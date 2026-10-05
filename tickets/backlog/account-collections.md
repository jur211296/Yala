---
id: account-collections
status: backlog
priority: low
area: "accounts, filters"
created: 2026-10-03
updated: 2026-10-03
source: idea de Jürgen el 2026-10-03, durante el rediseño de cuentas
---

# Colecciones de cuentas: agrupar cuentas para filtrarlas juntas

## La idea

Poder juntar cuentas en una colección con nombre («Casa», «Negocio») y filtrar el Panel por ella de un toque. Una
versión mínima serían **favoritas**, pero es una colección con un solo nombre, así que conviene empezar por las
colecciones.

- **No se llama «grupos»**: Yala ya usa «Grupos» para los gastos compartidos.
- Vive como fila en Ajustes › Cuentas (`accounts-settings-list-redesign`) y como atajo en la hoja de filtros.
- Es un **dato nuevo**: modelo SwiftData con CloudKit y su campo en el Modo Nube. Por eso es otro desarrollo.

Mientras tanto, el filtro de la toolbar del Panel ya deja elegir varias cuentas (`panel-accounts-redesign`).
