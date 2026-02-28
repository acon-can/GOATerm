import AppKit

enum SyntaxHighlighter {
    static func highlight(_ text: String, forExtension ext: String) -> NSAttributedString {
        let base: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
            .foregroundColor: NSColor.labelColor
        ]
        let result = NSMutableAttributedString(string: text, attributes: base)
        let fullRange = NSRange(location: 0, length: result.length)

        let rules = Self.rules(for: ext)
        for rule in rules {
            let regex = try? NSRegularExpression(pattern: rule.pattern, options: rule.options)
            regex?.enumerateMatches(in: text, range: fullRange) { match, _, _ in
                guard let range = match?.range else { return }
                result.addAttribute(.foregroundColor, value: rule.color, range: range)
            }
        }

        return result
    }

    private struct Rule {
        let pattern: String
        let color: NSColor
        var options: NSRegularExpression.Options = []
    }

    private static func rules(for ext: String) -> [Rule] {
        switch ext {
        case "swift":
            return swiftRules
        case "py":
            return pythonRules
        case "js", "ts", "jsx", "tsx":
            return jsRules
        case "json":
            return jsonRules
        case "sh", "bash", "zsh":
            return shellRules
        default:
            return baseRules
        }
    }

    private static let baseRules: [Rule] = [
        Rule(pattern: "//.*$", color: .systemGreen, options: .anchorsMatchLines),
        Rule(pattern: "#.*$", color: .systemGreen, options: .anchorsMatchLines),
        Rule(pattern: "\"[^\"\\\\]*(?:\\\\.[^\"\\\\]*)*\"", color: .systemRed),
        Rule(pattern: "'[^'\\\\]*(?:\\\\.[^'\\\\]*)*'", color: .systemRed),
    ]

    private static let swiftRules: [Rule] = [
        Rule(pattern: "//.*$", color: .systemGreen, options: .anchorsMatchLines),
        Rule(pattern: "\"[^\"\\\\]*(?:\\\\.[^\"\\\\]*)*\"", color: .systemRed),
        Rule(pattern: "\\b(import|func|var|let|class|struct|enum|protocol|extension|return|if|else|guard|switch|case|for|while|do|try|catch|throw|throws|async|await|self|super|init|deinit|true|false|nil|private|public|internal|fileprivate|open|static|final|override|weak|unowned|lazy|@Observable|@State|@Binding|@Environment|some)\\b", color: .systemPurple),
        Rule(pattern: "\\b(String|Int|Bool|Double|Float|Array|Dictionary|Set|Optional|UUID|Date|URL|Any|Void)\\b", color: .systemTeal),
        Rule(pattern: "\\b\\d+(\\.\\d+)?\\b", color: .systemBlue),
    ]

    private static let pythonRules: [Rule] = [
        Rule(pattern: "#.*$", color: .systemGreen, options: .anchorsMatchLines),
        Rule(pattern: "\"\"\"[\\s\\S]*?\"\"\"", color: .systemRed),
        Rule(pattern: "\"[^\"\\\\]*(?:\\\\.[^\"\\\\]*)*\"", color: .systemRed),
        Rule(pattern: "'[^'\\\\]*(?:\\\\.[^'\\\\]*)*'", color: .systemRed),
        Rule(pattern: "\\b(def|class|import|from|return|if|elif|else|for|while|try|except|finally|with|as|yield|lambda|pass|break|continue|and|or|not|in|is|True|False|None|self|async|await)\\b", color: .systemPurple),
        Rule(pattern: "\\b\\d+(\\.\\d+)?\\b", color: .systemBlue),
    ]

    private static let jsRules: [Rule] = [
        Rule(pattern: "//.*$", color: .systemGreen, options: .anchorsMatchLines),
        Rule(pattern: "\"[^\"\\\\]*(?:\\\\.[^\"\\\\]*)*\"", color: .systemRed),
        Rule(pattern: "'[^'\\\\]*(?:\\\\.[^'\\\\]*)*'", color: .systemRed),
        Rule(pattern: "`[^`]*`", color: .systemRed),
        Rule(pattern: "\\b(const|let|var|function|return|if|else|for|while|do|switch|case|break|continue|class|extends|import|export|from|default|new|this|super|try|catch|throw|finally|async|await|yield|typeof|instanceof|true|false|null|undefined)\\b", color: .systemPurple),
        Rule(pattern: "\\b\\d+(\\.\\d+)?\\b", color: .systemBlue),
    ]

    private static let jsonRules: [Rule] = [
        Rule(pattern: "\"[^\"\\\\]*(?:\\\\.[^\"\\\\]*)*\"\\s*:", color: .systemPurple),
        Rule(pattern: "\"[^\"\\\\]*(?:\\\\.[^\"\\\\]*)*\"", color: .systemRed),
        Rule(pattern: "\\b(true|false|null)\\b", color: .systemOrange),
        Rule(pattern: "\\b-?\\d+(\\.\\d+)?([eE][+-]?\\d+)?\\b", color: .systemBlue),
    ]

    private static let shellRules: [Rule] = [
        Rule(pattern: "#.*$", color: .systemGreen, options: .anchorsMatchLines),
        Rule(pattern: "\"[^\"\\\\]*(?:\\\\.[^\"\\\\]*)*\"", color: .systemRed),
        Rule(pattern: "'[^']*'", color: .systemRed),
        Rule(pattern: "\\b(if|then|else|elif|fi|for|do|done|while|until|case|esac|function|return|local|export|source|alias|cd|echo|exit|test)\\b", color: .systemPurple),
        Rule(pattern: "\\$\\{?\\w+\\}?", color: .systemTeal),
    ]
}
