import XCTest
@testable import LaTeXMathSwift
import OOXMLSwift

final class LaTeXMathParserTests: XCTestCase {

    // MARK: - Empty / error cases

    func testEmptyInputThrowsEmpty() {
        XCTAssertThrowsError(try LaTeXMathParser.parse("")) { err in
            XCTAssertEqual(err as? LaTeXParseError, .empty)
        }
    }

    func testWhitespaceInputThrowsEmpty() {
        XCTAssertThrowsError(try LaTeXMathParser.parse("   ")) { err in
            XCTAssertEqual(err as? LaTeXParseError, .empty)
        }
    }

    func testUnrecognizedMacroThrowsWithName() {
        XCTAssertThrowsError(try LaTeXMathParser.parse("\\overbrace{x}")) { err in
            guard case .unrecognizedToken(let token) = err as? LaTeXParseError else {
                XCTFail("expected unrecognizedToken, got \(err)")
                return
            }
            XCTAssertEqual(token, "\\overbrace")
        }
    }

    func testUnterminatedFractionThrowsMalformed() {
        XCTAssertThrowsError(try LaTeXMathParser.parse("\\frac{a}{b")) { err in
            guard case .malformed(let msg) = err as? LaTeXParseError else {
                XCTFail("expected malformed, got \(err)")
                return
            }
            XCTAssertTrue(msg.contains("unterminated") || msg.contains("expected"))
        }
    }

    // MARK: - Fraction / radical

    func testSingleFraction() throws {
        let result = try LaTeXMathParser.parse("\\frac{a}{b}")
        XCTAssertEqual(result.count, 1)
        guard let frac = result[0] as? MathFraction else {
            XCTFail("expected MathFraction"); return
        }
        XCTAssertEqual((frac.numerator[0] as? MathRun)?.text, "a")
        XCTAssertEqual((frac.denominator[0] as? MathRun)?.text, "b")
    }

    func testSquareRoot() throws {
        let result = try LaTeXMathParser.parse("\\sqrt{2}")
        XCTAssertEqual(result.count, 1)
        guard let rad = result[0] as? MathRadical else {
            XCTFail("expected MathRadical"); return
        }
        XCTAssertNil(rad.degree)
        XCTAssertEqual((rad.radicand[0] as? MathRun)?.text, "2")
    }

    func testCubeRoot() throws {
        let result = try LaTeXMathParser.parse("\\sqrt[3]{x}")
        guard let rad = result[0] as? MathRadical else {
            XCTFail("expected MathRadical"); return
        }
        XCTAssertNotNil(rad.degree)
        XCTAssertEqual((rad.degree?[0] as? MathRun)?.text, "3")
    }

    // MARK: - Sub / superscript normalization

    func testSubFirstThenSup() throws {
        let result = try LaTeXMathParser.parse("x_{k}^{2}")
        guard let ss = result[0] as? MathSubSuperScript else {
            XCTFail("expected MathSubSuperScript"); return
        }
        XCTAssertEqual((ss.sub?[0] as? MathRun)?.text, "k")
        XCTAssertEqual((ss.sup?[0] as? MathRun)?.text, "2")
    }

    func testSupFirstThenSubNormalizes() throws {
        let r1 = try LaTeXMathParser.parse("x^{2}_{k}")
        let r2 = try LaTeXMathParser.parse("x_{k}^{2}")
        guard
            let ss1 = r1[0] as? MathSubSuperScript,
            let ss2 = r2[0] as? MathSubSuperScript
        else {
            XCTFail("expected both MathSubSuperScript"); return
        }
        XCTAssertEqual((ss1.sub?[0] as? MathRun)?.text, (ss2.sub?[0] as? MathRun)?.text)
        XCTAssertEqual((ss1.sup?[0] as? MathRun)?.text, (ss2.sup?[0] as? MathRun)?.text)
        XCTAssertEqual(ss1.toOMML(), ss2.toOMML())
    }

    func testSingleCharScriptShorthand() throws {
        let result = try LaTeXMathParser.parse("x^2")
        guard let ss = result[0] as? MathSubSuperScript else {
            XCTFail("expected MathSubSuperScript"); return
        }
        XCTAssertEqual((ss.sup?[0] as? MathRun)?.text, "2")
    }

    // MARK: - Accent

    func testHatAccent() throws {
        let result = try LaTeXMathParser.parse("\\hat{x}")
        guard let acc = result[0] as? MathAccent else {
            XCTFail("expected MathAccent"); return
        }
        XCTAssertEqual(acc.accentChar, "\u{0302}")
        XCTAssertEqual((acc.base[0] as? MathRun)?.text, "x")
    }

    func testBarAccent() throws {
        let result = try LaTeXMathParser.parse("\\bar{x}")
        XCTAssertEqual((result[0] as? MathAccent)?.accentChar, "\u{0304}")
    }

