import Foundation

enum GoatActionParser {
    private static let blockPattern = try! NSRegularExpression(
        pattern: "```goat-action\\s*\\n(\\{[^`]*?\\})\\s*\\n```",
        options: .dotMatchesLineSeparators
    )

    static func parse(from text: String) -> [GoatAction] {
        let range = NSRange(location: 0, length: text.utf16.count)
        let matches = blockPattern.matches(in: text, range: range)
        return matches.compactMap { match in
            guard let jsonRange = Range(match.range(at: 1), in: text) else { return nil }
            let json = String(text[jsonRange])
            guard let data = json.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(GoatAction.self, from: data)
        }
    }

    static func stripActionBlocks(from text: String) -> String {
        let range = NSRange(location: 0, length: text.utf16.count)
        let stripped = blockPattern.stringByReplacingMatches(
            in: text, range: range, withTemplate: ""
        )
        return stripped.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
