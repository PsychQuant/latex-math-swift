# latex-math-swift

A pure-parser Swift package that converts a LaTeX subset into [ooxml-swift](https://github.com/PsychQuant/ooxml-swift) `MathComponent` ASTs (OMML — Office Math Markup Language, ECMA-376 Part 1 §22.1).

The package emits **only AST nodes** — it does **not** wrap output in `<m:oMath>` / `<m:oMathPara>` paragraph elements. That responsibility is the caller's, because Word and PowerPoint embed equations differently:

- **Word** wraps in `<m:oMathPara><m:oMath>...</m:oMath></m:oMathPara>` inside `<w:p>` paragraphs.
- **PowerPoint** commonly uses either OLE-embedded `equation.bin` objects (older PPT-compat) or OMML inside `<a:r>`/`<a:t>` text runs (Office 2016+).

Both flavors share the LaTeX → AST conversion this package provides.

## Install

Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/PsychQuant/latex-math-swift.git", from: "0.1.0")
]
```

## Usage

```swift
import LaTeXMathSwift
import OOXMLSwift

let components = try LaTeXMathParser.parse("\\frac{a}{b}")
// → [MathFraction(numerator: [MathRun(text: "a")], denominator: [MathRun(text: "b")])]

let omml = components.map { $0.toOMML() }.joined()
// → "<m:f><m:num><m:r><m:t>a</m:t></m:r></m:num><m:den><m:r><m:t>b</m:t></m:r></m:den></m:f>"

// Caller wraps in Word- or PPTX-flavored container.
```

## Supported macros

| Family | Macros | OMML target |
|---|---|---|
| Fraction / Radical | `\frac{a}{b}`, `\sqrt{a}`, `\sqrt[n]{a}` | `MathFraction`, `MathRadical` |
| Sub / Superscript | `a_{b}`, `a^{b}`, `a_{b}^{c}`, `a^{c}_{b}` | `MathSubSuperScript` |
| Accent | `\hat{}`, `\bar{}`, `\tilde{}`, `\dot{}`, `\overline{}` | `MathAccent` (combining diacritics) |
| Delimiter | `\left(\right)`, `\left[\right]`, `\left\{\right\}`, `\left|\right|`, `\left\|\right\|` | `MathDelimiter` |
| N-ary | `\sum_{a}^{b}`, `\int_{a}^{b}`, `\prod_{a}^{b}` (with or without bounds) | `MathNary` |
| Function | `\ln`, `\sin`, `\cos`, `\tan`, `\log`, `\exp`, `\max`, `\min`, `\det` followed by `(...)` | `MathFunction` |
| Limit | `\sup_{x}`, `\inf_{x}`, `\lim_{x \to 0}` | `MathLimit` |
| Text | `\text{...}` | `MathRun(style: .plain)` |
| Greek | All ECMA-376 §22.1.2.93 lowercase + uppercase + variants (`\varepsilon`, `\vartheta`, `\varphi`, etc.) | `MathRun` (Unicode) |
| Operators | `\cdot`, `\times`, `\pm`, `\sim`, `\approx`, `\neq`, `\le`, `\ge`, `\to`, `\infty`, `\partial`, `\cdots`, `\mid`, ... | `MathRun` (Unicode) |

For macros not in this list, `LaTeXMathParser.parse()` throws `LaTeXParseError.unrecognizedToken(token: String)`. Callers needing full LaTeX coverage should pre-process via Pandoc or fall back to `che-word-mcp`'s `insert_equation(components:)` JSON tree input.

## Errors

```swift
public enum LaTeXParseError: Error {
    case empty
    case unrecognizedToken(token: String)
    case malformed(message: String)
}
```

## License

MIT — see [LICENSE](LICENSE).

## Related

- [`ooxml-swift`](https://github.com/PsychQuant/ooxml-swift) — OMML emitter (`MathComponent` types this package returns)
- [`che-word-mcp`](https://github.com/PsychQuant/che-word-mcp) — first consumer (Word `insert_equation` MCP tool)
