# External Integrations

**Analysis Date:** 2026-01-15

## APIs & External Services

**Exchange Rate API (exchangerate.host):**
- Provider: https://api.exchangerate.host
- Purpose: Currency conversion for multi-currency transactions
- Service File: `Neto/Services/ExchangeRateAPIService.swift`
- Protocol: `Neto/Services/ExchangeRateProvider.swift` (`ExchangeRateProviderProtocol`)
- Auth: API key in `EXCHANGE_RATE_API_KEY` build setting
- Configuration: `Neto/Secrets.xcconfig` (gitignored)
- Endpoints Used:
  - `/live` - Current exchange rates
  - `/timeframe` - Historical rates (up to 365 days)
- Supported Currencies: USD, PEN, EUR
- Rate Limiting: Handles 429 (Too Many Requests) responses
- Timeouts: 30s (live), 60s (historical)

**Payment Processing:**
- Not detected

**Email/SMS:**
- Not detected

**Analytics:**
- Not detected (no Firebase, Amplitude, Mixpanel)

**Crash Reporting:**
- Not detected (no Crashlytics, Sentry)

## Data Storage

**Local Database:**
- SwiftData (on-device persistence)
- Configuration: `Neto/App/NetoApp.swift` (ModelContainer setup)
- 8 Core Entities: Category, Subcategory, Tag, Account, TransactionItem, Budget, ExchangeRate, FavoritePayment

**Cloud Storage:**
- Not detected (no CloudKit, iCloud integration)

**File Storage:**
- Local file system only
- CSV/Excel import from user files

**Caching:**
- Exchange rates cached in SwiftData (`ExchangeRate` model)
- Updated via daily background task

## Authentication & Identity

**Auth Provider:**
- None (local-only app, no user authentication)

**OAuth Integrations:**
- None

## Monitoring & Observability

**Error Tracking:**
- Not detected

**Analytics:**
- Not detected

**Logs:**
- Console print statements (debug only)
- No structured logging framework

## CI/CD & Deployment

**Hosting:**
- App Store distribution (standard iOS app)

**CI Pipeline:**
- Not detected (no GitHub Actions, Fastlane configs found)

## Environment Configuration

**Development:**
- Required: `Neto/Secrets.xcconfig` with `EXCHANGE_RATE_API_KEY`
- Local SwiftData database
- No mock services configured

**Production:**
- API key embedded via build settings
- On-device SwiftData storage
- No server-side components

## Background Tasks

**Daily Refresh:**
- Identifier: `com.jurgenschmidt.finaria.daily`
- Configuration: `Neto/Resources/Info.plist` (BGTaskSchedulerPermittedIdentifiers)
- Handler: `Neto/Services/BackgroundJobs.swift`
- Purpose: Update exchange rates daily

## Localization

**Supported Languages:**
- English (en) - `Neto/Resources/en.lproj/Localizable.strings`
- Spanish (es) - `Neto/Resources/es.lproj/Localizable.strings`

**Localization System:**
- Type-safe L10n enum: `Neto/Utils/L10n.swift`
- Pattern: `L10n.Panel.accounts`, `L10n.Tab.statistics`

## Webhooks & Callbacks

**Incoming:**
- None

**Outgoing:**
- None

---

*Integration audit: 2026-01-15*
*Update when adding/removing external services*
