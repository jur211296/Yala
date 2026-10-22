# El adopt no debe subir a una cuenta un corpus que no desciende de esa cuenta

## Contexto
Cola A (callejones de nube) sigue en bypass autónomo. Acaban de mergear #232–#234
(reintento del claim + g16 staging + reintento que no siembra al lado de otro
teléfono). Jürgen ordenó (2026-09-24): drenar los mediums de cola A y, al
vaciarlos, pasar solo a cola B (rediseño/UI) — este ticket es el siguiente medium
de callejón.

Ticket: `tickets/backlog/adopt-uploads-a-foreign-corpus-without-a-lineage-check.md`
(si el slug en disco difiere por un guion, usa el fichero real en backlog cuyo id
hable de adopt + corpus extranjero / linaje).

El adopt (`runAdoptOrphanReconcile` / flujo de adopt) sube como huérfana toda fila
local cuya identidad no está en el backend, sin comprobar que el corpus local
desciende de esa cuenta. Caminos que quedan: seguidor de un adopt con otro corpus;
relevo de líder callado (>60 min); sesión de persona anterior tras «Empezar desde
cero» con marcador superviviente. La tarjeta de adopt se ve más desde
`adopt-claim-stays-parked-with-no-ceiling`.

## Que se pide
1. Cerrar el agujero: ni el seguidor de un adopt ni un relevo suben a una cuenta un
   corpus que no desciende de esa cuenta (o documenta el caso como aceptado con
   decisión explícita en Paso 0 / ticket).
2. El segundo dispositivo del mismo Apple ID debe seguir adoptando, con sus
   huérfanas de la ventana.
3. Decisión de producto YA tomada por Frank (norma robusta / good-practice; no
   preguntar a Jürgen): **guarda de linaje dentro del escritor** (`runAdoptFlow`):
   adoptar solo si el `CloudMigrationMarker` del líder está en el store local.
   El faro (`CloudBeacon`) NO vale como prueba. Si el espejo del segundo dispositivo
   aún no importó el marcador, no reintentar para siempre: salida clara (bloqueo /
   cancel / techo alineado con adopt claim 15 min local / 72 h red) con copy
   honesto. Anótalo en el ticket y en Paso 0 como asumido.
4. Cubrir con tests el caso «corpus extranjero no sube» y el caso «segundo
   dispositivo mismo Apple ID sí adopta».
5. Gate verde, PR a `2.1`, merge, board/docs/TICKETS.md al día, `/cerrar-total`.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board del repo, actualizar `docs/TICKETS.md`, merge y
`/cerrar-total` sin preguntar si corre el gate o el commit. Bugs/decisiones nuevas
→ ticket propio antes de cerrar. Solo parar ante secreto/acceso de dispositivo o
decisión demasiado gorda para asumir (norma Frank: robusto, no lo más simple).
La regla «esperar OK si >3 ficheros» / «¿Sigo?» tras el plan está suspendida en
esta cola: implementa hasta cerrar.

## Que NO hay que tocar
- `marketing/` / Web/ (Lola).
- No redeploy masivo del Worker salvo lo estrictamente necesario para este fix.
- No abrir cola B ni tickets de rediseño UI en este encargo.
- No pedir a Jürgen techos/copy/adopción: ya decididos (robusto).

## Como se sabe que esta bien
- Criterios del ticket cumplidos (o caso aceptado documentado).
- Tests nuevos/actualizados en verde en el gate.
- PR mergeado a `2.1`; ticket movido (done si no hace falta device-QA; qa si sí).
- `/cerrar-total` limpio; worktree listo para limpiar.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Qué cuenta como prueba de linaje?** → Una fila `CloudMigrationMarker` en el store local cuyo `accountHash`
es el hash (`CloudBeacon.hash`) del `sub` de la sesión del adopt. Cualquier fila vale si casa; un hash vacío no prueba nada.
Por qué: el marcador lo escribe el líder de ESA cuenta en su CloudKit, y solo llega a este store si este dispositivo espeja
ese corpus. Alternativa descartada: «hay algún marcador» — un marcador de otra cuenta (una migración anterior de este iCloud)
lo daría por bueno. El faro, descartado por el ticket (lo escribe también el alta born-cloud).

**D2 · ¿Se exige siempre, o solo cuando hay algo que subir?** → Solo cuando el plan preliminar tiene filas que subir
(huérfanas o sin identidad). Sin nada que subir, el adopt sigue como hoy.
Por qué: el 2.º dispositivo de una cuenta NACIDA en la nube entra por el mismo adopt (`BornCloudSignUpFlow.continueAsReturningUser`
→ claim → `existing_stable` → `runAdoptFlow`) y nunca puede tener marcador: exigirlo siempre lo dejaría fuera, y el criterio 2
lo prohíbe. Sin filas que subir no hay corpus que mezclar. Alternativa descartada: exigirlo siempre (rompe born-cloud).

