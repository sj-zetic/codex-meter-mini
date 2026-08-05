import AppKit
import SwiftUI

enum CodexBrandArtwork {
    static var image: NSImage? {
        if let packagedURL = Bundle.main.url(forResource: "CodexIcon", withExtension: "png") {
            return NSImage(contentsOf: packagedURL)
        }
        return Bundle.module.url(forResource: "CodexIcon", withExtension: "png")
            .flatMap(NSImage.init(contentsOf:))
    }
}

struct CodexBrandIcon: View {
    var size: CGFloat

    var body: some View {
        Group {
            if let image = CodexBrandArtwork.image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: size * 0.48, weight: .semibold))
                    .foregroundStyle(.tint)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
