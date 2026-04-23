import Foundation
import OOXMLSwift

/// Recursive-descent parser converting a LaTeX subset into `[MathComponent]`.
///
/// Internal to the package; callers use `LaTeXMathParser.parse(_:)`.
///
/// ## Design notes
///
/// **Postfix script attachment**: after producing a base atom, the dispatcher
/// looks ahead for `_{...}` and `^{...}` and wraps the previous atom in
/// `MathSubSuperScript`. Both `x_{i}^{2}` and `x^{2}_{i}` normalize to the
/// same node.
///
/// **N-ary base scope**: `MathNary` consumes a single trailing atom as its
/// `base`. Users wanting a wider scope must wrap in braces:
/// `\sum_{i=1}^{n} {a_i b_i}` vs `\sum_{i=1}^{n} a_i b_i` (the second sets
/// only `a_i` as the operator's base; `b_i` becomes a sibling). This matches
/// Word's native equation editor behavior.
///
/// **Recursion depth**: bounded by Swift's default ~512 KB call stack; each
/// frame is small, accommodating equations with hundreds of nesting levels —
/// far beyond realistic input.
final class MacroDispatcher {

    private let chars: [Character]
    private var i: Int

    init(_ input: String) {
        self.chars = Array(input)
        self.i = 0
    }

    func parseAll() throws -> [MathComponent] {
        var result: [MathComponent] = []
        while i < chars.count {
            if let atom = try parseAtomWithScripts() {
                result.append(atom)
            } else {
                // Skip a stray whitespace at top level.
                i += 1
            }
        }
        // Coalesce consecutive plain MathRun(text:) into a single run for
        // tighter OMML output.
        return coalesceRuns(result)
    }

    /// Parse one base atom and consume any trailing `_{...}` / `^{...}`
    /// postfix script operators. Returns nil if we hit end of input or a
    /// closing delimiter handled by the caller.
    private func parseAtomWithScripts() throws -> MathComponent? {
        guard let base = try parseBaseAtom() else { return nil }
        return try attachScripts(to: base)
    }

    /// If the cursor points at `_` or `^`, consume one or both and wrap the
    /// supplied base in a `MathSubSuperScript`. Otherwise return base as-is.
    private func attachScripts(to base: MathComponent) throws -> MathComponent {
        var sub: [MathComponent]? = nil
        var sup: [MathComponent]? = nil

        // Loop allows arbitrary order (`_{}^{}` or `^{}_{}`) to normalize.
        while i < chars.count {
            skipSpaces()
            if i < chars.count && chars[i] == "_" && sub == nil {
                i += 1
                sub = try parseScriptArgument()
            } else if i < chars.count && chars[i] == "^" && sup == nil {
                i += 1
                sup = try parseScriptArgument()
            } else {
                break
            }
        }

        if sub != nil || sup != nil {
            return MathSubSuperScript(base: [base], sub: sub, sup: sup)
        }
        return base
    }

    /// `_{...}` and `^{...}` use a braced argument for multi-char content,
    /// but `_x` and `^2` (single char) are also valid.
    private func parseScriptArgument() throws -> [MathComponent] {
        guard i < chars.count else {
            throw LaTeXParseError.malformed(message: "expected argument after script operator")
        }
        if chars[i] == "{" {
            return try parseBracedGroup()
        }
        // Single-char shorthand: `_x` → [MathRun("x")]
        if chars[i] == "\\" {
            // Macro shorthand: `_\alpha` → parse single macro
            if let m = try parseBaseAtom() {
                return [m]
            }
            throw LaTeXParseError.malformed(message: "expected atom after script operator")
        }
        let c = chars[i]
        i += 1
        return [MathRun(text: String(c))]
    }

