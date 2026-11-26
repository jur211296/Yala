# Maquetas: oferta Pro con el mes gratis y mazo centrado (25-nov-2026)

Artifact para decidir (público): https://claude.ai/artifact/GdiXuiPLjfWskDWgq45JMn
Card «Espera decisión» de Jürgen en el tablero de Yala 2.3: «Elegir: oferta Pro con el mes gratis y mazo centrado (maquetas)».
La decisión se guarda en la base del artifact (`decisiones/maquetas`: `oferta`, `mazo`, `nota`).

- `index.html`: la página publicada (maquetas en HTML, iPhone 14, claro y oscuro, con y sin derecho a la prueba).
- `maquetas-oscuro.jpg`, `maquetas-claro.jpg`: las dos filas de maquetas, tal como se ven en el artifact.

Recomendación: oferta **C** (el mes gratis dentro de la tarjeta «¡Primeros pasos completos!»; los días siguientes la
tarjeta de Pro usa el texto de A) y mazo **A** (centrado, sin texto nuevo).

Medido en `2.3` y que condiciona la elección: la hoja «Prueba Yala Pro 1 mes gratis» ya sube al terminar el paso 2
(`TrialOfferMoments.noteRecordStepFinished`) y no se repite al completar (`SetupCompleteTrialOfferLogic.offersAtCompletion`).
En Yala Dev no sube porque la App Store no da precios (`ProPlanStatusLogic.trialOfferDecision` → retenida). El mazo está
solo hasta que se hace el paso 1 (`PrimerosPasosPanelGate.showsBalanceHero`); las acciones rápidas vuelven tras el paso 2
(`SetupChecklistManager.isQuietArrival`).
