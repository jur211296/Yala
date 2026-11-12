---
id: icloud-restore-preview-counts-categories-twice
status: backlog
priority: low
area: "welcome, icloud"
created: 2026-11-05
updated: 2026-11-05
source: "QA en el iPhone de pruebas del 2026-11-05 · relacionado: card tablero-al-activar-la-nube-algunas-categorias-y-70nl"
---

# «Ya tienes datos en tu iCloud» cuenta 124 categorías y la pantalla siguiente 62

Al reinstalar Yala Dev y elegir iCloud privado, «Ya tienes datos en tu iCloud» dijo «1 registro, 2 cuentas, **124
categorías**»; tras «Traer mis datos», la confirmación «¡Hola Jur!» dijo **62**. 124 = 2 × 62: la primera cuenta
duplicados que la restauración funde. Una segunda vez, con los datos ya subidos, las dos dijeron 62. La persona ve dos
cifras distintas para lo mismo. Captura: `~/Claude/entregas/2026-11-05-qa-dispositivo-fisico-device-mcp/evidencia/hallazgo-restaurar-62-categorias.jpg`. iPhone 14, iOS 27.2, Yala Dev
sobre `origin/2.2` (#809).
