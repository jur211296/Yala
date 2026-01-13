# Neto (iOS)

## Producto
Neto es una app iOS de finanzas personales. Objetivo: entender gastos, cuentas, presupuestos y reportes con claridad.

## Stack
- Swift, SwiftUI
- Persistencia: SwiftData
- Proyecto: .xcodeproj
- Scheme principal: Neto
- Unit tests: NetoTests
- UI tests: NetoUITests

## SwiftData (fuente de verdad)
El ModelContainer se configura en NetoApp.swift con estas entidades:
Category, Subcategory, Tag, Account, TransactionItem, Budget, ExchangeRate, FavoritePayment

## Flujo de trabajo obligatorio (para ahorrar tokens y reducir retrabajo)
1) Plan corto antes de editar (qué cambias y por qué)
2) Implementar mínimo que compila
3) Ejecutar /verify-ios
4) Si aplica, ejecutar /test-ios
5) Commit pequeño con /commit-one

## Reglas de cambio
- Evitar refactors grandes si no son necesarios para el feature actual
- No introducir dependencias nuevas sin justificación
- Mantener separación clara entre UI, lógica y capa SwiftData
