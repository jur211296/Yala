---
name: el-tope-cambia-el-orden-propio-a-orden-de-llegada
description: Acotar lo GUARDADO y decidir con lo ENTRANTE hace que el orden propio dependa del orden de llegada; y una key desconocida en un pull de prefs no es inerte en tests
metadata:
  type: feedback
---

Diseñé el tope a un HLC futuro (hlc01, 2026-10-07) creyendo que «decidir con el entrante sin acotar» conservaba el orden
propio del teléfono adelantado. La lente de extremo a extremo lo tumbó: solo si sus cambios LLEGAN en orden. Grupos subía
por `createdAt` (hora de drenado) y el cambio drenado con la hora adelantada quedaba fechado después: el viejo pisaba al
nuevo. Lo arregló subir en orden de HLC (`HLC.uploadOrder`); el reintento de un fallo parcial quedó como residual.

**Why:** un cambio de la regla de comparación del servidor desplaza la garantía a un sitio que nadie miraba (el orden de
subida del cliente). Las lentes de servidor y de cliente no lo vieron; la de escenarios multi-dispositivo sí.

**How to apply:** cuando un arreglo de LWW recorte o normalice lo guardado, pregunta qué orden del cliente pasa a ser
contrato y búscalo en el código de subida. Y en tests de `CloudSyncRuntime`: una página de prefs NO vacía corre
`applyMergeOutcome` y escribe `SessionState.shared` (rompió `StatisticsRecalculationTests` en la suite completa); ver la
regla en `testing.md`. Relacionado: [[review-adversarial-caza-lo-mio]], [[la-rule-de-area-es-una-lente-mas]].