    /// Parse one base atom (plain text, macro, group, etc.) without trailing
    /// scripts.
    private func parseBaseAtom() throws -> MathComponent? {
        skipSpaces()
        guard i < chars.count else { return nil }

        let c = chars[i]

        // Closing delimiters / script markers / commas — caller handles.
        if c == "}" || c == "_" || c == "^" { return nil }

        // Group: `{...}`
        if c == "{" {
            let group = try parseBracedGroup()
            // A single-element group flattens; multi-element returns whatever
            // makes sense as a single atom (we wrap in a synthetic delimiter
            // group only if the caller distinguishes — here we just return
            // the components inline by wrapping in a 0-delimiter "group".
            // For simplicity: collapse [single] to that single, otherwise
            // emit them as inline runs by concatenation.
            if group.count == 1 {
                return group[0]
            }
            // Multiple components in {} — we lose the grouping at OMML level
            // since OMML doesn't have a generic "group" concept. We fold by
            // returning each component flattened into the parent context via
            // a synthetic delimiter with empty open/close.
            return MathDelimiter(open: "", close: "", elements: [group], separator: "")
        }

        // Macro: `\token` or `\,` etc.
        if c == "\\" {
            return try parseMacro()
        }

        // Plain run: read consecutive non-special chars into one MathRun.
        return parsePlainRun()
    }

    /// Parse `\macro` or `\,` and any required arguments.
    private func parseMacro() throws -> MathComponent {
        guard i < chars.count, chars[i] == "\\" else {
            throw LaTeXParseError.malformed(message: "expected '\\\\' at macro start")
        }
        let macroStart = i
        i += 1   // consume backslash

        // Special single-symbol macros: `\,` `\!` `\;` etc.
        if i < chars.count, !chars[i].isLetter {
            let token = String(chars[macroStart...i])
            i += 1
            if let unicode = TokenDictionary.operators[token] {
                return MathRun(text: unicode)
            }
            // Unknown single-char macro
            throw LaTeXParseError.unrecognizedToken(token: token)
        }

        // Letter macro: read alphabetic chars
        while i < chars.count, chars[i].isLetter {
            i += 1
        }
        let macroName = String(chars[macroStart..<i])

        // Dispatch by macro name
        switch macroName {
        case "\\frac":
            let num = try parseRequiredBracedGroup(after: macroName)
            let den = try parseRequiredBracedGroup(after: macroName)
            return MathFraction(numerator: num, denominator: den)

        case "\\sqrt":
            // Optional [n] degree (balanced bracket scan), then required {radicand}
            skipSpaces()
            var degree: [MathComponent]? = nil
            if i < chars.count, chars[i] == "[" {
                let inner = try sliceBalanced(open: "[", close: "]")
                degree = try MacroDispatcher(inner).parseAll()
            }
            let radicand = try parseRequiredBracedGroup(after: macroName)
            return MathRadical(radicand: radicand, degree: degree)

        case "\\left":
            return try parseDelimitedExpression(openMacro: macroName)

        case "\\right":
            // Should be consumed by parseDelimitedExpression — stray \right
            throw LaTeXParseError.malformed(message: "unmatched \\right")

        case "\\text":
            let arg = try parseRequiredBracedGroupAsString(after: macroName)
            return MathRun(text: arg, style: .plain)

        default:
            // Accent macros: `\hat{x}`, `\bar{x}`, ...
            if let accentChar = TokenDictionary.accents[macroName] {
                let base = try parseRequiredBracedGroup(after: macroName)
                return MathAccent(base: base, accentChar: accentChar)
            }

            // N-ary operators: `\sum` `\int` `\prod` — check for `_{}^{}` bounds
            if let opChar = TokenDictionary.naryOperator(for: macroName) {
                return try parseNary(opChar: opChar)
            }

            // Limit ops: `\sup_{x}`, `\lim_{x \to 0}`
            if let limitName = TokenDictionary.limitOps[macroName] {
                return try parseLimit(name: limitName)
            }

            // Function names: `\ln(x)`, `\sin(x)`
            if TokenDictionary.functionNames.contains(macroName) {
                return try parseFunction(name: String(macroName.dropFirst()))
            }

            // Plain Greek/symbol/operator macros
            if let unicode = TokenDictionary.all[macroName] {
                return MathRun(text: unicode)
            }

            throw LaTeXParseError.unrecognizedToken(token: macroName)
        }
    }

    private func parseNary(opChar: String) throws -> MathComponent {
        // Look for optional sub/sup bounds in either order
        var sub: [MathComponent]? = nil
        var sup: [MathComponent]? = nil
        while i < chars.count {
            skipSpaces()
            if i < chars.count, chars[i] == "_", sub == nil {
                i += 1
                sub = try parseScriptArgument()
            } else if i < chars.count, chars[i] == "^", sup == nil {
                i += 1
                sup = try parseScriptArgument()
            } else {
                break
            }
        }

        skipSpaces()
        // Grab the next single atom as the n-ary base (per docstring).
        var base: [MathComponent] = []
        if let atom = try parseAtomWithScripts() {
            base = [atom]
        }

        let op = MathNary.NaryOperator(rawValue: opChar) ?? .sum
        return MathNary(op: op, sub: sub, sup: sup, base: base)
    }

