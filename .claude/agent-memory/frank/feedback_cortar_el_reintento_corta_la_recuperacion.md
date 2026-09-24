---
name: cortar-el-reintento-corta-la-recuperacion
description: Si un veredicto puede ser un falso positivo que el tiempo cura, el reintento ES la recuperación del legítimo; quitarlo «para cortar un bucle» lo deja sin salida, y el bucle suele tener otra puerta.
metadata:
  type: feedback
---

**Antes de quitarle a una salida su reintento «para que no entre en bucle», pregunta si el veredicto puede ser
falso y curarse solo. Si puede, el reintento es la recuperación del legítimo, no un bucle.**

**Why:** el 2026-09-24 (`migration-takeover-uploads-without-a-lineage-check`) la salida por linaje retiraba el sello
`.proceedMigration` para que «Reintentar → Migrar» parara en la puerta en vez de repetir 15 min. Dos lentes de la review lo
tumbaron: (1) no cortaba nada —el dispositivo seguía siendo líder y el adopt que la propia puerta recomienda volvía a
recibir `created`—, y (2) el falso bloqueo del relevo legítimo (import lento, identidades reparadas por dispositivo) se cura
cuando llegan los datos, y el reintento era su única vía. El precio de dejarlo lo paga el ajeno: 15 min por toque manual.

**How to apply:**

- Antes de cerrar un camino de vuelta, enumera TODAS las entradas que llegan al mismo estado (aquí: «Migrar», el adopt de
  Almacenamiento, el Welcome). Si otra lo reabre, el cierre es cosmético.
- Clasifica el veredicto: ¿definitivo de verdad, o «definitivo hasta que llegue algo»? En el segundo, el texto nombra la
  espera y el reintento, y el reintento se queda.
- Relacionado: [[mi-arreglo-quita-la-salida-que-habia]] (el mismo error visto desde el abuso) y
  [[la-review-adversarial-caza-lo-mio]].
