# Auditoría UX 2.2 · decidido por Jürgen · 01 · Estadísticas (resumen, observaciones con IA, tendencias, informe) y el saldo de hoy con fechas futuras

Base y PR: **2.2** (no 2.1). `lanzar-sesion` te deja sobre origin/2.1: antes del primer commit haz `git fetch origin && git switch -C encargo-tmp origin/2.2` (o rebasa tu rama sobre origin/2.2) y comprueba que `git log origin/2.2..HEAD` sale vacío. El PR va contra **2.2**.

## Contexto
Jürgen respondió el 18-oct (18:41–21:18 Lima, sesión «preguntas-auditoria-ux-2-2») todas las cards de la auditoría UX 2.2 que esperaban decisión. Resumen completo: `~/Claude/entregas/Yala--preguntas-auditoria-ux-2-2/decisiones.md`. Esta sesión implementa las de abajo, que están en «ready to launch» asignadas a frank, con la decisión en la nota de cada card.
Fuentes: la card (nota = decisión; contexto con capturas), el informe del lote en `~/Claude/entregas/Yala--auditoria-ux-2-2-lote-11-estadisticas/informe.md`, el HTML `~/Claude/propuestas/auditoria-ux-2.2/auditoria-ux-2.2.html` (opciones A/B/C/D y variantes) y los «Criterios UX/UI permanentes de Jürgen» del brief madre `~/Claude/tmp-frank/auditoria-ux-flujos-2-2.md` (léelos: sin degradados, etc.). Las variantes elegidas (p. ej. «L17-2-B.png») están en `capturas/` de esa misma carpeta del lote.

## Cards de esta sesión (8)
- **L11-5** · `tablero-ux-2-2-l11-5-compromisos-mezcla-pagos-su-7u5t`
  UX 2.2 · L11-5 · «Compromisos» mezcla pagos, suscripciones y presupuestos, su subtítulo solo habla de presupuestos y las barras no dicen d…
  Decisión de Jürgen: opción B. Dos bloques, «Lo que te falta pagar» (pagos y suscripciones con su total) y «Tus presupuestos» con «S/ 780 de S/ 1,000 · 78 %».
- **L11-6** · `tablero-ux-2-2-l11-6-esencial-prioritaria-opcion-t1r1`
  UX 2.2 · L11-6 · «Esencial, Prioritaria, Opcional»: tres palabras sin explicar, con «≈ S/ 35.75/día» debajo
  Decisión de Jürgen: opción B. Línea con el para qué arriba y un ejemplo por fila, mismos textos que L2-9 B.
- **L11-7** · `tablero-ux-2-2-l11-7-quien-paga-pro-y-no-ha-gene-7t42`
  UX 2.2 · L11-7 · Quien paga Pro y no ha generado la IA ve menos que quien no paga: «Observaciones» queda vacía
  Decisión de Jürgen (≠ de la recomendada, respétala tal cual): opción C con matiz (literal): «Creo que el usuario PRO debería aprovechar más la IA, deberíamos ir por C, pero no regeneremos cada vez que abra la pestaña, porque si no ha habido nuevos registros o algún filtrado no deberíamos necesitar nuevo dato, revisemos bien cómo eficientar esto pero que la IA salga automática mejor, sin depender de un clic». Es decir: en Pro la IA se genera sola al abrir Observaciones, pero se reutiliza el último resultado si no cambiaron los registros ni los filtros/período.
- **L11-8** · `tablero-ux-2-2-l11-8-la-misma-funcion-tiene-seis-ulg5`
  UX 2.2 · L11-8 · La misma función tiene seis nombres: «Resumen inteligente», «Insights inteligentes con IA», «Generar análisis IA», «Refin…
  Decisión de Jürgen: opción B (recomendada). «Resumen con IA» como nombre y «Generar con IA»/«Actualizar» como verbo; títulos «Tu mes en pocas palabras».