**D3 · ¿Dónde vive la guarda?** → Dentro de `runAdoptOrphanReconcile`, el escritor que sube, tras el plan preliminar y ANTES
del guard de backend vacío y de cualquier mutación (backfill incluido). `runAdoptFlow` la traduce a un error propio.
Por qué: es la única función que sube; ponerla en `runAdoptFlow` dejaría fuera a quien llame al reconcile directo. Va antes
del guard de backend vacío porque ese guard SIGUE el adopt (cambia el modo) y con un corpus ajeno en local eso deja las filas
ajenas dentro de una cuenta que no es suya, listas para subir en la primera edición.

**D4 · ¿Qué pasa si no hay prueba?** → Nada se toca, el efecto queda pendiente y cuenta como causa DEFINITIVA para el techo
CORTO del efecto (15 min acumulados, el reloj de `adopt-effect-retries-forever-with-no-ceiling`), con salida propia
`AdoptClaimExit.effectLineageUnproven` y su texto. La espera de iCloud va antes (quiescencia), así que un marcador que aún
se está importando pausa el reloj en vez de sumarlo.
Por qué: el caso ajeno no se arregla esperando y 72 h de tarjeta de progreso sería mentir; el caso legítimo con retraso sale
recuperable: la tarjeta de adopt vuelve (con marcador, o por la marca de salida atada a la cuenta) y el reintento pasa.
Alternativa descartada: plazo largo (72 h) — el caso que la guarda existe para parar es justo el que nunca se resuelve.

**D5 · ¿Qué salida nombra el techo corto con dos causas definitivas?** → La de la observación que lo vence (la base local o el
linaje). El corto solo vence en una observación con motivo, así que siempre hay uno que nombrar.
Por qué: el texto dice lo que se acaba de ver. Alternativa descartada: un «causas mezcladas» como en la subida — dos causas
turnándose aquí exigen un inventario que falla a ratos, y no hay evidencia de que pase.

**D6 · Camino 2 (el relevo de un líder callado).** → **Fuera de este PR, con ticket propio**
(`migration-takeover-uploads-without-a-lineage-check`).
Por qué: el relevo no pasa por el adopt sino por la subida del LÍDER (el `created` del takeover de `claim_account`), y ahí el
marcador no puede servir de prueba: el líder callado nunca llegó al cutover. Hace falta otra prueba (solape con lo que el
backend ya tiene) y otra salida, en el camino más caro de la migración. Medido además: el seguidor que ve `leaderVanished`
re-reclama y también puede recibir ese takeover, y el claim de un adopt también. Van al mismo ticket.

**D7 · Camino 3 (la sesión de la persona anterior).** → No lo cubre esta guarda (el marcador SÍ está) y no hace falta aquí:
`previous-person-cloud-session-survives-fresh-start-and-reinstall` (en `qa`) purga la sesión en «Empezar desde cero» y en la
reinstalación, así que no queda sesión que reusar. Se anota en el ticket.

**D8 · Texto de la salida.** → Asumido, sin preguntar (el encargo lo delega): dice que no entramos, por qué (datos de este
dispositivo que no podemos comprobar que vengan de esa cuenta), que lo de aquí sigue aquí, y la acción del caso legítimo
(esperar a que iCloud traiga los datos y reintentar). En los 16 locales.

**D9 · (review) ¿Qué filas piden prueba?** → Todas menos `ExchangeRate` (`adoptLineageExemptTables`).
Por qué: el arranque siembra tipos de cambio sin identidad ANTES del Welcome, así que D2 era falso en un teléfono real y el
2.º dispositivo de una cuenta nacida en la nube no entraba nunca. Son caché pública, no corpus de nadie; siguen subiendo.
Alternativa descartada: no sembrarlos antes del Welcome — toca el arranque, fuera de alcance.

**D10 · (review) ¿Sobre qué plan se decide?** → Sobre el preliminar y otra vez sobre el definitivo, que es el que sube.
Por qué: una fila que el import confirma entre las dos lecturas se subía sin prueba si el preliminar no la pedía.

**D11 · (review) ¿A qué cuenta queda atada la marca de esta salida?** → A ninguna.
Por qué: aquí la cuenta del intento es la sospechosa; atarla bloqueaba entrar con la buena. La guarda protege la subida
con cualquier cuenta. El texto pide además comprobar que se entra con la misma cuenta.

**D12 · (review) Lo que no se arregla aquí.** → A ticket: el adopt sobre store vacío con el espejo importando después
(medium), el marcador escrito sin sesión (low). Aceptado: el reloj corto de pared tras segundo plano (recuperable).
