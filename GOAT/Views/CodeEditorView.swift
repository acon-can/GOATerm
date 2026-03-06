import SwiftUI
import AppKit

struct CodeEditorView: NSViewRepresentable {
    @Binding var text: String
    let fileExtension: String
    var onTextChange: ((String) -> Void)?

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true

        let textView = NSTextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = false
        textView.usesFindBar = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.autoresizingMask = [.width]
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isHorizontallyResizable = true
        textView.isVerticallyResizable = true
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        // Line number ruler
        let ruler = LineNumberRulerView(textView: textView)
        scrollView.verticalRulerView = ruler
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true

        scrollView.documentView = textView
        context.coordinator.textView = textView
        textView.delegate = context.coordinator

        // Apply initial content with highlighting
        let highlighted = SyntaxHighlighter.highlight(text, forExtension: fileExtension)
        textView.textStorage?.setAttributedString(highlighted)

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text {
            let highlighted = SyntaxHighlighter.highlight(text, forExtension: fileExtension)
            let selectedRanges = textView.selectedRanges
            textView.textStorage?.setAttributedString(highlighted)
            textView.selectedRanges = selectedRanges
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, fileExtension: fileExtension, onTextChange: onTextChange)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        let fileExtension: String
        var onTextChange: ((String) -> Void)?
        weak var textView: NSTextView?

        init(text: Binding<String>, fileExtension: String, onTextChange: ((String) -> Void)?) {
            self._text = text
            self.fileExtension = fileExtension
            self.onTextChange = onTextChange
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text = textView.string
            onTextChange?(textView.string)

            // Re-highlight
            let highlighted = SyntaxHighlighter.highlight(textView.string, forExtension: fileExtension)
            let selectedRanges = textView.selectedRanges
            textView.textStorage?.setAttributedString(highlighted)
            textView.selectedRanges = selectedRanges
        }
    }
}

class LineNumberRulerView: NSRulerView {
    private weak var textView: NSTextView?

    init(textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        self.clientView = textView
        self.ruleThickness = 40

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(needsRedisplay),
            name: NSText.didChangeNotification,
            object: textView
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(needsRedisplay),
            name: NSView.boundsDidChangeNotification,
            object: textView.enclosingScrollView?.contentView
        )
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func needsRedisplay() {
        needsDisplay = true
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = textView,
              let layoutManager = textView.layoutManager,
              let container = textView.textContainer else { return }

        // Clip drawing to the provided rect to prevent bleeding outside bounds
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.clip(to: rect)

        let visibleRect = textView.visibleRect
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: container)
        let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)

        let text = textView.string as NSString
        var lineNumber = 1
        // Count lines before visible range
        text.enumerateSubstrings(in: NSRange(location: 0, length: charRange.location), options: [.byLines, .substringNotRequired]) { _, _, _, _ in
            lineNumber += 1
        }

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor
        ]

        text.enumerateSubstrings(in: charRange, options: [.byLines, .substringNotRequired]) { _, substringRange, _, _ in
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: substringRange.location)
            var lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
            lineRect.origin.y -= visibleRect.origin.y
            lineRect.origin.y += textView.textContainerInset.height

            // Only draw if within the visible rect
            guard lineRect.origin.y + lineRect.height >= rect.origin.y,
                  lineRect.origin.y <= rect.origin.y + rect.height else {
                lineNumber += 1
                return
            }

            let str = "\(lineNumber)" as NSString
            let size = str.size(withAttributes: attrs)
            let point = NSPoint(x: self.ruleThickness - size.width - 4, y: lineRect.origin.y + (lineRect.height - size.height) / 2)
            str.draw(at: point, withAttributes: attrs)

            lineNumber += 1
        }

        context.restoreGState()
    }
}