- **L11-9** · `tablero-ux-2-2-l11-9-las-observaciones-automatic-zji1`
  UX 2.2 · L11-9 · Las observaciones automáticas hablan raro: «Promedias S/ 327.53 por día», «Tu balance creció 6 %»
  Decisión de Jürgen: opción B (recomendada). Frases con verbos de persona y «saldo», en 16 idiomas.
- **L11-10** · `tablero-ux-2-2-l11-10-tendencias-ensena-dos-vece-n96e`
  UX 2.2 · L11-10 · Tendencias enseña dos veces la misma comparación, y «Flujo de Efectivo» se confunde con «Flujo de caja»
  Decisión de Jürgen: opción B (recomendada). Una tarjeta de saldo con «Ver el mes anterior»; «Flujo de Efectivo» → «Entradas y salidas» con selector en texto.
- **L11-12** · `tablero-ux-2-2-l11-12-el-editor-del-informe-no-d-l8hc`
  UX 2.2 · L11-12 · El editor del informe no dice qué días entran, «Probar» sin permiso no hace nada y el mensual del día 1 dice «este mes»
  Decisión de Jürgen: opción B (recomendada). Línea con lo que llegará, «Probar» pide permiso, mensual del día 1 nombra el mes cerrado.
- `tablero-el-saldo-cuenta-los-movimientos-con-fech-ptdt`
  El saldo cuenta los movimientos con fecha futura y la curva no los dibuja
  Jürgen decidió el 2026-10-18 21:17 Lima: opción A. El saldo de hoy deja fuera los movimientos con fecha futura hasta que llegue su fecha; cifra y curva coinciden (Panel, «¿Cuánto tienes hoy?» y widget de inicio). Cálculo financiero: review adversarial.

## Avisos de esta sesión
- **Saldo con fecha futura** (bug, va primero): cálculo financiero. Antes del PR pasa una review adversarial (subagente que intente romperlo: movimientos de mañana, de otro huso, recurrentes, divisas, widget de inicio con su propia caché) y deja el resultado en el PR.
- **L11-7**: en Pro la IA de Observaciones se genera sola al abrir, pero reutiliza el último resultado mientras no cambien los registros ni los filtros/período. Diseña la clave de caché (huella de registros + filtros + período) y documenta en el PR cuántas llamadas ahorra. No cambies cuota, modelo ni proveedor.
- **L11-10** renombra «Flujo de Efectivo» a «Entradas y salidas»: el widget correspondiente lo seguirá en la sesión 08 (L15-1); aquí solo la pantalla de Estadísticas.
- L11-6 usa los mismos textos que L2-9 B (ya en 2.2): reutilízalos.

## Cómo mover las cards
- Al empezar con cada una: `tablero mover <id> --a "in progress" --agente frank`. No uses `--nota` en `tablero editar` salvo para AÑADIR: `--nota` reemplaza la nota entera, así que copia la decisión de Jürgen que ya está y añade debajo lo tuyo.
- Al cerrar: a `done` (`--agente frank`) las que queden hechas y mergeadas sin nada que probar en el teléfono; a `in qa` asignadas a `jurgen` con un guion corto de iPhone en la nota si hay algo que él deba probar en el teléfono.
- Todo ticket nuevo lleva su card.

## La UI sigue la decisión al pie de la letra
- Implementa exactamente lo que dice la decisión de cada card (y la variante con captura si la hay). No inventes UI ni «mejores» la opción elegida. Los detalles que la decisión no fija y que el sistema de diseño ya resuelve (márgenes, tipografía, componentes existentes) se toman de lo que ya hay en la app.
- Si al implementar aparece algo de verdad sin decidir (dos caminos que cambian lo que ve el usuario y ninguno sale de la decisión), NO elijas tú: deja 2–3 propuestas con capturas o mock y tu recomendación en la nota de esa card, muévela a «espera decisión» asignada a `jurgen` con `--pregunta`, y sigue con las demás. Solo se para ese ítem, no la sesión.
- Ningún texto de la app escribe «OpenAI»: se dice «un servicio de IA» (con enlace a la política de privacidad, que es el único sitio que nombra al proveedor).
- Todo texto nuevo o cambiado, en los **16 idiomas**, y `/l10n-check` limpio.

