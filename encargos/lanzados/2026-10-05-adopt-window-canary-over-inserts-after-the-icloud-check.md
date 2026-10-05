# Canario sobre inserts al espejo de iCloud después del chequeo del adopt

## Contexto
Contexto limpio: no hay chat previo. Card del tablero `tablero-decidir-que-hacer-con-lo-que-llega-a-icl-kyys`. Ticket del repo: `tickets/backlog/adopt-window-uploads-what-reaches-the-mirror-after-the-icloud-check.md` (origen #249; sale de docs/ESTADO.md, retirado el 30-sep).

Decisión de Jürgen 2026-10-04 (opción A, la robusta): «Primero un canario en el historial de los inserts que llegan después del chequeo. No cerrar la política antes de eso.»

Regla permanente: Jürgen quiere la solución más robusta / best-practice; sin prisas. Lo irreversible sobre datos o producción queda propuesto, no ejecutado.

PR #358 (personal drain / sign-out, texto sin plazo) está en auto-merge a 2.1 y puede seguir en CI: este encargo NO depende de ese PR ni toca ese carril. El gemelo de Groups del drain espera a #358; no lo toques.

## Qué se pide
1. Implementar de punta a punta el canario sobre el historial de inserts que llegan al espejo de iCloud después de la comprobación del adopt / sin linaje, con tests.
2. Telemetría y logging sin filtrar datos personales.
3. Entregar qué mide el canario y cómo leerlo (en el PR / ticket / resumen de cierre).
4. Mover el ticket del repo según la convención del repo (a `qa` o `done` según device-QA aporte o no).
5. Si hace falta un iPhone real, dejar un guion de device-QA en `tickets/qa`.
6. Abrir PR a 2.1 con auto-merge si el repo lo permite (ADR-054).

## Qué NO hay que tocar
- Ningún deploy ni migración a Supabase prod (si hace falta algo, déjalo propuesto).
- Ningún cambio de modelo / proveedor.
- El formulario de cuenta del PR #341.
- Cards de IA de 2.2.
- El gemelo Groups del drain (groups-drain…); espera a #358.
- Otros tickets distintos de este.

## Cómo se sabe que está bien
- El canario corre de punta a punta con tests en verde y mide los inserts post-chequeo / sin linaje.
- Queda documentado qué mide y cómo leerlo.
- Telemetría/logging sin datos personales.
- Ticket movido según convención; si hace falta iPhone, guion en `tickets/qa`.
- PR a 2.1 en auto-merge; Mini limpia al cerrar.

Base: origin/2.1. GATE: justo antes del gate mira si el PR anterior (#358) sigue en CI; si sigue, espera a que entre y rebasa una sola vez con el simulador apagado; si 2.1 no se movió, sigue; si ese CI falla, no esperes: rebasa con lo que haya y sigue. Build y simulador después de ese rebase, una sola vez.

Pipeline serial: limpiar → build `xcodebuild -jobs 2` sin sim → boot 1 sim → tests → apagar y borrar data del sim. Nunca solapar.

DerivedData y cachés: al lanzar y al cerrar borra sola el DerivedData de esta sesión (no el de otra viva) y las cachés de XcodeBuildMCP de worktrees que ya no existen o cuyo PR ya se mergeó. Prohibido preguntar; si falla, dilo en el cierre.

Capturas: si el cambio se ve en pantalla, `capturas/antes.png` y `capturas/despues.png` en el worktree, rutas en el resumen.

Horario nocturno: decide la opción recomendada y más robusta y sigue; lo irreversible sobre datos o producción queda propuesto para la mañana.

Al terminar con el PR en auto-merge a 2.1: /cerrar-total y Mini limpia (sim apagado y borrado, worktree fuera si ya mergeó).

---

## Paso 0 — decisiones (resueltas en autónomo, de noche)

1. **¿Cambia lo que sube?** No. Es un canario: mide y deja rastro; la política (qué hacer con esas filas) queda para
   Jürgen con los números delante. Decisión del 2026-10-04: «No cerrar la política antes de eso».
2. **Dónde mide.** En el drain que lee la ventana del adopt (del paso 3 al remonte): el primero tras relanzar, el síncrono de
   `CloudSyncRuntime.start`. La ventana ya existe y tiene testigo: el fichero `….backend-known` del registro del adopt
   (ticket hermano #250). Sin fichero no hay ventana y no se cuenta nada. No se añade otro escaneo del historial.
3. **Qué cuenta.** Las ALTAS que ese drain va a subir en las tablas que piden linaje (todas menos `ExchangeRate`, la misma
   exención que la guarda: `adoptLineageExemptTables`), con una identidad que el backend NO conocía en el adopt. Las de
   identidad conocida ya no suben (#250) y no cuentan. Cambios y borrados no: el ticket pregunta por lo que LLEGA.
4. **Autor, en dos series.** `mirror` (la transacción lleva la firma del espejo: bajó de iCloud, el caso del ticket) y
   `local` (cualquier otro autor: lo creado en este teléfono en la ventana, legítimo). La segunda está a propósito: que el
   espejo firme sus imports no está medido en device; si no firmara, lo importado aparecería en `local` y la serie `mirror`
   en cero mentiría. Con las dos, el número se lee en ambos mundos.
5. **Por qué camino entró el adopt.** Se guarda junto a la lista del backend (fichero `….adopt-route`, mismo ciclo de vida):
   `none` / `noAccount` (la sonda de iCloud dijo que no había nada que probar: la población peligrosa del ticket), `found`
   (había corpus y se esperó a su import), `lineageRows` (había filas locales que pedían linaje: no se preguntó a iCloud) y
   `noMirror` (el espejo no estaba adjunto). Sin fichero, `unknown`. Es lo que separa el caso 2 del ticket (otro Apple ID
   tras un `noAccount`) del caso 1 (el iPad del mismo dueño tras una prueba de linaje).
6. **Telemetría.** Canario `cloudAdoptLateImportUnproven`, `value` = cuántas altas en ese drain. Sin identificadores,
   nombres ni importes. *Corregido tras la review:* el detalle agrupa en `<autor>|<camino>|<clase>` (clase
   `TransactionItem` u `other`) en vez de `<tipo>|…`: por tipo, la vuelta que trae un corpus entero emitiría hasta 30
   eventos y el spool de métricas (50) tiraría canarios ajenos. El tipo exacto queda en el rastro del dispositivo.
7. **Device-QA.** CloudKit no existe en el simulador: el canario solo se ve con iPhone real. Ticket a `qa` con guion.
8. **Review adversarial.** Toca el drain del sync (lógica cara aunque no cambie la salida): sí, tres lentes.
9. **El gemelo de Grupos y #358.** Ni se tocan.
10. **Tras la review (tres lentes) y dos tandas de mutantes**, aceptado: suelo por el ancla del cursor (un re-anclaje del
    token contaba huérfanas ya subidas), contar la fila añadida y no el alta traducida (medido: el re-drain tras un kill no
    deduplica), agrupar el detalle, y los huecos de tests (conteos de 2+, controles positivos, `defer`). Abiertos como
    tickets: la salida por backend vacío (sin ventana) y el hueco entre el reconcile y el paso 3. Documentados sin ticket:
    la serie `local` incluye altas derivadas del arranque, y una retirada que no puede borrar deja la ventana abierta.
