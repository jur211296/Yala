---
name: qa-guiado-2-1-espera-tf19
description: El QA guiado de 2.1 (sesión Yala--qa-guiado-2-1-tf17) quedó abierto a propósito el 2026-10-19, esperando 9 cards de 2.1 y un TestFlight 19 para una tanda corta.
metadata:
  type: project
---

El QA guiado de 2.1 sobre el TestFlight 18 terminó el 2026-10-19 con 23 de 27 pasados (PR #563, abierto y SIN cola de
merge). Jürgen pidió **no cerrar la sesión**: se sigue en ella cuando entren los arreglos.

**Why:** quedan 9 cards de 2.1 de Frank (en curso: cq2i, 9ttd, ewkw, 8171; lista para lanzar: axgf, ppxk, t2q8, n2xn) y
tres en qa que dependen de ellas (gk5w ← axgf+ppxk; h52f ← 8171; d0ui: suscripciones, notas al revisor, capturas de Lola).
n5zw pasó a 2.2 por decisión de Jürgen (el #562 no arregla el caso en el iPhone real).

**How to apply:** al retomar, subir un TestFlight 19 con esas cards y hacer una tanda corta: C6 paso 4, micrófono paso 3,
D · E2 completa y una prueba por cada card arreglada. Estado de los aparatos al pausar: iPhone de QA con Yala (TestFlight)
apuntando a una cuenta de producción ya borrada (borrar la app antes) y Yala Dev en privado; el iPad con iCloud
`test@yala-app.pe` (Jürgen tiene que volver a su iCloud personal). Producción y staging quedaron sin cuentas de prueba
(salvo las i5-* fijas de staging). Relacionado: [[el-guion-se-adapta-al-estado-del-telefono]].
