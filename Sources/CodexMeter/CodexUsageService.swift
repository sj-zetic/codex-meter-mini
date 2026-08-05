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
    private let queue = DispatchQueue(label: "com.codexmeter.rpc")

    func connect() {
        queue.async { [weak self] in self?.startIfNeeded() }
    }

    func refresh() {
        queue.async { [weak self] in
            guard let self else { return }
            if self.process?.isRunning != true { self.startIfNeeded() }
            if self.initialized { self.sendUsageRequest() }
        }
    }

    func stop() {
        queue.sync {
            output?.readabilityHandler = nil
            try? input?.close()
            try? output?.close()
            if process?.isRunning == true { process?.terminate() }
            process = nil
            input = nil
            output = nil
            initialized = false
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
        let stderr = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = ["app-server", "--stdio"]
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr
        process.terminationHandler = { [weak self] _ in
            self?.queue.async {
                self?.initialized = false
                self?.process = nil
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
            send(method: "initialize", params: [
                "clientInfo": ["name": "CodexMeter", "title": "Codex Meter", "version": "1.0.0"],
                "capabilities": ["experimentalApi": true]
            ], id: nextRequestID())
        } catch {
            fail("Couldn’t start Codex: \(error.localizedDescription)")
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
        send(method: "account/rateLimits/read", params: NSNull(), id: nextRequestID())
    }

    private func send(method: String, params: Any, id: Int? = nil) {
        var message: [String: Any] = ["jsonrpc": "2.0", "method": method, "params": params]
        if let id { message["id"] = id }
        guard JSONSerialization.isValidJSONObject(message),
              var data = try? JSONSerialization.data(withJSONObject: message) else { return }
        data.append(0x0A)
        do { try input?.write(contentsOf: data) }
        catch { fail("The connection to Codex was interrupted.") }
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
        if initialized == false, message["result"] != nil, message["id"] != nil {
            initialized = true
            send(method: "initialized", params: NSNull())
            sendUsageRequest()
            return
        }

        if let snapshot = UsageParser.parse(message) {
            DispatchQueue.main.async { [weak self] in self?.onSnapshot?(snapshot) }
            return
        }

        if let error = message["error"] as? [String: Any] {
            let text = error["message"] as? String ?? "Codex couldn’t load usage."
            fail(text)
        }
    }

    private func fail(_ message: String) {
        DispatchQueue.main.async { [weak self] in self?.onFailure?(message) }
    }
}
