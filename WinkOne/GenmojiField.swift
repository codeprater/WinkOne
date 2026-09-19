import SwiftUI
import UIKit

/// A one line field that accepts a Genmoji from the emoji keyboard.
///
/// Genmoji arrives as an `NSAdaptiveImageGlyph` inside the attributed text, not
/// as a character, so a plain `TextField` cannot receive one. This wraps a
/// `UITextView` with adaptive image glyphs switched on and hands back the
/// glyph's image data the moment one is inserted.
struct GenmojiField: UIViewRepresentable {
    @Binding var genmojiData: Data?
    var placeholder: String
    var onTooLarge: (() -> Void)?

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        view.backgroundColor = .clear
        view.font = .systemFont(ofSize: 22, weight: .semibold)
        view.textColor = .white
        view.tintColor = UIColor(WinkColor.volt)
        view.textAlignment = .center
        view.isScrollEnabled = false
        view.textContainerInset = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
        view.autocorrectionType = .no
        view.returnKeyType = .done
        if #available(iOS 18.0, *) {
            view.supportsAdaptiveImageGlyph = true
        }
        context.coordinator.attachPlaceholder(to: view, text: placeholder)
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.refreshPlaceholder(view)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        private let parent: GenmojiField
        private weak var placeholderLabel: UILabel?

        /// A Genmoji is a small image. Anything past this is not one.
        private let maxBytes = 400_000

        init(_ parent: GenmojiField) {
            self.parent = parent
        }

        func attachPlaceholder(to view: UITextView, text: String) {
            let label = UILabel()
            label.text = text
            label.font = .systemFont(ofSize: 14, weight: .medium)
            label.textColor = UIColor.white.withAlphaComponent(0.4)
            label.textAlignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
            ])
            placeholderLabel = label
        }

        func refreshPlaceholder(_ view: UITextView) {
            placeholderLabel?.isHidden = !view.attributedText.string.isEmpty
                || parent.genmojiData != nil
        }

        func textViewDidChange(_ textView: UITextView) {
            defer { refreshPlaceholder(textView) }
            guard #available(iOS 18.0, *) else { return }

            var found: Data?
            let full = NSRange(location: 0, length: textView.attributedText.length)
            textView.attributedText.enumerateAttribute(
                .adaptiveImageGlyph,
                in: full
            ) { value, _, stop in
                if let glyph = value as? NSAdaptiveImageGlyph {
                    found = glyph.imageContent
                    stop.pointee = true
                }
            }

            guard let found else { return }
            guard found.count <= maxBytes else {
                parent.onTooLarge?()
                textView.attributedText = NSAttributedString(string: "")
                return
            }
            parent.genmojiData = found
            // One per card. Clear the field so a second insert replaces rather
            // than stacking up.
            textView.attributedText = NSAttributedString(string: "")
        }

        func textView(
            _ textView: UITextView,
            shouldChangeTextIn range: NSRange,
            replacementText text: String
        ) -> Bool {
            if text == "\n" {
                textView.resignFirstResponder()
                return false
            }
            return true
        }
    }
}
