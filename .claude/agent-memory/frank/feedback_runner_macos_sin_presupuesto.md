---
name: runner-macos-sin-presupuesto
description: Jürgen no paga minutos extra del runner macOS del CI; un job nuevo en xcode-27 se pregunta con el coste medido y la respuesta por defecto es no
metadata:
  type: feedback
---

No se añaden jobs nuevos en el runner macOS del CI (`xcode-27`) sin presupuesto aprobado: se cobra por minuto y Jürgen dijo «NO» el 2026-11-17 al job de interfaz por PR (~59 min de macOS por PR, ~10 h/día), aunque la propuesta P2 ya estaba aprobada.

**Why:** «Aprobar la propuesta» no aprobó el gasto; el encargo lo marcaba como vital y la medida lo hizo visible. Lo que sí vale: lo que corre gratis (gate local en la Mini/Max, jobs en ubuntu).

**How to apply:** Ante cualquier verificación nueva que pida macOS en CI, mide el coste por PR y por día ANTES de construir el job, y ofrece la variante local (gate) como recomendada. Escribir el job antes de la respuesta costó retirarlo después ([[gasto-a-la-medida-del-trafico]]).
