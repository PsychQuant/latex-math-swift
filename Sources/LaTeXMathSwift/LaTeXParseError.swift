import Foundation

/// Error thrown by `LaTeXMathParser.parse(_:)` when input cannot be converted
/// into a `MathComponent` AST.
///
/// All cases carry enough information for the caller to render an actionable
/// error message — no opaque "parse failed" — and to reroute the offending
/// equation to a fallback path (e.g., `che-word-mcp`'s
/// `insert_equation(components:)` JSON tree).
public enum LaTeXParseError: Error, Equatable {
    /// Input string was empty or contained only whitespace.
    case empty

    /// Encountered a `\token` that the parser does not recognize.
    /// The associated value is the verbatim token starting with `\` and
    /// ending at the first non-letter character (e.g. `"\\overbrace"`).
    case unrecognizedToken(token: String)

    /// Structural problem in the input: unterminated braces, mismatched
    /// `\left`/`\right`, missing macro argument, etc. The associated
    /// message describes the specific issue.
    case malformed(message: String)
}

extension LaTeXParseError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .empty:
            return "LaTeX input was empty."
        case .unrecognizedToken(let token):
            return "Unrecognized LaTeX token \(token)."
        case .malformed(let message):
            return "Malformed LaTeX: \(message)."
        }
    }
}