    private func parseLimit(name: String) throws -> MathComponent {
        // `\sup_{x}` → MathLimit(position: .lower, base: [Run("sup")], limit: x)
        // `\lim_{x \to 0}` → same shape
        var limit: [MathComponent] = []
        skipSpaces()
        if i < chars.count, chars[i] == "_" {
            i += 1
            limit = try parseScriptArgument()
        }

        let baseRun = MathRun(text: name)
        if limit.isEmpty {
            return baseRun
        }
        return MathLimit(position: .lower, base: [baseRun], limit: limit)
    }

    private func parseFunction(name: String) throws -> MathComponent {
        // `\ln(P_t)` → MathFunction(functionName: [Run("ln")], argument: parsed("P_t"))
        skipSpaces()
        let funcRun = MathRun(text: name)

        // If followed by `(`, balanced-paren scan to find the matching `)`,
        // then recursively parse the inner content.
        if i < chars.count, chars[i] == "(" {
            let inner = try sliceBalanced(open: "(", close: ")")
            let arg = try MacroDispatcher(inner).parseAll()
            return MathFunction(functionName: [funcRun], argument: arg)
        }

        // No parenthesized argument — treat as plain text (e.g. `\ln` standalone).
        return funcRun
    }

    /// Cursor must point at `open`. Consumes through the matched `close` and
    /// returns the substring strictly between them. Tracks nested pairs so
    /// `((a)b)` gives `(a)b`.
    private func sliceBalanced(open: Character, close: Character) throws -> String {
        guard i < chars.count, chars[i] == open else {
            throw LaTeXParseError.malformed(message: "expected '\(open)'")
        }
        i += 1   // consume open
        let start = i
        var depth = 1
        while i < chars.count {
            let c = chars[i]
            if c == open {
                depth += 1
            } else if c == close {
                depth -= 1
                if depth == 0 {
                    let inner = String(chars[start..<i])
                    i += 1   // consume close
                    return inner
                }
            }
            i += 1
        }
        throw LaTeXParseError.malformed(message: "unterminated '\(open)' (missing matching '\(close)')")
    }

    private func parseDelimitedExpression(openMacro: String) throws -> MathComponent {
        // Already consumed `\left`. Next is the open delimiter (single char or
        // `\|` for double-bar or `\{` `\}` for literal braces).
        skipSpaces()
        let open = try readDelimiter()
        let elements = try parseUntilLeftRight()
        // Expect `\right<close>`
        guard i + 5 < chars.count + 1 else {
            throw LaTeXParseError.malformed(message: "missing \\right after \\left\(open)")
        }
        // Skip `\right`
        if !consumeLiteral("\\right") {
            throw LaTeXParseError.malformed(message: "expected \\right after \\left\(open) content")
        }
        let close = try readDelimiter()
        return MathDelimiter(open: open, close: close, elements: [elements], separator: "")
    }

    /// Read one delimiter character or escape (`\|` `\{` `\}` `.`).
    /// Returns the visible delimiter character ("(", "|", "‖", "{", etc.) or
    /// empty string for the LaTeX `.` invisible delimiter.
    private func readDelimiter() throws -> String {
        guard i < chars.count else {
            throw LaTeXParseError.malformed(message: "expected delimiter character")
        }
        let c = chars[i]
        if c == "\\" {
            // `\|` `\{` `\}` `\langle` etc.
            i += 1
            guard i < chars.count else {
                throw LaTeXParseError.malformed(message: "incomplete escaped delimiter")
            }
            let next = chars[i]
            if next == "|" {
                i += 1
                return "‖"
            }
            if next == "{" {
                i += 1
                return "{"
            }
            if next == "}" {
                i += 1
                return "}"
            }
            // Letter macros: `\langle` etc. — read until non-letter
            if next.isLetter {
                let start = i
                while i < chars.count, chars[i].isLetter { i += 1 }
                let macro = "\\" + String(chars[start..<i])
                switch macro {
                case "\\langle": return "⟨"
                case "\\rangle": return "⟩"
                case "\\lceil":  return "⌈"
                case "\\rceil":  return "⌉"
                case "\\lfloor": return "⌊"
                case "\\rfloor": return "⌋"
                default:
                    throw LaTeXParseError.unrecognizedToken(token: macro)
                }
            }
            throw LaTeXParseError.malformed(message: "unrecognized escaped delimiter \\\(next)")
        }
        // Single-char delimiter
        if c == "." {
            i += 1
            return ""   // LaTeX invisible delimiter
        }
        i += 1
        return String(c)
    }

