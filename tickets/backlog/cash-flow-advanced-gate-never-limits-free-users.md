---
id: cash-flow-advanced-gate-never-limits-free-users
status: backlog
priority: medium
area: cash-flow, pro
created: 2026-11-09
updated: 2026-11-09
source: revisión por vistas 2.3, zona 36 (docs/ux/revision-vistas-2.3/36-reportes-flujo/, hallazgos secundarios); consolidación de necesarias 2.3
---

# Decidir: el flujo de caja avanzado no limita a nadie, Free ve lo mismo que Pro

**Es una decisión de producto, no un arreglo.** La revisión de Reportes y Flujo vio que un usuario gratis ve lo mismo que
uno Pro en el flujo de caja (capturas b04-b09 de la zona 36). Leído en el código el 2026-11-09: `ProFeature.cashFlowAdvanced`
dice en su comentario que métodos, horizonte y gráficas avanzados son Pro (`Yala/App/Services/FeatureGateService.swift:21`),
pero no está en `isProOnly` (`:36`). Por eso el recorte de Free (3 meses adelante, ninguno atrás) y el aviso de Pro de
`CashFlowPlanViewModel` nunca actúan.

## Qué hay que decidir

A) Es a propósito: el flujo de caja es gratis entero. Se borra el recorte y el aviso, que son código que no actúa.
B) Se cierra: `cashFlowAdvanced` pasa a solo Pro y el recorte vuelve a actuar. Cambia lo que vive hoy un usuario gratis.

Sale de la consolidación de necesarias 2.3 (`docs/ux/revision-vistas-2.3/consolidacion-necesarias-2026-11/ficha.md`,
decisión 2). No entra en ningún lote hasta que se decida.
