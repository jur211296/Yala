# Neto

App iOS de finanzas personales (SwiftUI) para registrar y entender gastos, cuentas, presupuestos y reportes con claridad.

## Stack

- **Persistencia:** SwiftData
- **ModelContainer:** `NetoApp.swift`
- **Entidades:** Category, Subcategory, Tag, Account, TransactionItem, Budget, ExchangeRate, FavoritePayment

## Proyecto

- **Archivo:** `Neto.xcodeproj`
- **Scheme:** Neto
- **Unit Tests:** NetoTests
- **UI Tests:** NetoUITests

## Regla Operativa

Cambios pequeños e incrementales.

Antes de commit:
1. Ejecutar `/verify-ios`
2. Si aplica, ejecutar `/test-ios` o `/uitest-ios`
3. Commits atómicos con `/commit-one`

## Restricciones

- Evitar refactors grandes
- Evitar dependencias nuevas sin justificación

## Prioridades de Desarrollo

1. **Automatización** - Transacciones recurrentes, categorización inteligente
2. **Insights financieros** - Mejores analíticas, predicciones, recomendaciones
3. **Sincronización** - iCloud sync, soporte multi-dispositivo

## Deuda Técnica Conocida

Ver `.planning/codebase/CONCERNS.md`

---

*Actualizar cuando el alcance del proyecto evolucione*
