import Testing
@testable import Yala

/// Regression coverage for the `.considerate` variant of
/// `L10n.Insights.ruleDominantSharedCategory(_:_:tone:)`.
///
/// The bug: the `.considerate` localized template had its placeholders in the
/// order `%d ... %@` WITHOUT positional specifiers, while the Swift signature
/// passes `(name: String, pct: Int)` positionally. `String(format:)` then bound
/// the `String` name into `%d` and the `Int` pct into `%@`, treating the integer
/// as an object pointer → `EXC_BAD_ACCESS` at render time.
///
/// The fix uses positional specifiers (`%2$d%% ... %1$@`) so the placeholder
/// order is independent of the argument order. These tests are pure-logic: the
/// function only consumes a `String` + `Int` and returns a `String` (no
/// ModelContext, no SwiftData, no UI). Simply invoking it with `.considerate`
/// would crash under the old template; it now returns a well-formed string.
struct InsightDominantSharedCategoryFormatTests {

    /// A distinctive category name that won't collide with any localized
    /// template wording, so we can assert it survived into the output verbatim.
    private let categoryName = "ZZQ_Food_Marker"

    // MARK: - The bug case (.considerate)

    @Test func considerateTone_doesNotCrashAndKeepsNameAndPercent() {
        let result = L10n.Insights.ruleDominantSharedCategory(categoryName, 60, tone: .considerate)

        // Resolved (not the raw key) and non-empty → the localized value was found.
        #expect(!result.isEmpty)
        #expect(result != "insights.ruleDominantSharedCategory.considerate")

        // The String arg landed in the %@/%1$@ slot (proves it wasn't fed to %d
        // and that the Int wasn't sent to %@ → no EXC_BAD_ACCESS).
        #expect(result.contains(categoryName))

        // The Int arg landed in the %d/%2$d slot, rendered as "60".
        #expect(result.contains("60"))
    }

    // MARK: - The other tones (already correct, must stay safe)

    @Test func normalTone_keepsNameAndPercent() {
        let result = L10n.Insights.ruleDominantSharedCategory(categoryName, 75, tone: .normal)

        #expect(!result.isEmpty)
        #expect(result != "insights.ruleDominantSharedCategory.normal")
        #expect(result.contains(categoryName))
        #expect(result.contains("75"))
    }

    @Test func sarcasticTone_keepsNameAndPercent() {
        let result = L10n.Insights.ruleDominantSharedCategory(categoryName, 90, tone: .sarcastic)

        #expect(!result.isEmpty)
        #expect(result != "insights.ruleDominantSharedCategory.sarcastic")
        #expect(result.contains(categoryName))
        #expect(result.contains("90"))
    }

    // MARK: - Edge cases

    @Test func considerateTone_zeroPercent() {
        // Degenerate but valid input — must still bind cleanly and not crash.
        let result = L10n.Insights.ruleDominantSharedCategory(categoryName, 0, tone: .considerate)

        #expect(!result.isEmpty)
        #expect(result.contains(categoryName))
        #expect(result.contains("0"))
    }

    @Test func considerateTone_emptyName() {
        // Empty name shouldn't crash; the percentage must still render.
        let result = L10n.Insights.ruleDominantSharedCategory("", 42, tone: .considerate)

        #expect(!result.isEmpty)
        #expect(result.contains("42"))
    }

    @Test func considerateTone_nameWithPercentLiteral() {
        // A name containing a stray '%' must not be re-interpreted as a format
        // specifier: arguments are not re-parsed by String(format:).
        let trickyName = "50% Off Club"
        let result = L10n.Insights.ruleDominantSharedCategory(trickyName, 12, tone: .considerate)

        #expect(!result.isEmpty)
        #expect(result.contains(trickyName))
        #expect(result.contains("12"))
    }

    // MARK: - All tones exhaustive (CaseIterable) — defense against future regressions

    @Test func allTones_renderWithoutCrash() {
        for tone in InsightTone.allCases {
            let result = L10n.Insights.ruleDominantSharedCategory(categoryName, 55, tone: tone)
            #expect(result.contains(categoryName), "tone \(tone.rawValue) lost the name")
            #expect(result.contains("55"), "tone \(tone.rawValue) lost the percent")
        }
    }
}
