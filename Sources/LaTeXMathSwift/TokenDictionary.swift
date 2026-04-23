import Foundation

/// Lookup tables mapping LaTeX `\token` macros to Unicode characters.
/// Used by `MacroDispatcher.parseLatexPlain(_:)` to convert plain-text
/// macro tokens into `MathRun` components.
///
/// Tables follow ECMA-376 §22.1.2.93 `ST_Style` Greek/symbol catalog
/// supplemented with common econometrics / statistics operators.
enum TokenDictionary {

    /// Lowercase Greek letters (`\alpha` … `\omega`).
    static let lowercaseGreek: [String: String] = [
        "\\alpha":   "α",
        "\\beta":    "β",
        "\\gamma":   "γ",
        "\\delta":   "δ",
        "\\epsilon": "ε",
        "\\zeta":    "ζ",
        "\\eta":     "η",
        "\\theta":   "θ",
        "\\iota":    "ι",
        "\\kappa":   "κ",
        "\\lambda":  "λ",
        "\\mu":      "μ",
        "\\nu":      "ν",
        "\\xi":      "ξ",
        "\\omicron": "ο",
        "\\pi":      "π",
        "\\rho":     "ρ",
        "\\sigma":   "σ",
        "\\tau":     "τ",
        "\\upsilon": "υ",
        "\\phi":     "φ",
        "\\chi":     "χ",
        "\\psi":     "ψ",
        "\\omega":   "ω",
    ]

    /// Uppercase Greek letters whose macro form differs from a Latin letter
    /// (e.g. there is no `\Alpha` because it would render as ASCII `A`).
    static let uppercaseGreek: [String: String] = [
        "\\Gamma":   "Γ",
        "\\Delta":   "Δ",
        "\\Theta":   "Θ",
        "\\Lambda":  "Λ",
        "\\Xi":      "Ξ",
        "\\Pi":      "Π",
        "\\Sigma":   "Σ",
        "\\Upsilon": "Υ",
        "\\Phi":     "Φ",
        "\\Psi":     "Ψ",
        "\\Omega":   "Ω",
    ]

    /// Variant Greek letter forms.
    static let variantGreek: [String: String] = [
        "\\varepsilon": "ε",   // U+03B5 (the "open" epsilon Word renders by default)
        "\\vartheta":   "ϑ",
        "\\varphi":     "φ",
        "\\varpi":      "ϖ",
        "\\varrho":     "ϱ",
        "\\varsigma":   "ς",
    ]

    /// Common operators and symbols.
    static let operators: [String: String] = [
        "\\cdot":      "·",
        "\\times":     "×",
        "\\pm":        "±",
        "\\mp":        "∓",
        "\\sim":       "∼",
        "\\approx":    "≈",
        "\\neq":       "≠",
        "\\le":        "≤",
        "\\leq":       "≤",
        "\\ge":        "≥",
        "\\geq":       "≥",
        "\\to":        "→",
        "\\rightarrow":"→",
        "\\leftarrow": "←",
        "\\Rightarrow":"⇒",
        "\\Leftarrow": "⇐",
        "\\infty":     "∞",
        "\\partial":   "∂",
        "\\nabla":     "∇",
        "\\cdots":     "⋯",
        "\\ldots":     "…",
        "\\vdots":     "⋮",
        "\\ddots":     "⋱",
        "\\mid":       "∣",
        "\\quad":      "\u{2003}",   // em space
        "\\qquad":     "\u{2003}\u{2003}",
        "\\,":         "\u{2009}",   // thin space
    ]

    /// Bare n-ary operators without bounds (rendered as plain MathRun runs).
    /// When followed by `_{...}` or `^{...}` they are routed to MathNary instead.
    static let bareNary: [String: String] = [
        "\\sum":      "∑",
        "\\int":      "∫",
        "\\prod":     "∏",
        "\\oint":     "∮",
        "\\bigcup":   "⋃",
        "\\bigcap":   "⋂",
    ]

    /// Combined lookup table.
    static let all: [String: String] = lowercaseGreek
        .merging(uppercaseGreek)   { _, new in new }
        .merging(variantGreek)     { _, new in new }
        .merging(operators)        { _, new in new }
        .merging(bareNary)         { _, new in new }

    /// LaTeX accent macros and their corresponding Unicode combining diacritics.
    /// Used by MacroDispatcher to construct `MathAccent`.
    static let accents: [String: String] = [
        "\\hat":      "\u{0302}",   // combining circumflex
        "\\bar":      "\u{0304}",   // combining macron
        "\\overline": "\u{0304}",
        "\\tilde":    "\u{0303}",   // combining tilde
        "\\dot":      "\u{0307}",   // combining dot above
        "\\ddot":     "\u{0308}",   // combining diaeresis
        "\\vec":      "\u{20D7}",   // combining right arrow above
    ]

    /// Function names rendered as `MathFunction(functionName: [MathRun(...)])`
    /// when followed by a parenthesized argument; otherwise treated as plain
    /// `MathRun(text:)` text.
    static let functionNames: Set<String> = [
        "\\ln", "\\sin", "\\cos", "\\tan",
        "\\log", "\\exp",
        "\\max", "\\min", "\\det",
        "\\arg", "\\arcsin", "\\arccos", "\\arctan",
        "\\sinh", "\\cosh", "\\tanh",
    ]

    /// Limit-style operators rendered as `MathLimit` when followed by `_{...}`,
    /// otherwise as plain `MathRun`.
    static let limitOps: [String: String] = [
        "\\sup": "sup",
        "\\inf": "inf",
        "\\lim": "lim",
    ]

    /// N-ary operator UTF chars used to construct `MathNary.NaryOperator`.
    /// Returns nil when the macro is not n-ary-eligible (i.e. it's plain or
    /// limit-style).
    static func naryOperator(for macro: String) -> String? {
        switch macro {
        case "\\sum":    return "∑"
        case "\\int":    return "∫"
        case "\\prod":   return "∏"
        case "\\oint":   return "∮"
        case "\\bigcup": return "⋃"
        case "\\bigcap": return "⋂"
        default:         return nil
        }
    }
}
