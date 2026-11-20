---
id: 2026-11-20-oferta-de-un-mes-se-cae-en-silencio
status: backlog
priority: medium
area: "pro, primeros-pasos, storekit"
created: 2026-11-20
updated: 2026-11-20
source: "maquetas de Primeros pasos, 20-nov (tema 4)"
---

# La oferta de un mes de Pro del final de Primeros pasos se cae sin avisar

Jürgen nunca la ve. Medido el 20-nov en el simulador (build Debug-Dev de 2.3, precios de prueba): al cerrar el paso 7
sube a los 1,6 s. El código tiene cinco cortes silenciosos, y basta uno:

1. Un paso del mazo sin hacer ni omitir: `checkAllComplete` no dispara nunca `onAllStepsCompleted`.
2. Instalación sin mazo (`showsDeck` falso: venía de 2.2 o «Ya tengo una cuenta»): no se apunta `pendingOfferKey` y sale `ProTrialOfferSheet`.
3. Pro activo (`TrialOfferMomentLogic.arms` y `shouldSubmit` lo excluyen), incluido el interruptor Pro de Yala Dev.
4. Sin derecho a la prueba (`ProPlanStatusLogic.trialOfferDecision` → `.dropForever`), p. ej. la cuenta de Sandbox que ya compró.
5. Precios sin cargar (`.holdForLater`): espera al siguiente arranque.

**Inferido, sin medir en el iPhone de Jürgen:** el 4 (Sandbox ya usada) o el 1. Para confirmarlo, abrir Yala Dev en el
iPhone 14 con la consola de Xcode al terminar el paso 7. Ninguno deja rastro en Console ni en telemetría.

## Hecho cuando

Lo que decida Jürgen en el tema 4 del artifact (momento de la oferta) está implementado, y cada corte deja una línea en
Console (`#if DEBUG`) o un evento de telemetría que diga por qué no salió.