## Reglas
- **Sin esperar el CI de ningún PR** (tampoco el tuyo): `git fetch origin && git rebase origin/2.2` justo antes de abrir el PR.
- Pipeline serial en la Mini: limpiar, build con `xcodebuild -jobs 2` sin simulador encendido, encender 1 simulador, tests, apagarlo. 1 simulador a la vez. Mira `df -h /` antes de compilar. Usa los simuladores iOS 27.0. Al cerrar, apaga y borra (erase) el simulador que usaste.
- Al lanzar y al cerrar borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen; no toques las de un worktree vivo.
- En `~/Yala` (árbol principal) no toques, commitees ni descartes `Cloudkit Schemas/yala_dev-*.ckdb`, `Yala.xcscheme` ni `encargos/pendientes/`.
- Nada de salud ni de clínicas. No toques tmux `salud--*`, `sat-lab--*`, `ruum--*`, `clinicas-dentales-bi--*`, `Yala--qa-guiado-2-1-tf17` ni otros `Yala--` vivos.
- Nada de despliegues a producción (Worker/gateway, Supabase, CloudKit Production, web). Si algo hace falta, déjalo listo con los pasos en una card a `jurgen` (o a `lola` si es CloudKit) y sigue.
- No cambies cuota, modelo ni proveedor de IA, precios ni productos de StoreKit.
- Prueba la sesión tú misma con **/barrido-qa** en el simulador (tests de lo que cambie, flujos tocados de punta a punta, VoiceOver en lo nuevo). Hay cambio visible: capturas de antes y después en `capturas/` del worktree, copiadas también a `~/Claude/entregas/<sesión>/capturas/`, con sus rutas en el resumen de cierre.
- Cierra sola con **/cerrar-total** (merge incluido). No esperes a nadie.

## Cómo se sabe que está bien
Cada card hecha tal como la decidió Jürgen (o, si algo no estaba decidido, con sus propuestas en la card a `jurgen` y solo ese ítem parado), textos en los 16 idiomas, tests en verde (`/gate`, `YalaTests`), /barrido-qa pasado, capturas de antes y después, cards movidas, y PR mergeado en 2.2 explicando en lenguaje de usuario qué verá la persona.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass), tras medir el código: las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · Saldo con fecha futura: dónde va el corte** → un solo predicado por DÍA en `LiveBalanceCalculator` (cuenta si `date < inicio de mañana`, calendario del usuario), con `asOf` inyectable y viajando en el `Breakdown`. Lo usan el saldo vivo (Panel, hoja «¿Cuánto tienes hoy?», Estadísticas, informe, score, widget), el P&L cambiario (si no, la divisa desaparece en silencio), el saldo por cuenta (`AccountBalanceCalculator` + `InitialBalanceService`: tarjetas, detalle, lista, formulario y widget por cuenta), la curva por cuenta de Estadísticas y la métrica saldo de `TrendDataProcessor`. El widget se recalcula al volver a primer plano si cambió el día.
Por qué: la decisión pide que cifra y curva coincidan; dejar las tarjetas con el futuro dentro abría una contradicción nueva en el mismo Panel (hero sin, tarjetas con). Alternativa descartada: cortar solo el hero (deja el P&L roto y el Panel contradiciéndose).
Fuera: el conector `mcp/` (portar el corte exige desplegar el Worker = producción) → ticket; Yala IA ya los excluye (corta por instante).

