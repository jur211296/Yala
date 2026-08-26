---
id: yala-android
status: backlog
priority: low
area: general
created: 2026-03-29
updated: 2026-08-26
source: YalaWiki/Backlog/future_yala-android.md
---


# Yala para Android

## Contexto
> Swift 6.3 (marzo 2026) incluye el primer SDK oficial de Swift para Android. El Android Workgroup de swift.org respalda el esfuerzo. Esto abre la puerta a una versión Android de Yala compartiendo lógica de negocio en Swift.

## Qué se puede compartir (lógica pura, sin dependencias Apple)
- **Calculators:** InsightsCalculator, CashFlowProjectionCalculator, SplitCalculator, WeekdaySpendingCalculator, BalanceTrendCalculator, etc. (`Yala/App/Logic/Calculators/`, 19 archivos verificados 2026-07-01)
- **Servicios de lógica:** FilterService, CurrencyConverter, AmountParser, DateParser, MoneyParsing
- **Modelos de dominio** y reglas de negocio (structs puros)
- **Utilidades:** `CurrencyCode` (enum dentro de `Yala/Utils/CurrencyUtils.swift`, SSOT de divisas — no es un archivo separado), formatters, validadores
- Estimado: ~20-30% del codebase actual — **verificado 2026-07-01**: 167 de
  669 archivos Swift del target (~25%) no importan `SwiftUI`/`SwiftData`/
  `UIKit`, consistente con la estimación original. La app creció bastante
  desde marzo (21 modelos SwiftData, 61 servicios, 65 helpers pure-logic en
  `Yala/App/Logic/`, ver `CODEBASE-MAP.md`) pero la proporción de lógica
  pura se mantiene en ese rango.

## Qué NO se puede compartir (reescritura necesaria)
- **UI completa** — SwiftUI no existe en Android, necesitaría Jetpack Compose o similar
- **SwiftData** — exclusivo Apple, necesitaría Room/SQLite o equivalente
- **Frameworks Apple:** StoreKit, CloudKit, WidgetKit, UserNotifications, Vision
- **Integraciones sistema:** Shortcuts, Live Activities, App Intents

## Tecnologías clave
- **Swift SDK for Android** — compilación Swift → Android
- **Swift Java / Swift Java JNI Core** — interop con Kotlin/Java
- **Android Workgroup** — soporte oficial swift.org

## Estrategia propuesta
1. **Fase 0 — Preparar codebase iOS:** Extraer lógica pura a un Swift Package separado (sin imports de SwiftUI/SwiftData/UIKit). Esto beneficia también la testabilidad en iOS. **Verificado 2026-07-01: Fase 0 NO ha comenzado** — no existe ningún `Package.swift` propio del proyecto (solo checkouts de dependencias de terceros bajo `.spm/`/`.deriveddata/`). Los calculators/logic helpers siguen viviendo dentro del target de la app (`Yala/App/Logic/`), sin extraer.
2. **Fase 1 — Validar:** Compilar el package de lógica pura para Android. Verificar que calculators y parsers pasan tests en ambas plataformas.
3. **Fase 2 — Prototipo Android:** UI mínima en Kotlin/Compose consumiendo el módulo Swift. Pantalla de transacciones + estadísticas básicas.
4. **Fase 3 — App completa:** Persistencia (Room), sync, suscripciones (Google Play Billing), notificaciones.

## Referencias
- [Swift SDK for Android — swift.org](https://www.swift.org/blog/exploring-the-swift-sdk-for-android/)
- [Android Workgroup — swift.org](https://www.swift.org/android-workgroup/)
- [Swift 6.3 Android SDK — Thurrott](https://www.thurrott.com/dev/334219/swift-6-3-brings-first-sdk-for-android)
- [Anuncio 9to5Google](https://9to5google.com/2026/03/28/swift-a-coding-language-developed-by-apple-now-offers-official-android-support/)

## Notas
- El SDK es muy nuevo (marzo 2026) — esperar maduración antes de invertir fuerte
- Monitorear: soporte de debugging, tooling, y adopción por la comunidad
- Prerequisito natural: que Yala iOS esté estable y con tracción suficiente para justificar la inversión
- **Verificado 2026-07-01**: el toolchain local ya corre Swift 6.4
  (`swiftlang-6.4.0.23.5`, más nuevo que el Swift 6.3 de marzo citado como
  hito habilitante) y `IPHONEOS_DEPLOYMENT_TARGET = 26.0` — sin cambios al
  argumento del ticket, solo confirma que no hay bloqueo de toolchain del
  lado iOS para eventualmente iniciar la Fase 0 cuando se decida invertir.

migrated from YalaWiki Backlog/future_yala-android.md @ 1934e8ad
