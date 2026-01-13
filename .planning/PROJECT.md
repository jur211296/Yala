# Neto - Project Definition

**Created:** 2026-01-13
**Status:** Active Development

## Vision

Neto is a personal finance iOS app for the general public that helps users understand their spending, manage accounts, track budgets, and gain financial insights with clarity and simplicity.

## Target Users

- General public via App Store
- Users seeking intuitive personal finance tracking
- People who want automated categorization and insights
- Multi-device users needing data sync

## Core Value Proposition

A native iOS finance app that combines ease of use with powerful analytics, automation, and cross-device sync.

## Current State (Brownfield)

Existing codebase with:
- 149 Swift files, 8 SwiftData models
- Transaction tracking with multi-currency support
- Category/subcategory organization with budgets
- Statistics views with charts and trends
- CSV/Excel import/export
- Exchange rate integration

See `.planning/codebase/` for detailed analysis.

## Development Priorities

1. **Automation** - Recurring transactions, smart categorization
2. **Financial insights** - Better analytics, predictions, recommendations
3. **Data sync** - iCloud sync, multi-device support

## Timeline

Rapid iteration with weekly milestones.

## Technical Constraints

- iOS 26.1+ deployment target
- Swift 5.0, SwiftUI, SwiftData
- MVVM architecture with @Observable
- No new dependencies without justification

## Quality Standards

- Build must pass before commits
- Follow existing conventions (see CONVENTIONS.md)
- Atomic, focused commits via /commit-one

## Known Technical Debt

From CONCERNS.md:
- Hardcoded API key fallback in ExchangeRateAPIService
- Large view files (TrendsTabView, CategoriesTabView ~1,200 lines)
- Missing tests for TransactionCSVImportService
- DispatchQueue usage instead of Task API

## Success Criteria

- Features ship incrementally in weeks
- App Store ready quality
- Maintains performance with growing data
- Clean, maintainable codebase

---

*Update this document as project scope evolves*