    private func parseUntilLeftRight() throws -> [MathComponent] {
        var result: [MathComponent] = []
        while i < chars.count {
            skipSpaces()
            // Peek for `\right`
            if peekLiteral("\\right") {
                break
            }
            if let atom = try parseAtomWithScripts() {
                result.append(atom)
            } else {
                break
            }
        }
        return coalesceRuns(result)
    }

    private func parseUntil(closing: Character) throws -> [MathComponent] {
        var result: [MathComponent] = []
        while i < chars.count {
            skipSpaces()
            if chars[i] == closing { break }
            if let atom = try parseAtomWithScripts() {
                result.append(atom)
            } else {
                break
            }
        }
        return coalesceRuns(result)
    }

    private func parseRequiredBracedGroup(after macro: String) throws -> [MathComponent] {
        skipSpaces()
        guard i < chars.count, chars[i] == "{" else {
            throw LaTeXParseError.malformed(message: "expected '{' after \(macro)")
        }
        return try parseBracedGroup()
    }

    private func parseRequiredBracedGroupAsString(after macro: String) throws -> String {
        skipSpaces()
        guard i < chars.count, chars[i] == "{" else {
            throw LaTeXParseError.malformed(message: "expected '{' after \(macro)")
        }
        i += 1   // consume '{'
        var depth = 1
        var buf = ""
        while i < chars.count {
            let c = chars[i]
            if c == "{" {
                depth += 1
                buf.append(c)
            } else if c == "}" {
                depth -= 1
                if depth == 0 {
                    i += 1
                    return buf
                }
                buf.append(c)
            } else {
                buf.append(c)
            }
            i += 1
        }
        throw LaTeXParseError.malformed(message: "unterminated braces after \(macro)")
    }

    private func parseBracedGroup() throws -> [MathComponent] {
        guard i < chars.count, chars[i] == "{" else {
            throw LaTeXParseError.malformed(message: "expected '{'")
        }
        i += 1   // consume '{'
        var result: [MathComponent] = []
        while i < chars.count, chars[i] != "}" {
            if let atom = try parseAtomWithScripts() {
                result.append(atom)
            } else {
                break
            }
        }
        guard i < chars.count, chars[i] == "}" else {
            throw LaTeXParseError.malformed(message: "unterminated braces")
        }
        i += 1   // consume '}'
        return coalesceRuns(result)
    }

    private func parsePlainRun() -> MathComponent {
        // Read consecutive plain chars (not whitespace, not special).
        var buf = ""
        while i < chars.count {
            let c = chars[i]
            if c == "\\" || c == "{" || c == "}" || c == "_" || c == "^" {
                break
            }
            // Stop at whitespace so subsequent macros parse cleanly,
            // but keep single chars to allow `a + b` to be one run.
            buf.append(c)
            i += 1
        }
        return MathRun(text: buf)
    }

    // MARK: - Helpers

    private func skipSpaces() {
        while i < chars.count, chars[i] == " " {
            i += 1
        }
    }

    private func consumeLiteral(_ literal: String) -> Bool {
        let lit = Array(literal)
        guard i + lit.count <= chars.count else { return false }
        for (k, c) in lit.enumerated() where chars[i + k] != c {
            return false
        }
        i += lit.count
        return true
    }

    private func peekLiteral(_ literal: String) -> Bool {
        let lit = Array(literal)
        guard i + lit.count <= chars.count else { return false }
        for (k, c) in lit.enumerated() where chars[i + k] != c {
            return false
        }
        return true
    }

    private func coalesceRuns(_ components: [MathComponent]) -> [MathComponent] {
        var out: [MathComponent] = []
        for comp in components {
            if let run = comp as? MathRun,
               run.style == nil,
               let prev = out.last as? MathRun,
               prev.style == nil {
                out[out.count - 1] = MathRun(text: prev.text + run.text)
            } else {
                out.append(comp)
            }
        }
        return out
    }
}
