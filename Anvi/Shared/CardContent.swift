import AppKit
import SwiftUI

enum Markdown {
    /// Inline Markdown (**bold**, *italic*, `code`, ~~strike~~, [links](…)), keeping line breaks.
    static func attributed(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }

    /// The text without Markdown markers, on one line, for lists and tables.
    static func plain(_ text: String) -> String {
        String(attributed(text).characters)
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }
}

/// One side of a card: optional image above Markdown text.
struct CardFaceView: View {
    var text: String
    var imageURL: URL?
    var font: Font = .system(size: 26)

    var body: some View {
        VStack(spacing: 16) {
            if let imageURL, let image = NSImage(contentsOf: imageURL) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 280)
                    .clipShape(.rect(cornerRadius: 8))
            }
            if !text.isEmpty {
                Text(Markdown.attributed(text))
                    .font(font)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
