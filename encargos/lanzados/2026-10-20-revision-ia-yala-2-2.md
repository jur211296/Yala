# Revisar a fondo cómo usa Yala la IA (privada en el teléfono y en la nube) para que dé mejores respuestas

Base y PR: **2.2** (no 2.1). `lanzar-sesion` te deja sobre origin/2.1: antes del primer commit haz `git fetch origin && git switch -C encargo-tmp origin/2.2` (o rebasa tu rama sobre origin/2.2) y comprueba que `git log origin/2.2..HEAD` sale vacío. El PR va contra **2.2**.

## Contexto
Card `tablero-revisar-a-fondo-como-usa-yala-la-ia-priv-u6iq` (2.2, high, a frank). Jürgen, 19-oct: que el chat de Yala IA solo lea los últimos 13 meses de saldos es solo un síntoma. Hay que revisar toda la manera en que la app usa la IA, la privada (en el dispositivo) y la de la nube: qué modelo o camino usar para cada tipo de pregunta, qué más datos y herramientas podemos darle, cómo mejorar los prompts y todo lo necesario para que responda mejor. Incluye el ticket de los 13 meses.
Esta sesión va ANTES del lote de UX de Yala IA (lote decidido 2.2 · 07, siguiente en la cola), para que ese lote parta del ruteo y los prompts nuevos. No hagas aquí las cards de ese lote (L14-x, L16-8).
Lee antes: `docs/ai-cloud-vs-private-2026-10.md`, la nota de la card (`tablero ver tablero-revisar-a-fondo-como-usa-yala-la-ia-priv-u6iq`), `.claude/rules/` que toquen IA, y el último lote de IA ya mergeado (PR #546, #551, #554) para no deshacer decisiones.

## Qué se pide
1. **Mapa de todos los caminos de IA**: chat de Yala IA en privado y en la nube, Resumen con IA, Observaciones, Siri y Atajos, lectura de foto/voz si pasa por un modelo. Para cada uno: qué modelo o camino usa, qué contexto y herramientas recibe, qué prompt, cuántos tokens manda, y dónde falla.
2. **Banco de preguntas reales** (30–50, en español y alguna en inglés y portugués, cubriendo saldos, gastos por categoría, comparativas de meses, presupuestos, pagos planificados, tarjetas con varias divisas, Grupos, «¿puedo gastar X?», registrar con lenguaje natural). Mídelo ANTES con la semilla `realista` en el simulador (Yala Dev contra staging para la nube; nunca producción) y guarda las respuestas.
3. **Arreglar el bug de los 13 meses** (card `tablero-yala-ia-calcula-los-saldos-solo-con-los-646z`): los saldos deben salir de la fuente de verdad de la app, no de una ventana de movimientos.
4. **Proponer e implementar** el ruteo por tipo de pregunta, las herramientas o consultas de datos que falten y los prompts nuevos, siempre que **no cambien la UI ni lo que sale del teléfono** (privacidad). Mide DESPUÉS con el mismo banco.
5. Mira si estas cards caen dentro de lo que tocas; si sí, arréglalas y muévelas; si no, déjalas como están: `tablero-el-chat-de-yala-ia-reenvia-todos-los-tur-n6t8`, `tablero-si-el-contexto-del-chat-no-se-puede-prep-ol9e`, `tablero-yala-ia-no-cuenta-hasta-el-mediodia-un-g-qrv9`, `tablero-yala-ia-no-usa-el-trato-que-toca-tuteo-v-81m4`, `tablero-con-el-modo-solo-gastos-activo-el-chat-d-4m37`.
6. Lo que sí cambie UI, privacidad, coste, cuota, modelo contratado o proveedor: NO lo hagas. Déjalo en una card a `jurgen` en «espera decisión» (`--pregunta`), con 2–3 opciones, la medición que la apoya y tu recomendación.
7. **Informe** en `docs/ai/revision-ia-2-2.md` (y copia en `~/Claude/entregas/<sesión>/`): mapa, banco con respuestas antes/después y una nota por pregunta, qué se cambió y qué queda para Jürgen.

## Qué NO hay que tocar
- No cambies cuota, precios, productos de StoreKit, proveedor de IA ni el flag de `chat.explore` (sigue a 0; encender la IA ampliada en staging y producción es de la card de jurgen).
- Ningún texto de la app nombra al proveedor («OpenAI» u otro): se dice «un servicio de IA», con enlace a la política de privacidad. Si cambias un texto visible, en los **16 idiomas** y `/l10n-check` limpio.
- Yala IA con Grupos como contenedor aparte (`tablero-2-2-yala-ia-entiende-grupos-como-un-cont-69gi`) tiene su sesión: no la hagas aquí.
- Nada de despliegues a producción (Worker/gateway, Supabase, CloudKit Production, web). Si un cambio del gateway hace falta, déjalo listo en el repo con los pasos en una card a `jurgen` y sigue. Staging solo si ya hay un camino de despliegue a staging documentado y reversible.

## Cómo mover las cards
- Al empezar: `tablero mover tablero-revisar-a-fondo-como-usa-yala-la-ia-priv-u6iq --a "in progress" --agente frank` (y lo mismo con las del punto 5 que tomes). `--nota` en `tablero editar` REEMPLAZA la nota: copia lo que ya hay y añade debajo.
- Al cerrar: a `done` lo hecho y mergeado sin nada que probar en el teléfono; a `in qa` asignado a `jurgen` con un guion corto de iPhone si él debe probarlo. Todo ticket nuevo lleva su card.

## Reglas
- **Sin esperar el CI de ningún PR** (tampoco el tuyo): `git fetch origin && git rebase origin/2.2` justo antes de abrir el PR.
- Pipeline serial en la Mini: limpiar, build con `xcodebuild -jobs 2` sin simulador encendido, encender 1 simulador, tests, apagarlo. 1 simulador a la vez. El disco está apretado (unos 18 GB libres al lanzar): mira `df -h /` antes de compilar. Usa los simuladores iOS 27.0. Al cerrar, apaga y borra (erase) el simulador que usaste.
- Al lanzar y al cerrar borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen; no toques las de un worktree vivo.
- En `~/Yala` (árbol principal) no toques, commitees ni descartes `Cloudkit Schemas/yala_dev-*.ckdb`, `Yala.xcscheme` ni `encargos/pendientes/`.
- Nada de salud ni de clínicas. No toques tmux `salud--*`, `sat-lab--*`, `ruum--*`, `clinicas-dentales-bi--*`, `Yala--qa-guiado-2-1-tf17` ni otros `Yala--` vivos. No toques los iPhones ni el iPad de Jürgen.
- Prueba la sesión tú misma con **/barrido-qa** en el simulador (tests de lo que cambie, flujos de Yala IA de punta a punta). Si hay cambio visible, capturas de antes y después en `capturas/` del worktree, copiadas a `~/Claude/entregas/<sesión>/capturas/`, con sus rutas en el resumen de cierre.
- Cierra sola con **/cerrar-total** (merge incluido). No esperes a nadie.

## Cómo se sabe que está bien
Informe con el mapa y el banco de preguntas antes/después; el bug de los 13 meses arreglado con su test; ruteo, herramientas y prompts mejorados en 2.2 sin cambiar UI ni privacidad, y con mejora medida en el banco; cards a `jurgen` con lo que necesita su decisión; tests en verde (`/gate`, `YalaTests`); /barrido-qa pasado; cards movidas; PR mergeado en 2.2 explicando en lenguaje de usuario qué responde ahora mejor Yala IA.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass, 01:00 Lima): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Cómo se mide el banco «en el simulador» sin conducir 2 × 50 preguntas a mano?** → Un test de `YalaTests`
(`YalaIABankDumpTests`, apagado salvo con `TEST_RUNNER_YALA_AI_BANK_DIR`) siembra `realista` en el simulador y construye
cada petición con el MISMO código que la app (`FullFinancialContextBuilder.build` + `ChatAssistantService.makeAskQuery`);
un script (`gateway/scripts/yala-ia-bank.ts`) las manda a **staging** (`chat.intent` + `chat.answer`, token del bypass
de desarrollo, nunca producción) y guarda las respuestas. Unas cuantas se comprueban además de punta a punta en el
simulador con `Yala Dev` en el /barrido-qa. Por qué: mide exactamente lo que sale del teléfono y es repetible antes y
después. Descartado: teclear el banco en la UI (lento y ruidoso).

