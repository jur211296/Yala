Yala
# Auditoría: qué decisiones de Jürgen sobre Yala están de verdad en 2.3 y cuáles no tienen encargo
---
toca: docs/auditorias/2026-11-21-decisiones-vs-2-3.md,tickets/backlog/2026-11-21-auditoria-decisiones-vs-2-3.md,tickets/done/2026-11-21-auditoria-decisiones-vs-2-3.md
esfuerzo: high
cierre: cierra-sola
---

Pedido de Jürgen (21-nov, 05:52 Lima). Motivo: su decisión del 20-nov sobre la fila de Favoritos de Nuevo registro quedó «incorporada» en el registro (escrita en la documentación del repo) pero nunca entró en ningún encargo ni en el código; lo vio en TestFlight 2.3 (6). Preguntó si es la única. El estado «incorporada» del registro NO prueba que esté implementado.

## Qué hacer (solo lectura del código; no cambies código de la app)
1. Toma todas las decisiones de Yala capturadas desde el 1-nov-2026: `python3 ~/.claude/scripts/decisiones.py` (registro en `~/Claude/flota/decisiones/decisiones.jsonl`, `proyecto` = Yala, `tipo` = capturada; respeta sustituciones: manda la más nueva). Descarta las que no piden cambio (se deja como está, OKs de borrar cachés, reglas de proceso de la flota), pero lístalas aparte.
2. Por cada decisión que pide un cambio en la app, la web o el backend, clasifícala con evidencia:
   - **Implementada en 2.3**: archivo y línea, o commit/PR mergeado en `origin/2.3`. Si se puede ver, captura del simulador.
   - **Parcial**: qué falta.
   - **En encargo encolado o sesión viva**: `python3 ~/.claude/scripts/coordinador.py estado` y briefs en `~/Claude/flota/borradores/`.
   - **Sin encargo**: nadie la está haciendo.
   - **Pospuesta a propósito** (p. ej. a 2.4 por decisión de Jürgen): con la fuente.
   La fila de Favoritos ya tiene sesión en curso (`favoritos-fila-ver-todos-arriba-chips-completos`): márcala así.
3. Para cada «sin encargo» o «parcial», propone un encargo agrupado por vista (regla: una sesión por vista; tareas chicas de la misma vista se juntan de 3 a 5), con título humano y prioridad sugerida. No encoles nada: solo propones.

## Entrega
- Artifact visual de Claude (no Markdown suelto): resumen arriba con conteos por grupo, luego tabla filtrable por grupo y vista, con la frase de la decisión, la fecha y la evidencia (link al PR o archivo). Arriba destacadas las «sin encargo» y «parcial» con el encargo propuesto.
- Copia breve en `docs/auditorias/2026-11-21-decisiones-vs-2-3.md` con el link al artifact.
- Termina con /cerrar-total cuando el PR (solo docs y ticket) esté dentro de 2.3. En el cierre pon el link del artifact.

Nota del coordinador: esta sesión NO edita `docs/TICKETS.md` (otra sesión de Yala lo tiene tomado); el ticket va solo en su archivo de `tickets/`.

## Cómo trabajar
- iPhone 14 (Jürgen, 19-nov): queda conectado a la Mini para cualquier sesión de cualquier máquina vía DeviceMCP. Antes de recurrir al simulador, verifica de verdad si está libre (que responda y que ninguna otra sesión lo esté usando en ese momento); no lo des por ocupado sin comprobarlo. Si lo usas, suéltalo al terminar.
- Textos nuevos en su propia tabla, nunca en Localizable.strings. Nunca un botón debajo de otro.
- En la Max puedes usar un segundo simulador además del de otra sesión, o el iPhone 14 por DeviceMCP; en la Mini, uno solo. No uses `-derivedDataPath /tmp/claude-*`.
- Nada en producción (ni CloudKit ni Supabase).
- Commit y PR sin firma de IA, contra 2.3. Deja el auto merge activado y no cierres hasta ver el PR dentro de 2.3. Si hay conflicto o el CI falla por tu PR, arréglalo tú. Si tras unos 45 minutos el CI sigue rojo por algo ajeno, cierra y anota el motivo.
- Lo menor y reversible se decide con la opción recomendada y se anota. Lo vital, según el modo fijado al arrancar: en semi (05:30–20:00) preguntas y esperas con la sesión viva; en nocturno (20:00–05:30) dejas un checkpoint recuperable y una card «Espera decisión» para Jürgen, sin cerrar como completo, sin mergear ni desplegar lo incompleto.
- Entregable del cierre: artifact visual de Claude (capturas antes y después y mediciones), nunca Markdown ni PDF.
- Cierre: `/cerrar-total`, con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», y el link del artifact.

## Paso 0 — decisiones (resueltas en semi, sin consulta: todas menores y reversibles)

1. **Fuente del registro.** En la Max no hay `decisiones.py`; se copió `decisiones.jsonl` de la Mini por ssh y se filtró en Python: proyecto Yala (también «yala»), tipo `capturada`, desde el 1-nov y sin las sustituidas. El registro empieza el 7-nov, así que lo del 1 al 7-nov no se puede auditar; se dice en el artifact.
2. **«Autoriza encolar X» cuenta como pedido de X.** Se verifica X, no el encolado.
3. **Las de consola (CloudKit Production, Supabase, Sentry, DNS) son un grupo propio: «Fuera del repo».** El repo no puede probarlas. Lo que no deja rastro de haberse hecho va a una propuesta «Confirmar con Dan».
4. **Una parcial cuya parte pendiente cubre un encargo en cola cuenta como «En encargo»**, con la parte hecha anotada (155, 161 y 162).
5. **Verificación con cinco agentes, uno por área.** Las afirmaciones que sostienen cada «sin encargo» y cada parcial clave se comprobaron a mano después.
6. **Sin capturas del simulador.** Cada decisión trae evidencia de código (archivo y línea o PR). Capturar más de cien pantallas no cabía en la sesión; se anota en el cierre.
7. **Propuestas por vista con selector sí/no/después en la base de datos del artifact**, tal como Jürgen pidió entregar las propuestas el 11-nov. Nada se encola.
8. **Este PR solo lleva documentación y el ticket.** `docs/TICKETS.md` no se toca porque lo tiene otra sesión. El ticket nace directamente en `done`, porque el trabajo termina en esta sesión.
