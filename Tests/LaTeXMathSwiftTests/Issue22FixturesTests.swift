import XCTest
@testable import LaTeXMathSwift
import OOXMLSwift

/// 18 fixture equations from `PsychQuant/che-word-mcp#22`.
/// All MUST parse without throwing; OMML output is exercised but not pinned to
/// exact strings (XML attribute order varies; `Tests/CheWordMCPTests/InsertEquationGoldenTests.swift`
/// in the consumer repo asserts the docx round-trip end-to-end).
final class Issue22FixturesTests: XCTestCase {

    private static let fixtures: [(label: String, latex: String)] = [
        ("EQ1",  "R_{t} = \\ln(P_{t}) - \\ln(P_{t-1})"),
        ("EQ2",  "JB = \\frac{N}{6}\\left(S^{2} + \\frac{(K-3)^{2}}{4}\\right)"),
        ("EQ3",  "Q = T(T+2) \\sum_{k=1}^{p} \\frac{\\hat{\\rho}_{k}^{2}}{T-k}"),
        ("EQ4",  "\\Delta Y_{t} = \\alpha + \\beta Y_{t-1} + \\sum_{i=1}^{p} \\delta_{i} \\Delta Y_{t-i} + \\varepsilon_{t}"),
        ("EQ5",  "\\hat{\\varepsilon}_{t}^{2} = \\alpha_0 + \\alpha_1 \\hat{\\varepsilon}_{t-1}^{2} + \\cdots + \\alpha_q \\hat{\\varepsilon}_{t-q}^{2} + u_t"),
        ("EQ6",  "D = \\sup_{x} \\left\\| F_1(x) - F_2(x) \\right\\|"),
        ("EQ7",  "R_{t} = \\phi_{0} + \\phi_{1} R_{t-1} + \\varepsilon_{t}, \\quad \\varepsilon_{t} \\mid \\Omega_{t-1} \\sim N(0, h_{t})"),
        ("EQ8",  "h_{t} = \\omega + \\alpha \\varepsilon_{t-1}^{2} + \\beta h_{t-1}"),
        ("EQ9",  "h_{t} = \\omega + \\alpha \\varepsilon_{t-1}^{2} + \\beta h_{t-1} + \\gamma D"),
        ("EQ10", "\\sigma^2 = \\frac{\\omega}{1 - \\alpha - \\beta}"),
        ("EQ11", "h_{t} = \\frac{\\omega}{1-\\beta} + \\alpha \\sum_{i=0}^{\\infty} \\beta^{i} \\varepsilon_{t-1-i}^{2}"),
        ("EQ12", "h_{t} = \\omega + \\alpha \\varepsilon_{t-1}^{2} + \\beta h_{t-1} + \\theta S_{t-1}^{-} \\varepsilon_{t-1}^{2} + \\gamma D"),
        ("EQ13", "\\ln(h_{t}) = \\omega + \\alpha \\left\\| \\frac{\\varepsilon_{t-1}}{\\sqrt{h_{t-1}}} \\right\\| + \\gamma^{*} \\frac{\\varepsilon_{t-1}}{\\sqrt{h_{t-1}}} + \\beta \\ln(h_{t-1})"),
        ("EQ14", "\\ln(h_{t}) = \\omega + \\alpha \\left\\| z_{t-1} \\right\\| + \\gamma^{*} z_{t-1} + \\beta \\ln(h_{t-1}) + \\delta D"),
        ("EQ15", "R_{t} = \\phi_{0} + \\phi_{1} R_{t-1} + \\lambda \\sigma_{t} + \\varepsilon_{t}"),
        ("EQ16", "HL = \\frac{\\ln(0.5)}{\\ln(\\text{persistence})}"),
        ("EQ17", "LR = -2\\left(\\ln L_{\\text{full}} - \\ln L_{\\text{pre}} - \\ln L_{\\text{post}}\\right)"),
        ("EQ18", "t = \\frac{\\hat{\\theta}_{\\text{post}} - \\hat{\\theta}_{\\text{pre}}}{\\sqrt{SE(\\hat{\\theta}_{\\text{post}})^{2} + SE(\\hat{\\theta}_{\\text{pre}})^{2}}}"),
    ]

    func testAll18FixtureEquationsParseWithoutThrowing() throws {
        for fixture in Self.fixtures {
            do {
                let result = try LaTeXMathParser.parse(fixture.latex)
                XCTAssertFalse(result.isEmpty, "\(fixture.label) parsed to empty result")
            } catch {
                XCTFail("\(fixture.label) failed: \(error)\n  LaTeX: \(fixture.latex)")
            }
        }
    }

    func testAll18FixtureEquationsEmitNonEmptyOMML() throws {
        for fixture in Self.fixtures {
            let result = try LaTeXMathParser.parse(fixture.latex)
            let omml = result.map { $0.toOMML() }.joined()
            XCTAssertFalse(omml.isEmpty, "\(fixture.label) OMML was empty")
            // Sanity: OMML never contains residual LaTeX backslashes from
            // unrecognized tokens (which would mean parsing succeeded but
            // structure is wrong).
            XCTAssertFalse(omml.contains("\\frac"), "\(fixture.label) OMML contains residual \\frac")
            XCTAssertFalse(omml.contains("\\sum"), "\(fixture.label) OMML contains residual \\sum")
            XCTAssertFalse(omml.contains("\\hat"), "\(fixture.label) OMML contains residual \\hat")
            XCTAssertFalse(omml.contains("\\left"), "\(fixture.label) OMML contains residual \\left")
        }
    }

    func testEQ3HasNestedFractionWithAccent() throws {
        // EQ3 specifically exercises the previously-broken case from issue #22:
        // \frac inner contains \hat which used to throw.
        let result = try LaTeXMathParser.parse("Q = T(T+2) \\sum_{k=1}^{p} \\frac{\\hat{\\rho}_{k}^{2}}{T-k}")
        let omml = result.map { $0.toOMML() }.joined()
        XCTAssertTrue(omml.contains("<m:nary>"))
        XCTAssertTrue(omml.contains("<m:f>"))
        XCTAssertTrue(omml.contains("<m:acc>"))
    }
}
