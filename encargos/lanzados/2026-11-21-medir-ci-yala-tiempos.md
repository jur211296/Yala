Yala
# Medir cuánto tarda el CI de Yala y proponer cómo bajarlo, sin cambiar nada
---
toca: docs/auditorias/2026-11-21-ci-tiempos.md,tickets/backlog/2026-11-21-medir-ci-yala-tiempos.md,tickets/done/2026-11-21-medir-ci-yala-tiempos.md
esfuerzo: high
cierre: cierra-sola
---

Pedido de Jürgen (21-nov, 06:11 Lima). Vio un prompt en X para dejar el CI de un repo «lo más rápido posible sin que mienta» (meta: resultado de un PR en menos de 1 minuto en la mediana y menos de 2 en el p95). Ese prompt es para repos JS/TS (bun, oxlint, vitest), no para Swift; aquí se adaptan solo las ideas a Yala. Esta sesión SOLO MIDE Y PROPONE: no cambia workflows, runners, hooks ni tests.

## Reglas que mandan sobre la velocidad (para las propuestas)
- La suite completa corre antes de que algo entre a 2.3 (o a la rama base); la selección por diff solo acelera el feedback del PR.
- Nunca esconder fallos: nada de reintentos automáticos, timeouts más largos ni tests saltados.
- Nunca chequear menos: los checks requeridos y reglas solo se mantienen o crecen.

## Qué hacer (solo lectura)
1. Con `gh run list` / `gh api` toma los últimos 150 runs de los workflows de `jur211296/Yala` (PRs a 2.3, 2.2 y 1.0) y separa cada job en espera (cola del runner), preparación (checkout, toolchain, caché, resolver paquetes, arrancar simulador) y ejecución (build y tests), con p50 y p95. Incluye también la web (Astro) si tiene workflow propio.
2. Identifica el bloque más grande y los jobs más lentos. Mira cuántas veces una sesión de Claude o un auto-merge quedó esperando el CI y cuánto (estimado desde los runs).
3. Propone mejoras ordenadas por impacto, cada una con ahorro estimado y si tiene costo mensual:
   - caché de DerivedData / SPM / build, clone con `--filter=blob:none`, toolchain ya horneada;
   - repartir tests en partes paralelas con base en tiempos reales; tests que tarden más de 20 s;
   - en PR correr solo los tests alcanzables por el diff, con lista de archivos que fuerzan suite completa, y la suite completa en merge queue o antes de mergear;
   - cancelar el run viejo de una rama cuando llega un commit nuevo;
   - tope de tiempo por job;
   - hooks locales (pre-push) que corran lo mismo que el CI;
   - runners: GitHub hosted vs. self-hosted en la Mini/Max vs. pagados (p. ej. Blacksmith u otros con macOS). Lo pagado se lista aparte con costo mensual estimado; no se contrata nada.
4. No encoles nada: solo propones encargos (uno por PR chico, con medición antes/después).

## Entrega
- Artifact visual de Claude (no Markdown suelto): arriba el tiempo de hoy (p50/p95 por PR) y la meta; gráfico por bloque (espera/preparación/ejecución); tabla de jobs; propuestas ordenadas con ahorro y costo; aparte, lo que necesita cuenta, secreto o gasto.
- Copia breve en `docs/auditorias/2026-11-21-ci-tiempos.md` con el link al artifact.
- Termina con /cerrar-total cuando el PR (solo docs y ticket) esté dentro de 2.3. En el cierre pon el link del artifact.

## Cómo trabajar
- iPhone 14 (Jürgen, 19-nov): queda conectado a la Mini para cualquier sesión de cualquier máquina vía DeviceMCP. Antes de recurrir al simulador, verifica de verdad si está libre (que responda y que ninguna otra sesión lo esté usando en ese momento); no lo des por ocupado sin comprobarlo. Si lo usas, suéltalo al terminar.
- Textos nuevos en su propia tabla, nunca en Localizable.strings. Nunca un botón debajo de otro.
- En la Max puedes usar un segundo simulador además del de otra sesión, o el iPhone 14 por DeviceMCP; en la Mini, uno solo. No uses `-derivedDataPath /tmp/claude-*`.
- Nada en producción (ni CloudKit ni Supabase).
- Commit y PR sin firma de IA, contra 2.3. Deja el auto merge activado y no cierres hasta ver el PR dentro de 2.3. Si hay conflicto o el CI falla por tu PR, arréglalo tú. Si tras unos 45 minutos el CI sigue rojo por algo ajeno, cierra y anota el motivo.
- Lo menor y reversible se decide con la opción recomendada y se anota. Lo vital, según el modo fijado al arrancar: en semi (05:30–20:00) preguntas y esperas con la sesión viva; en nocturno (20:00–05:30) dejas un checkpoint recuperable y una card «Espera decisión» para Jürgen, sin cerrar como completo, sin mergear ni desplegar lo incompleto.
- Entregable del cierre: artifact visual de Claude (capturas antes y después y mediciones), nunca Markdown ni PDF.
- Cierre: `/cerrar-total`, con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», y el link del artifact.

## Paso 0 — decisiones (resueltas en semi, sin preguntar: todas menores y reversibles)

1. **Ventana.** Los últimos 150 runs de PR del workflow `QA` cubren solo del 16 al 21-nov (149 a 2.3, 1 a 1.0, 0 a 2.2: 2.2 ya no recibe PR). Se usan tal cual, como pide el encargo, más 60 runs del push a 2.3 y las 12 nocturnas como contexto.
2. **«Resultado del PR».** Hasta que terminan los tres checks del ruleset de 2.3 (`tests`, `coverage-index`, `gateway`), sin runs cancelados. Se separan PR que compilan y PR solo de docs.
3. **Bloques.** Espera = cola del job; preparación = checkout, Xcode, Secrets, simulador, cuarentena y set-up/post; build = `Build for testing`; ejecución = los dos pasos de unit. El build se muestra aparte de los tests (el encargo los junta en «ejecución»).
4. **Web (Astro).** No tiene workflow en GitHub (la construye Vercel): se dice y no se mide.
5. **Espera de las sesiones.** Por cada PR mergeado: del último run de PR al merge.
6. **Factura.** `gh` no tiene el permiso `user`: no se pide; se marca como inferencia y va a «Necesita de ti».
7. **Formato.** Artifact HTML propio (informe único, no dashboard recurrente) y copia breve en `docs/auditorias/`; ticket directo en `tickets/done/` (la entrega es la medición).
8. **Sin pruebas de interfaz:** el encargo no corre XCUITest; el presupuesto de UI no aplica.