**D2 · Nube vs privado en el banco.** → Se mide un solo camino. Con `chat.explore` a 0 en staging (no se toca) la nube
contesta igual que `chat.answer`: medido en el código (`ai-gateway.md`). El camino ampliado queda fuera del banco.

**D3 · ¿Qué cuenta como «no cambia lo que sale del teléfono»?** → No se manda ningún TIPO de dato nuevo ni nada fuera
de lo que dice el aviso P1 vigente («un resumen de tus últimos 13 meses: saldos y nombres de cuentas, totales por
categoría, comercios frecuentes, presupuestos, pagos recurrentes y tus gastos más grandes de este mes»). Corregir una
cifra (el saldo de los 13 meses) o añadir AGREGADOS de esos mismos tipos dentro de los 13 meses sí entra; notas,
movimientos sueltos de otros meses o datos de más de 13 meses, no: van a card. Por qué: es la frontera que el usuario
aceptó. Si Jürgen la lee más estrecha, el cambio de contexto se revierte solo (está aislado).

**D4 · Modelo, esfuerzo de razonamiento, proveedor, IA en el teléfono (Foundation Models).** → No se tocan: card a
jurgen con la medición. Ni se despliega el gateway.

**D5 · Cards del punto 5.** → Se toman `…646z` (13 meses), `…qrv9` (mediodía: mismo corte, mismo fichero), `…81m4`
(trato regional: es del prompt), `…ol9e` (contexto que falla en silencio: mismo camino) y `…4m37` (solo gastos: el
borrador del chat es el único que no lo respeta; se alinea con Siri, Atajo y Apple Pay, decisión reversible tomada de
noche). `…n6t8` (turnos) se deja: su propio triage dice que falta decidir N y es coste.

**D6 · Base.** → Rama recreada sobre `origin/2.2` (0 commits por delante); PR contra `2.2`.

**D7 · El contexto nuevo sube los tokens por pregunta (8,2k → 12,8k).** → Se deja dentro, recortado (tops cortos,
flags solo en `true`, cifras a céntimos), y se lleva a Jürgen como decisión con tres opciones (card `…i66p`). Por qué: el
punto 4 del encargo pide más datos, y más datos son más tokens; el «coste» del punto 6 se lee como modelo, cuota o
llamadas nuevas. Lo compensa en parte que 42 de cada 50 preguntas ya no pagan el clasificador. Es reversible sin release
de por medio solo en la parte del gateway: el contexto vive en la app, así que recortarlo pide un build.

**D8 · «¿Puedo gastar X?» sin signos.** → Pregunta siempre, aunque traiga cifra (medido en el simulador: caía en
«¿registrar o preguntar?»), y el clasificador recibe tres ejemplos. Medido contra staging: 120 de 120 en el banco de
`chat.intent` más cinco frases nuevas.
