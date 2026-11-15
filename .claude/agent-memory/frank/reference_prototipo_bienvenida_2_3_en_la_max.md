---
name: prototipo-bienvenida-2-3-en-la-max
description: El artifact v35 de la bienvenida 2.3 no se lee desde la Mini; su fuente está en la Max y se trae por scp
metadata:
  type: reference
---

El prototipo oficial de la bienvenida 2.3 (artifact `AcwrfYm96uy8k6Ga2EXnU6`, v35) da «artifact not found» con
`Artifact read` desde la Mini (12-nov). Su fuente sí se lee: `max:Claude/entregas/onboarding-yala-20261107/prototipo/fuente-actual/`
(`scp -r` al scratchpad). Lo que cada lote necesita:

- `09d-registro.js`: el mazo (`deck`, `TSTEPS` con título y línea de cada paso), la hoja de los 7 pasos y «días después».
- `09i-coach.js`: la barra nueva, la pantalla Más y la guía de foco (`tip`, `more`).
- `09e/09g/09h/09j`: textos de cada paso (presupuesto, pagos, grupos, final).
- CSS del mazo: `03g-r7.css` (`.deck8`, `.dkf`, `.dkb`).

**How to apply:** en un lote de la bienvenida 2.3, trae la fuente por scp en vez de reintentar el artifact.
Relacionado: [[conducir-simulador-con-axe]].
