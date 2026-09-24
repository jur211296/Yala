# Tras el cutover, B entra aunque A no haya exportado el marcador

## Contexto
Residual medium de la review adversaria de `claim-grants-a-takeover-after-the-leader-passed-the-cutover` (PR #239, mergeado a 2.1 el 2026-09-24). Con g16_04, si A pasó el cutover del servidor (`migrated_at` puesto) y el lease venció, B recibe `existing_stable` y va al adopt. El adopt exige el marcador de cuenta en el store local cuando hay filas huérfanas; si A se quedó sin exportar el marcador (dormido en `cutover(.markerWritten)`, o agotó el tope y volvió a iCloud borrándolo), B con datos propios se queda en `.lineageUnproven` y no entra nunca si A no vuelve. Ticket en `tickets/in-progress/adopt-after-the-cutover-needs-a-marker-the-leader-never-exported.md`. Relacionado, no duplicado: `cutover-marker-without-a-session-locks-out-the-second-device`.

## Que se pide
Cierra el callejón: un segundo teléfono con datos propios entra en una cuenta cuyo líder pasó el cutover del servidor sin exportar el marcador, o deja una salida escrita para ese caso.

Candidatas en el ticket (elige la robusta / buena práctica, nunca la más simple):
1. Cliente: sin marcador, aceptar como prueba de linaje lo mismo que la ida (`checkForwardLineage`: identidad compartida con el backend), midiendo que no reabre `adopt-uploads-a-foreign-corpus-without-a-lineage-check`.
2. Servidor: señal de «marcador exportado» y que la rama g16_04 la exija; sin ella, el relevo de antes.

Frank ya eligió robustez: implementa la opción recomendada tras medir; no preguntes a Jürgen por techos/copy/candidatas de producto. Solo AskUserQuestion si hace falta su dispositivo, secretos o acceso real (horario diurno 6:00–21:00 Lima).

## Que NO hay que tocar
- marketing/ ni Web/
- No paralelizar otro encargo de Yala
- No reabrir el bug de corpus extranjero en adopt
- No reinventar g16_04: el claim post-cutover ya da adopt

## Como se sabe que esta bien
- Criterios del ticket cumplidos (tests / mutantes según el área)
- Gate verde, PR a 2.1, docs/TICKETS.md e índice al día, ticket movido (qa si hace falta device-QA; done si no)
- Residuales nuevos → ticket propio antes de cerrar
- /cerrar-total al terminar

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board del repo (actualizar `docs/TICKETS.md`), merge y /cerrar-total sin preguntar si corre el gate o el commit. La regla del repo «espera aprobación si >3 ficheros» / «¿Sigo?» tras el plan queda suspendida en este encargo: implementa hasta cerrar. Solo parar ante decisión/acceso real de Jürgen (dispositivo, secretos). Bugs/decisiones nuevas → ticket propio antes de cerrar. Board: create/move directo en `tickets/` (sin inbox Tim).

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory. URL/key solo en la Mini.

## Paso 0 (2026-09-24, Frank en autónomo)

**D1 — Candidata: la de cliente.** El adopt da por probado el linaje con el marcador de la cuenta **o** con una fila viva
del backend que esté en el store local, en su tabla (la prueba de `checkForwardLineage`). Por qué, medido:
- La prueba por identidad ya guarda el relevo, que sube el corpus ENTERO; el adopt solo sube huérfanas. Aceptarla aquí no
  abre nada que la ida no acepte ya.
- La de servidor exige a g16_04 una señal nueva y, sin ella, **devuelve el relevo** que Jürgen retiró en #239 («B adopta,
  no espera ni releva»). Contradice su decisión y cambia el protocolo del líder.
- Cierra también el síntoma de `cutover-marker-without-a-session-locks-out-the-second-device` (marcador con hash vacío) y
  el falso bloqueo de un marcador que aún no se importó.

**D2 — ¿Reabre `adopt-uploads-a-foreign-corpus-without-a-lineage-check`?** No, medido: ninguna tabla personal tiene
identidades fijas entre teléfonos (sin `UUID(uuidString:)` de siembra; las entidades de sistema se acuñan por dispositivo,
`SystemEntityMergePolicy`), así que un corpus de otro iCloud no comparte ninguna. `exchange_rates` no cuenta
(`adoptLineageExemptTables`, la misma excepción). El test que decía «lo único que los separa es el marcador» modelaba el
corpus ajeno CON una identidad compartida, que un teléfono real no puede tener: se corrige el fixture, no la guarda.

**D3 — Detalles.** Solo filas VIVAS del backend (como la ida). El marcador se mira primero: su tabla ilegible sigue siendo
`.localFailure`. La enumeración ya está verificada contra el Merkle antes de la guarda. Se decide en los dos planes, con el
inventario de cada uno. Un solo helper para el cruce, compartido con `checkForwardLineage`.

**D4 — Fuera.** La tarjeta de Ajustes sin marcador sigue en «Migrar a la nube», que no llega al adopt:
`settings-migrate-blocks-a-second-device-before-its-marker` (backlog, sin tocar). Sin texto nuevo: el de
`effectLineageUnproven` sigue siendo verdad para quien no tiene ninguna de las dos pruebas.

**D5 — Verificación.** Unit + mutantes (área: cálculo de sync, review adversarial de 3 lentes). Sin device-QA propio: el
escenario pide un líder dormido en `markerWritten` más de una hora; va a `done` si la review no pide otra cosa.

**D6 — Tras la review (3 lentes).** La lente del dispositivo legítimo cazó que UNA fila compartida no basta: con la
exportación del líder parada, la cuenta (`shortcutID`) se comparte pero sus movimientos siguen sin identidad y el
backfill los subiría duplicados. El marcador lo impedía de hecho (se exporta después). Se exige además que, en cada tabla
que sube, estén todas las filas vivas de la cuenta (`adoptSharedRowsProof`). La lente del corpus ajeno encontró un
store mezclado por la vuelta a iCloud: medido que esa cuenta sigue congelada (`reverse_frozen_at`) y su push da 409, así
que no llega; queda escrito en la regla. El camino de Ajustes sin marcador no llega al adopt (D4): el criterio se marca
con ese alcance escrito.