**D2 · L11-5 «Lo que te falta pagar»: qué suma** → los pagos planificados pendientes del período partidos en «Pagos» y «Suscripciones», con su total = suma de los dos. Sin «suscripciones activas · mensual», que contaba dos veces la suscripción pendiente y llamaba «mensual» a un importe que no lo era. «Tus presupuestos»: «S/ 780 de S/ 1,000 · 78 %» en la moneda de cada presupuesto. «Abiertos si caben» (la opción B): «Lo que te falta pagar» siempre abierto; «Tus presupuestos» abierto con cuatro o menos, plegado con más (el corpus de prueba tiene seis). «Tus presupuestos» enseña todos los activos, no solo los de ≥ 50 %: con ese título, enseñar solo los «en riesgo» mentía.

**D3 · L11-6 textos** → por fila, el texto de ejemplo que ya enseña el selector de necesidad (`need.*.desc`, lote 7 = L2-9 B); arriba, la línea de la opción B («Así se reparte tu gasto entre lo necesario, lo importante y lo que podrías recortar»). Solo la tarjeta de Resumen.

**D4 · L11-7 caché de la IA** → clave = huella SHA-256 del resumen agregado que se envía + tono, enfoque, país, idioma y divisa; persistida en disco (último resultado por clave, tope pequeño) para que sobreviva al relanzamiento y al cambio de pestaña. En Pro con el consentimiento ya dado, abrir Observaciones genera sola si no hay resultado para esa huella. Sin consentimiento sigue haciendo falta un toque (el consentimiento no se puede saltar). Cuota, modelo y proveedor intactos.

**D5 · L11-8 nombres** → función «Resumen con IA»; botón «Generar con IA», y «Actualizar» cuando ya hay uno; títulos con sustantivo del período («Tu mes en pocas palabras», «Tu semana…», «Tu año…»), también en Distribución («Tu mes de un vistazo»).

**D6 · L11-9 alcance** → todas las frases automáticas de Resumen y Tendencias que dicen «balance» o «Promedias»; el resto ya usa verbos de persona.

**D7 · L11-10** → la tarjeta de Tendencias gana «Ver el mes anterior» (el rótulo sigue al período y al modo de comparación); al encenderlo dibuja la curva punteada con el componente de la antigua Comparativa, que desaparece. «Flujo de Efectivo» → «Entradas y salidas» solo en Estadísticas (el widget del Panel lo sigue la sesión 08); selector en texto con los mismos identificadores.

**D8 · L11-12** → la línea calcula el próximo envío y el tramo que contará; el semanal del lunes pasa a contar la semana cerrada (lunes a domingo anteriores), que es lo que dice la decisión, y el enlace del aviso abre esa semana. El mensual del día 1 nombra el mes cerrado en sus cuatro textos y su saldo es el del cierre de ese mes; el del lunes dice «la semana pasada». «Probar» pide el permiso y, si está denegado, ofrece abrir Ajustes.

**D9 · L11-7 cuando la IA falla** → con el resumen saliendo solo, un fallo dejaba el título «Observaciones» vacío y el aviso arriba. En el modo Observaciones el aviso con «Reintentar» va bajo su título y no se repite arriba; en Detalle sigue donde estaba. Mismo componente.

**D10 · Review adversarial del saldo (3 lentes)** → aplicado: corte también en la curva agregada con rango que acaba en el futuro, en «Saldo hoy» de la ficha de cuenta, en el aviso de cambio de divisa y en el saldo inicial (nunca en un mes futuro); la salud financiera conserva su cobertura de antes (cuenta lo futuro, porque lo pendiente ya descuenta lo pagado); el informe cerrado valora el saldo al tipo de su cierre; el corte usa el final del día del calendario (cambio de horario a medianoche); el widget se rehace al cambiar de día con la app abierta. A ticket: el conector `mcp/` (pide desplegar), los totales que cuentan la medianoche de mañana, la cifra y la curva del widget con movimientos sin cuenta, y los saldos de Yala IA sobre 13 meses.

