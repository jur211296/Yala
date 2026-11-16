---
id: onboarding-2-3-where-money-goes-step
status: done
priority: high
area: onboarding
created: 2026-11-12
updated: 2026-11-12
source: tablero-bienvenida-2-3-paso-6-mira-a-donde-va-tu-3fcj (docs/onboarding-2-3/SPEC.md, Y23-14)
qa-status: pass
qa-date: 2026-11-12
qa-notes: simulador iPhone 17 Pro iOS 27.2 - tocar el paso abre «Tus gráficas viven en Más»; «Omitir» pasa el mazo al 7 (antes se quedaba en el 6), medido antes y después con capturas; XCUITest y unit
---
# Bienvenida 2.3 · Paso 6 · Mira a dónde va tu dinero (Y23-14)

La guía y sus textos («Tus gráficas viven en Más», «Todas tus gráficas», con el foco en Resumen, Tendencias y
Distribución) ya los había dejado el lote 01, idénticos a la ficha, y terminarla daba el paso por hecho. Faltaba lo del
prototipo: **«Omitir» en la guía (o tocar fuera) da el paso por omitido y el mazo pasa al 7**. Irse a otra pestaña la
cierra sin tocar el mazo. El disparador «días después» (Y23-15, lote 01) no cambia.

Pruebas: `YalaTests/Bienvenida23FinalTests` (chartsStep_*) y
`YalaUITests/Flows/Bienvenida23FinalUITests#test_step6_skippingTheGuide_movesTheDeckToStep7`.
