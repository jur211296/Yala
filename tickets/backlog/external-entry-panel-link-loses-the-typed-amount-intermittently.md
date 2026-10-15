---
id: external-entry-panel-link-loses-the-typed-amount-intermittently
status: backlog
priority: medium
area: testing
created: 2026-10-15
updated: 2026-10-15
source: gate del lote 15 de la auditoría UX 2.2 (encargo 2026-10-15-auditoria-ux-2-2-lote-15-desde-fuera)
---

# `ExternalEntryForeignSheetUITests` pierde a veces el importe escrito tras el enlace al Panel

## Medido (2026-10-15, iPhone 17 Pro, iOS 27.0, `Yala Dev`, rama del lote 15 sobre `origin/2.2`)

- En la corrida del gate (11 suites, 40 casos, centinela «estuviste solo»), un rojo:
  `test_halfFilledFormInAnotherTab_panelLink_keepsTheForm` → «El importe escrito se perdió (valor: «0.00»)»
  (`ExternalEntryForeignSheetUITests.swift:184`).
- El mismo caso aislado, dos veces seguidas en el mismo simulador: verde las dos (34 s y 32 s).
- El camino que prueba (`yala://panel` → `setOrDeferDeepLink(.panel)`) no lo tocó el lote 15.

## Hipótesis (sin medir)

Familia de la regla de `.claude/rules/testing.md` sobre `typeText` en iOS 27.0: el teclado sigue entrando y lo escrito
no llega entero al campo antes de salir a segundo plano. Si es eso, es el test y no el producto.

## Hecho cuando

- Se mide si el valor se pierde en la app (el campo vacío tras volver) o en la escritura del test, con N corridas.
- Arreglado el que toque, o en la Lista Negra con dueño y fecha.
