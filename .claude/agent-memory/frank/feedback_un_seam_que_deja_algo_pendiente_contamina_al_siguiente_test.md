---
name: un-seam-que-deja-algo-pendiente-contamina-al-siguiente-test
description: `-uitest-reset` borra UserDefaults DESPUÉS de que `SessionState` lo leyó; una marca pendiente sobrevive en memoria y tapa el test siguiente.
metadata:
  type: feedback
---

Si un seam (o un flujo) deja una marca pendiente que `SessionState` lee en su `init` (`needsPostOnboardingTrial`), `-uitest-reset`
no basta: hay que bajarla también en memoria en el bloque de hooks del arranque uitest.

**Why:** gate del 2026-10-19: once XCUITest en rojo con «el avatar de Perfil existe pero NO es alcanzable»; la debug description del
avatar mostraba la oferta de prueba encima. Aislados pasaban. Mi seam `-uitest-pending-trial-offer` lo hacía más probable.

**How to apply:** ante un rojo «algo lo tapa» que pasa aislado, exporta los adjuntos del `.xcresult`
(`xcresulttool export attachments`) y lee la debug description del elemento: dice qué hay encima. No lo atribuyas a flakiness.
