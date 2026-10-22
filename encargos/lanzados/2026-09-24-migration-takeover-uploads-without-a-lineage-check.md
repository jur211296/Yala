# El relevo de una migración abandonada no sube un corpus sin linaje con lo que la cuenta ya tiene

## Contexto
Residual del PR #235 (`adopt-uploads-a-foreign-corpus-without-a-lineage-check`, a qa). El camino 2 de ese ticket —relevo de un líder callado vía `claim_account` con lease expirado— no pasa por el reconcile del adopt: es la subida del LÍDER tras un `created`. Ticket: `tickets/backlog/migration-takeover-uploads-without-a-lineage-check.md`. Rama base `2.1`.

## Que se pide
Cierra el ticket. Un relevo cuyo corpus no comparte linaje con filas personales vivas del backend no sube nada y sale con texto honesto. El relevo legítimo (mismo Apple ID, líder muerto a mitad) sigue terminando. El alta normal sobre cuenta vacía / solo grupos no paga una espera nueva.

Mide antes de inventar: el ticket ya propone candidatos (enumeración post-`created`, campo de relevo en `claim_account`); verifica riesgos de falso bloqueo por retraso de importación de identidades. Elige la opción robusta / good-practice (no la más simple).

## Que NO hay que tocar
- `marketing/` ni Web/
- No reabrir el ticket padre (ya en qa con su guion de device-QA)
- No paralizar la cola por device-QA del padre

