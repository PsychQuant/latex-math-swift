import Foundation
import OOXMLSwift

/// LaTeX subset → OMML `MathComponent` AST.
///
/// Pure parser: produces only AST nodes, never wraps output in `<m:oMath>`,
/// `<m:oMathPara>`, or any container element. Wrapping is the caller's
/// responsibility because Word and PowerPoint embed equations differently.
///
/// ## Supported macros
///
/// See `README.md` for the canonical list. Highlights:
///
/// - Fraction / radical: `\frac{a}{b}`, `\sqrt{a}`, `\sqrt[n]{a}`
/// - Sub / superscript: `a_{b}`, `a^{b}`, `a_{b}^{c}`, `a^{c}_{b}` (normalized)
/// - Accent: `\hat{}`, `\bar{}`, `\tilde{}`, `\dot{}`, `\overline{}`
/// - Delimiter: `\left(\right)`, `\left[\right]`, `\left\|\right\|`, etc.
/// - N-ary: `\sum_{a}^{b}`, `\int_{a}^{b}`, `\prod_{a}^{b}` (with or without bounds)
/// - Function: `\ln(x)`, `\sin(x)`, `\cos(x)`, ...
/// - Limit: `\sup_{x}`, `\inf_{x}`, `\lim_{x \to 0}`
/// - Text: `\text{...}`
/// - All Greek letters (lowercase, uppercase, variants)
/// - Common operators (`\cdot`, `\times`, `\pm`, `\sim`, `\le`, `\ge`, `\to`, ...)
///
/// Anything else throws `LaTeXParseError.unrecognizedToken`.
public enum LaTeXMathParser {

    /// Parse a LaTeX subset string into an array of `MathComponent` nodes.
    ///
    /// - Parameter latex: The LaTeX expression.
    /// - Returns: Array of `MathComponent` representing the parsed AST.
    /// - Throws: `LaTeXParseError.empty` on empty or whitespace-only input;
    ///           `.unrecognizedToken(token:)` on unsupported `\macro`;
    ///           `.malformed(message:)` on structural problems.
    public static func parse(_ latex: String) throws -> [MathComponent] {
        let trimmed = latex.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            throw LaTeXParseError.empty
        }
        let dispatcher = MacroDispatcher(latex)
        return try dispatcher.parseAll()
    }
}
