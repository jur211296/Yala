# External Integrations

**Analysis Date:** 2026-01-15
**Updated:** 2026-03-24

## APIs & External Services

**Exchange Rate API (exchangerate.host):**
- Provider: https://api.exchangerate.host
- Purpose: Currency conversion for multi-currency transactions
- Service File: `Yala/Services/ExchangeRateAPIService.swift`
- Protocol: `Yala/Services/ExchangeRateProvider.swift` (`ExchangeRateProviderProtocol`)
- Auth: API key in `EXCHANGE_RATE_API_KEY` build setting
- Configuration: `Yala/Secrets.xcconfig` (gitignored)
- Endpoints Used:
  - `/live` - Current exchange rates
  - `/timeframe` - Historical rates (up to 365 days)
- Supported Currencies: 48 currencies via `CurrencyCode` enum
- Rate Limiting: Handles 429 (Too Many Requests) responses
- Timeouts: 30s (live), 60s (historical)

**OpenAI API (GPT-4.1 Mini):**
- Purpose: AI insights narrativas para usuarios Pro
- Service File: `Yala/Services/InsightsLLMService.swift`
- Auth: API key via `Secrets.xcconfig` + `Bundle.main.object(forInfoDictionaryKey:)`
- Gating: Solo Pro, on-demand (boton generar)
- Privacy: Solo datos agregados, nunca transacciones individuales

**StoreKit 2:**
- Purpose: Suscripciones Pro (mensual/anual)
- Service File: `Yala/App/Services/StoreKitManager.swift`
- Products: configurados en App Store Connect
- Gating: `FeatureGateService.swift`

**TelemetryDeck:**
- Purpose: Analytics privacy-first
- Service File: `Yala/Services/TelemetryService.swift`
- Privacy: No PII, datos agregados, GDPR compliant

## Cloud & Sync

**iCloud (CloudKit):**
- Purpose: Sync de datos SwiftData entre dispositivos
- Config: CloudKit container en entitlements
- Service: `Yala/Services/iCloudSyncService.swift` (monitor estado)
- Preferences: `Yala/App/Services/PreferenceSyncService.swift` (iCloud KV)
- Dedup: `Yala/App/Services/CategoryDeduplicationService.swift` (merge post-sync)
- Compatibilidad: Nunca `@Attribute(.unique)`, defaults en todo, relaciones optional

## Data Storage

**SwiftData (local + iCloud):**
- Configuration: `Yala/App/SwiftDataConfiguration.swift`
- 15 Core Entities: Category, Subcategory, Tag, Account, TransactionItem, Budget, ExchangeRate, FavoritePayment, ScheduledPayment, InboxDraft, MerchantMemory, NotificationItem, CashFlowPlan, CashFlowLine, CashFlowOverride

**Caching:**
- Exchange rates cached in SwiftData (`ExchangeRate` model)
- Updated via daily background task

## Localization

**Supported Languages:** 6
- Spanish (es), English (en), German (de), French (fr), Italian (it), Portuguese (pt)
- System: Type-safe `L10n` enum via `Yala/Utils/L10n.swift`

## Background Tasks

**Daily Refresh:**
- Identifier: `com.jurgenschmidt.yala.daily`
- Handler: `Yala/Services/BackgroundJobs.swift`
- Purpose: Exchange rates, scheduled payment notifications, budget alerts

## Local Notifications

- `Yala/Services/NotificationService.swift` — Core notifications
- `Yala/Services/ScheduledPaymentNotificationService.swift` — Payment reminders
- `Yala/Services/ReportNotificationService.swift` — Financial report notifications

## CI/CD & Deployment

- Distribution: App Store (standard)
- No CI pipeline (local builds)

---

*Integration audit: 2026-01-15*
*Last updated: 2026-03-24*
