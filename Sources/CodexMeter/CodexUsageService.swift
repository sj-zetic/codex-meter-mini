import Foundation

final class CodexUsageService {
    var onSnapshot: ((UsageSnapshot) -> Void)?
    var onFailure: ((String) -> Void)?

    private var process: Process?
    private var input: FileHandle?
    private var output: FileHandle?
    private var buffer = Data()
    private var nextID = 1
    private var initialized = false
    private var pendingRequest: PendingRequest?
    private var responseTimeoutWorkItem: DispatchWorkItem?
    private var recoveryAttempted = false
    private var isStopping = false
    private let queue = DispatchQueue(label: "com.codexmeter.rpc")
    private let responseTimeout: TimeInterval = 15

    private enum PendingRequest {
        case initialize(Int)
        case usage(Int)

        var id: Int {
            switch self {
            case .initialize(let id), .usage(let id): return id
            }
        }

        var timeoutMessage: String {
            switch self {
            case .initialize: return "Codex took too long to connect."
            case .usage: return "Codex took too long to refresh usage."
            }
        }
    }

    func connect() {
        queue.async { [weak self] in
            self?.isStopping = false
            self?.startIfNeeded()
        }
    }

    func refresh() {
        queue.async { [weak self] in
            guard let self else { return }
            if self.process?.isRunning != true { self.startIfNeeded() }
            if self.initialized, self.pendingRequest == nil { self.sendUsageRequest() }
        }
    }

    func stop() {
        queue.sync {
            isStopping = true
            clearPendingRequest()
            tearDownConnection()
        }
    }

    deinit { stop() }

    private func startIfNeeded() {
        guard process?.isRunning != true else { return }
        guard let executable = locateCodex() else {
            fail("Codex isn’t installed. Install or open the Codex app, then try again.")
            return
        }

        let process = Process()
        let stdin = Pipe()
        let stdout = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = ["app-server", "--stdio"]
        process.standardInput = stdin
        process.standardOutput = stdout
        // The app-server can log for days. An unread stderr Pipe eventually fills
        // and blocks the child process, so discard logs we do not surface.
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { [weak self, weak process] _ in
            self?.queue.async {
                guard let self, let process, self.process === process else { return }
                self.clearPendingRequest()
                self.initialized = false
                self.process = nil
                self.input = nil
                self.output = nil
                guard self.isStopping == false else { return }
                self.recoverOrFail("The Codex connection ended unexpectedly.")
            }
        }

        do {
            try process.run()
            self.process = process
            input = stdin.fileHandleForWriting
            output = stdout.fileHandleForReading
            output?.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                self?.queue.async { self?.consume(data) }
            }
            let id = nextRequestID()
            pendingRequest = .initialize(id)
            guard send(method: "initialize", params: [
                "clientInfo": ["name": "CodexMeter", "title": "Codex Meter", "version": "1.0.0"],
                "capabilities": ["experimentalApi": true]
            ], id: id) else {
                recoverOrFail("The connection to Codex was interrupted.")
                return
            }
            scheduleResponseTimeout()
        } catch {
            recoverOrFail("Couldn’t start Codex: \(error.localizedDescription)")
        }
    }

    private func locateCodex() -> String? {
        let candidates = [
            "/Applications/ChatGPT.app/Contents/Resources/codex",
            "/Applications/Codex.app/Contents/Resources/codex",
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex"
        ]
        if let match = candidates.first(where: FileManager.default.isExecutableFile(atPath:)) { return match }

        let path = ProcessInfo.processInfo.environment["PATH"] ?? ""
        return path.split(separator: ":")
            .map { String($0) + "/codex" }
            .first(where: FileManager.default.isExecutableFile(atPath:))
    }

    private func nextRequestID() -> Int { defer { nextID += 1 }; return nextID }

    private func sendUsageRequest() {
        guard pendingRequest == nil else { return }
        let id = nextRequestID()
        pendingRequest = .usage(id)
        guard send(method: "account/rateLimits/read", params: NSNull(), id: id) else {
            recoverOrFail("The connection to Codex was interrupted.")
            return
        }
        scheduleResponseTimeout()
    }

    @discardableResult
    private func send(method: String, params: Any, id: Int? = nil) -> Bool {
        var message: [String: Any] = ["jsonrpc": "2.0", "method": method, "params": params]
        if let id { message["id"] = id }
        guard JSONSerialization.isValidJSONObject(message),
              var data = try? JSONSerialization.data(withJSONObject: message),
              let input else { return false }
        data.append(0x0A)
        do {
            try input.write(contentsOf: data)
            return true
        } catch {
            return false
        }
    }

    private func consume(_ data: Data) {
        buffer.append(data)
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = buffer[..<newline]
            buffer.removeSubrange(...newline)
            guard let value = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else { continue }
            handle(value)
        }
    }

    private func handle(_ message: [String: Any]) {
        let responseID = (message["id"] as? NSNumber)?.intValue
            ?? (message["id"] as? Int)

        if case .initialize(let id) = pendingRequest,
           responseID == id,
           message["result"] != nil {
            clearPendingRequest()
            initialized = true
            send(method: "initialized", params: NSNull())
            sendUsageRequest()
            return
        }

        if case .usage(let id) = pendingRequest,
           responseID == id,
           let snapshot = UsageParser.parse(message) {
            clearPendingRequest()
            recoveryAttempted = false
            DispatchQueue.main.async { [weak self] in self?.onSnapshot?(snapshot) }
            return
        }

        if responseID == pendingRequest?.id,
           let error = message["error"] as? [String: Any] {
            let text = error["message"] as? String ?? "Codex couldn’t load usage."
            recoverOrFail(text)
        }
    }

    private func scheduleResponseTimeout() {
        responseTimeoutWorkItem?.cancel()
        guard let request = pendingRequest else { return }
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.pendingRequest?.id == request.id else { return }
            self.recoverOrFail(request.timeoutMessage)
        }
        responseTimeoutWorkItem = workItem
        queue.asyncAfter(deadline: .now() + responseTimeout, execute: workItem)
    }

    private func clearPendingRequest() {
        responseTimeoutWorkItem?.cancel()
        responseTimeoutWorkItem = nil
        pendingRequest = nil
    }

    private func recoverOrFail(_ message: String) {
        clearPendingRequest()
        guard recoveryAttempted == false else {
            recoveryAttempted = false
            tearDownConnection()
            fail(message)
            return
        }

        recoveryAttempted = true
        tearDownConnection()
        startIfNeeded()
    }

    private func tearDownConnection() {
        let oldProcess = process
        process = nil
        oldProcess?.terminationHandler = nil
        output?.readabilityHandler = nil
        try? input?.close()
        try? output?.close()
        if oldProcess?.isRunning == true { oldProcess?.terminate() }
        input = nil
        output = nil
        buffer.removeAll(keepingCapacity: true)
        initialized = false
    }

    private func fail(_ message: String) {
        DispatchQueue.main.async { [weak self] in self?.onFailure?(message) }
    }
}