    func testTildeAccent() throws {
        let result = try LaTeXMathParser.parse("\\tilde{x}")
        XCTAssertEqual((result[0] as? MathAccent)?.accentChar, "\u{0303}")
    }

    // MARK: - Delimiter

    func testParenDelimiter() throws {
        let result = try LaTeXMathParser.parse("\\left(x\\right)")
        guard let d = result[0] as? MathDelimiter else {
            XCTFail("expected MathDelimiter"); return
        }
        XCTAssertEqual(d.open, "(")
        XCTAssertEqual(d.close, ")")
    }

    func testDoubleBarDelimiter() throws {
        let result = try LaTeXMathParser.parse("\\left\\|x\\right\\|")
        guard let d = result[0] as? MathDelimiter else {
            XCTFail("expected MathDelimiter"); return
        }
        XCTAssertEqual(d.open, "‖")
        XCTAssertEqual(d.close, "‖")
    }

    func testBracketDelimiter() throws {
        let result = try LaTeXMathParser.parse("\\left[x\\right]")
        guard let d = result[0] as? MathDelimiter else {
            XCTFail("expected MathDelimiter"); return
        }
        XCTAssertEqual(d.open, "[")
        XCTAssertEqual(d.close, "]")
    }

    // MARK: - N-ary

    func testSumWithBothBounds() throws {
        let result = try LaTeXMathParser.parse("\\sum_{k=1}^{p} a")
        guard let nary = result[0] as? MathNary else {
            XCTFail("expected MathNary"); return
        }
        XCTAssertEqual(nary.op, .sum)
        XCTAssertNotNil(nary.sub)
        XCTAssertNotNil(nary.sup)
        XCTAssertEqual((nary.sup?[0] as? MathRun)?.text, "p")
    }

    func testBareSumWithoutBounds() throws {
        let result = try LaTeXMathParser.parse("\\sum a")
        guard let nary = result[0] as? MathNary else {
            XCTFail("expected MathNary"); return
        }
        XCTAssertNil(nary.sub)
        XCTAssertNil(nary.sup)
    }

    func testIntegralWithBounds() throws {
        let result = try LaTeXMathParser.parse("\\int_{0}^{1} x")
        XCTAssertEqual((result[0] as? MathNary)?.op, .integral)
    }

    // MARK: - Function name

    func testLnWithParen() throws {
        let result = try LaTeXMathParser.parse("\\ln(x)")
        guard let fn = result[0] as? MathFunction else {
            XCTFail("expected MathFunction"); return
        }
        XCTAssertEqual((fn.functionName[0] as? MathRun)?.text, "ln")
    }

    func testSinWithParen() throws {
        let result = try LaTeXMathParser.parse("\\sin(\\theta)")
        XCTAssertNotNil(result[0] as? MathFunction)
    }

    // MARK: - Limit

    func testSupWithSub() throws {
        let result = try LaTeXMathParser.parse("\\sup_{x} f")
        guard let lim = result[0] as? MathLimit else {
            XCTFail("expected MathLimit"); return
        }
        XCTAssertEqual(lim.position, .lower)
        XCTAssertEqual((lim.base[0] as? MathRun)?.text, "sup")
    }

    func testLimWithArrow() throws {
        let result = try LaTeXMathParser.parse("\\lim_{x \\to 0} f")
        XCTAssertNotNil(result[0] as? MathLimit)
    }

    // MARK: - Text macro

    func testTextMacroProducesPlainRun() throws {
        let result = try LaTeXMathParser.parse("\\text{persistence}")
        guard let run = result[0] as? MathRun else {
            XCTFail("expected MathRun"); return
        }
        XCTAssertEqual(run.text, "persistence")
        XCTAssertEqual(run.style, .plain)
    }

    // MARK: - Greek / variant

    func testVarepsilonMapsToGreekEpsilon() throws {
        let result = try LaTeXMathParser.parse("\\varepsilon")
        XCTAssertEqual((result[0] as? MathRun)?.text, "ε")
    }

    func testCapitalDelta() throws {
        let result = try LaTeXMathParser.parse("\\Delta")
        XCTAssertEqual((result[0] as? MathRun)?.text, "Δ")
    }

    // MARK: - Recursion stress

    func testFiveLevelNestedFraction() throws {
        let nested = "\\frac{\\frac{\\frac{a}{b}}{c}}{\\frac{d}{e}}"
        let result = try LaTeXMathParser.parse(nested)
        XCTAssertNotNil(result[0] as? MathFraction)
        // Sanity-check the OMML emit doesn't crash and contains expected structure.
        let omml = result[0].toOMML()
        XCTAssertTrue(omml.contains("<m:f>"))
    }

    // MARK: - Coalescing

    func testConsecutivePlainCharsCoalesceIntoOneRun() throws {
        let result = try LaTeXMathParser.parse("abc")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual((result[0] as? MathRun)?.text, "abc")
    }
}