## Como se sabe que esta bien
Criterios del ticket en verde (tests + docs). Gate, PR a `2.1`, merge, board/TICKETS al día, `/cerrar-total`. Bugs/decisiones nuevas → ticket propio antes de cerrar.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board del repo, actualizar `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar si corre el gate o el commit. La regla del repo «espera aprobación si >3 ficheros» / «¿Sigo?» tras el plan queda suspendida en este encargo: implementa hasta el cierre. Solo para ante decisión de producto/acceso real (AskUserQuestion 06:00–21:00 Lima) o secreto/device de Jürgen. Board de proyectos: create/move directo.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**Medido antes de decidir (2026-09-24).** `claim_account` vivo en staging y producción: md5 `ab0e59d0…` (g16_02), con
CINCO `return` de `created` (alta nueva, promoción, relevo, re-claim del mismo líder, g16_01). El Worker devuelve el JSON
del RPC tal cual (`gateway/src/sync/account.ts`), así que un campo nuevo llega al cliente sin deploy. La subida del
snapshot va por tablas en orden UTF-8 (`accounts` primero, `tx_items` al final): las primeras páginas que un líder sube son
de tablas con identidad PROPIA desde que la fila nace (`Account.shortcutID`, `Budget.id`…), que un 2.º dispositivo del
mismo iCloud ya tiene por CloudKit sin esperar a que el líder le asigne nada. Ninguna identidad es fija en el código
(`UUID(uuidString: "…")`: cero en `Yala/`).

**D1 · ¿Qué prueba el linaje en un relevo?** → Que alguna fila VIVA del backend (fuera de `exchange_rates`) esté en el
inventario local, con su tabla y su identidad. Sin filas vivas personales en el backend no hay nada que mezclar y sigue.
Por qué: una identidad aleatoria solo llega a este store por el CloudKit del mismo iCloud (o por un pull de esa cuenta).
El marcador no sirve (el líder callado nunca llegó al cutover) y el faro tampoco (lo escribe el propio claim del relevo).
Alternativa descartada: exigir solape «suficiente» — una sola identidad aleatoria compartida ya es la prueba.

**D2 · ¿Cómo se sabe que hay que comprobarlo sin pagarlo en cada alta?** → Pista del servidor: `claim_account` añade a
toda respuesta `created` el campo `has_personal_writes` (hay fila en `sync_seq_counters`, la señal de g16_01). Migración
`g16_03`, en staging y producción. El cliente comprueba si la pista es `true` o FALTA (un servidor sin g16_03: falla
cerrado, paga la enumeración).
Por qué: el alta normal —cuenta nueva o solo de grupos— nunca tiene contador, así que no paga red nueva (criterio 3). Y la
pista cubre también el re-claim del mismo líder tras un relevo cuya respuesta se perdió, que un campo «esto es un relevo»
no vería (esa rama es la del líder idempotente). Alternativas descartadas: comprobar siempre (dos viajes y un modo de
fallo nuevo en cada alta), o un campo solo en la rama del relevo (se pierde con la respuesta).

**D3 · ¿Dónde vive la comprobación?** → En el paso de identidad (35 %), ANTES de `assignIdentity()`, tras la quiescencia que
el runner ya espera en cada pasada. La pista se journalea en el MISMO save de la transición `created → assigningIdentity`
(`MigrationState.forwardLineageUnverified`, schema 16); probada, se journalea `false` para no repetir la enumeración.
Por qué: es la última parada antes de subir y antes de cualquier mutación local (backfill, captura). Una pista journaleada
sobrevive al relanzamiento, que es cuando el claim no se repite.

**D4 · ¿Qué pasa sin prueba?** → Nada se toca; causa DEFINITIVA `lineageUnproven` del techo corto del paso (15 min), salida
a `failedRollback` con `[.rollback]` y texto propio (`storage.failed.stepLineageUnproven`, 16 locales), el mismo en
Almacenamiento y en la bienvenida. La red y una enumeración incompleta van al largo (72 h).
Por qué: es el molde de los tres pasos de la ida; los 15 min absorben un import que llega tarde.

**D5 · ¿Y el sello del claim?** → ~~La salida por linaje retira el `.proceedMigration`.~~ **Retirada en la review:** el sello
se queda, y «Reintentar» vuelve a comprobar.
Por qué: el relevo bloqueado sigue siendo el líder de la cuenta, así que cualquier entrada suya —también el adopt que la
puerta de «Migrar» recomienda al ver la cuenta con datos— recibe `created` y vuelve a comprobar. Retirar el sello no cortaba
el bucle y sí le quitaba al relevo LEGÍTIMO bloqueado en falso (import lento, identidades reparadas por dispositivo) su vía
de reintento, que es justo su recuperación: cuando sus datos llegan, la comprobación pasa. El precio es del ajeno: cada
reintento manual cuesta 15 min y acaba en el mismo texto.

**D6 · Texto.** → Asumido: dice que no se activó, por qué (esa cuenta ya tiene datos en la nube y los de este dispositivo no
coinciden), que no se juntaron, «lo que tienes en este dispositivo sigue aquí» (el vecino del adopt vetó «tus datos siguen
aquí») y dos acciones que se recorren: comprobar la cuenta, y —si es la suya y usa el mismo iCloud— esperar a iCloud y
reintentar. No culpa a «otro dispositivo» (los datos pueden ser de un intento anterior de este mismo; lo cazó la review) ni
promete «termínala desde el otro dispositivo»: ese camino pasa por el lease de este (60 min) y por un «otro dispositivo tomó
el relevo» en el primero. La bienvenida lleva la flecha y «Reintentar».

**D8 · (review) ¿Dónde se escribe la pista?** → En `handle`, al ENTRAR en `assigningIdentity`, no en `driveClaim`.
Por qué: a la identidad llegan dos claims —el de `driveClaim` y el del seguidor que recibe el relevo (`pollLeaderInternal`)—,
y el caso del ticket es el segundo; escrita solo en `driveClaim`, el seguidor leía lo que quedara en el journal. Cada entrada
la reescribe, así que un `false` de un intento anterior no se hereda.

**D9 · (review) Lo que no se arregla aquí.** → A ticket: el líder desplazado que vuelve y sigue subiendo
(`displaced-migration-leader-keeps-uploading-after-a-takeover`, medium, previo a este ticket) y «Cancelar» al 35 % en la
bienvenida (`welcome-cancel-during-the-identity-step-does-not-return-to-the-chooser`, low). Aceptado: un build v15 que
actualiza con la subida del relevo ya empezada no comprueba (la guarda vive en la identidad), y la enumeración se repite
entera en cada pasada mientras dura `unproven` (solo en el relevo; `proven` corta sin el Merkle).

**D7 · Residuales aceptados.** (1) El relevo bloqueado se queda el lease hasta que caduca (60 min desde el relevo): no hay
RPC para soltarlo. (2) Un relevo legítimo cuyo líder solo llegó a subir tablas de identidad SINTÉTICA y cuyo export a
CloudKit no salió nunca sale bloqueado; con `accounts` primero en la subida hace falta un líder sin cuentas —o cuentas cuyo
`shortcutID` repara cada dispositivo por su cuenta (`repairCollapsedIdentityUUIDs`), que la review señaló y convergen por
CloudKit—. Se recupera reintentando cuando los datos llegan (D5), o lo termina el primer dispositivo. (3) El reloj corto
cuenta tiempo de pared (el mismo de los tres pasos).
