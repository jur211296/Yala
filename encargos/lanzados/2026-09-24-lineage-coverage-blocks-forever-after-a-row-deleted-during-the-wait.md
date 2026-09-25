# Un borrado en el otro teléfono durante la espera no puede dejar el relevo ni el adopt sin salida

## Contexto
Residual de la review adversarial de `migration-takeover-may-duplicate-rows-whose-leader-identities-never-arrived` (PR #241, mergeado a 2.1). Ese fix hace que el relevo espere a que iCloud traiga las identidades del líder callado, en vez de subir duplicados. Quedó un callejón: si en el teléfono B se borra (o un deduplicador funde) una fila que A ya subió al backend, la cobertura de linaje (`MigrationWorkExecutor.adoptSharedRowsProof` / `checkForwardLineage`) exige que toda fila VIVA del backend esté en local. B no puede distinguir «identidad aún no llegó» de «fila borrada aquí» (los `SyncIdentity` son locales; un borrado por CloudKit no deja testigo). El motor del líder, callado, es el único que podría tombstonear esa fila en el backend. Resultado: relevo y adopt se quedan para siempre en «espera a iCloud».

Ticket: `tickets/in-progress/lineage-coverage-blocks-forever-after-a-row-deleted-during-the-wait.md` (ya movido a in-progress en el árbol principal; alinear worktree/`docs/TICKETS.md` al arrancar).

Hermano en backlog (NO este encargo): `displaced-leader-late-identity-export-can-rekey-the-relief-corpus` — export tardío del líder desplazado. Si al medir aparece acoplado, deja ticket propio; no lo mezcles.

## Que se pide
1. Reproducir / fijar con prueba el caso: A subió filas y calló; B borra (o funde) una de esas filas vivas en backend; B toma relevo o adopt → hoy bloquea sin salida.
2. Arreglar sin reabrir el duplicado que cerró #241: el relevo/adopt no debe subir a ciegas las filas del líder cuyas identidades aún no llegaron.
3. Decisión de producto (Frank, robusta — NO preguntar): **no** tomar la salida «subir igualmente, puede duplicar». Preferir casar por contenido/ancla de `SyncIdentityService` las filas sin identidad local con las del backend, o una salida recuperable alineada con #241 (techo + pedir abrir Yala en A / reintentar) que desbloquee sin duplicar. Elige la opción más robusta y medible; documenta cuál en el PR.
4. Cubrir el matiz medido de deduplicadores (`NotificationService` / `CategoryDeduplicationService`): el bloqueo que evita un duplicado real de categoría semilla no puede dejar eterno el callejón si A no vuelve — misma familia de salida.
5. Si `verifyEnumerationComplete` (Merkle incompleto) sale al camino, ticket residual aparte — no hinchar este.

## Que NO hay que tocar
- marketing/, Web/
- El contrato de #241 (no subir duplicados del líder callado)
- Device-QA en iPhone real (este ticket es código + pruebas; a `done` si el gate basta; a `qa` solo si hace falta mano en dispositivo)
- El hermano `displaced-leader-late-identity-export-can-rekey-the-relief-corpus` salvo ticket residual si aparece

## Como se sabe que esta bien
- Prueba(s) roja→verde: borrado (y, si cabe sin inflar, fusión dedup) durante la espera ya no deja relevo/adopt sin salida
- No se reabre el duplicado de #241 (pruebas de cobertura de linaje del líder callado siguen pasando)
- Gate verde, PR mergeado a 2.1, board/`docs/TICKETS.md` al día, `/cerrar-total`

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board del repo, actualizar `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar si corre el gate o el commit. Bugs/decisiones nuevas → ticket propio antes de cerrar. Solo parar ante decisión/acceso real (noche: elige lo recomendado / robusto; no uses AskUserQuestion salvo acceso/secrets de Jürgen). Suspendida la regla «¿Sigo?» / wait-for-approval si >3 files: implementa hasta cerrar.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git) cuando: (1) decisión de producto o acceso de Jürgen; (2) abriste el PR o preview listo; (3) terminaste y vas a /cerrar-total — resumen corto en lenguaje de usuario; (4) tramo sin siguiente paso claro (una vez). NO avises por test rojo que reclasificas, build a reintentar, ni CI advisory.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Qué salida para la fila que falta?** → Una fila viva del backend que falta aquí solo bloquea si en este
teléfono puede haber su GEMELA con otra identidad. Si no puede, no hay nada que duplicar y el relevo/adopt sigue.
Por qué: el duplicado de #241 exige una gemela local; un borrado no la deja. Alternativa descartada: «subir igualmente»
tras el techo (puede duplicar; prohibida por el encargo) y «esperar a que A vuelva» (si no vuelve, eterno).

**D2 · Tablas de identidad sintética (movimientos, categorías, borradores, favoritos, comercios)** → se casa cada fila
que falta con las locales sin identidad del backend (sin `syncID` o huérfanas) por una CLAVE DE LINAJE inmutable
leída del wire: `created_at` (ms) en movimientos/borradores/favoritos, `merchant_canonical` en comercios, y en
categorías la clave del deduplicador (`icon|color|isIncome`) para las semilla y el nombre normalizado para el resto.
Casa → la local toma la identidad del backend (rebind, sin esperar). Clave legible y sin gemela → no bloquea. Clave
ilegible → bloquea como hoy (`accountRowsMissing`). Por qué: `created_at` no se edita y es igual en los dos teléfonos;
el ancla de contenido de `SyncIdentityService` incluye importe y fecha, que sí se editan, y un movimiento editado
durante la espera no casaría y se duplicaría. Alternativa descartada: el ancla de contenido tal cual.

**D3 · Tablas de identidad propia (cuentas, presupuestos, etiquetas, avisos…)** → su identidad viaja con la fila, así
que la única gemela posible es una fila que este teléfono re-identificó (reparación de UUID colapsados) o una semilla
por dispositivo. Siguen bloqueando, salvo que el historial de SwiftData de este teléfono tenga el BORRADO de esa
identidad (`.preserveValueOnDeletion` la conserva en el tombstone): testigo positivo de «se borró aquí», también
cuando lo borró un deduplicador. Alternativa descartada: no pedir cobertura ahí (reabría la gemela re-identificada que
la regla cita como caso legítimo).

**D4 · ¿La fila borrada vuelve?** → Sí: sigue viva en el backend y el `verify`/pull la baja (zombi), como antes de
#241. No se tombstonea desde B (no distingue «borrada» de «no llegó» en las sintéticas). Ticket residual propio.

**D5 · Deduplicadores** → categoría semilla fundida: la superviviente casa por la clave del deduplicador y toma la
identidad de la fundida. Subcategorías/avisos semilla fundidos: testigo de borrado del historial (D3). La copia que
vuelve por el pull la vuelve a fundir el deduplicador en el arranque (inferido, no medido).

**D6 · `verifyEnumerationComplete`** → no sale al camino de este arreglo; si no hay ticket, se abre uno residual.

**D7 · Entrega** → worktree: rama + PR, gate, review adversarial (toca sync/migración), merge con CI verde, ticket a
`done` (código + pruebas; sin device-QA).

### Paso 0 revisado tras la review adversarial (sustituye D2, D3 y D5)

La review de tres lentes tumbó dos premisas mías: «clave legible y sin gemela ⇒ no bloquea» falla ABIERTO (la clave
puede no casar siendo la misma fila: categorías editadas, `createdAt` que la migración ligera rellenó en cada teléfono
por su cuenta, colisiones del mismo milisegundo que cruzaban identidades), y el testigo de borrado del historial no
cubre al deduplicador (la gemela es la superviviente, con otra identidad).

**D2' · Criterio** → falla cerrado. Tras casar, una fila que falta bloquea mientras quede una candidata (fila sin
identidad del backend en esa tabla) sospechosa. Dejan de serlo la creada aquí después de la última escritura del backend
(historial de SwiftData, sin el autor del espejo, +10 min) y la semilla que el deduplicador vuelve a fundir.

**D3' · Casado** → solo con una clave única en el backend y entre las candidatas.

**D5' · Deduplicadores** → categoría semilla fundida: casa por la clave del deduplicador. Subcategorías semilla y avisos
supervivientes: no cuentan como sospechosos; el duplicado que suba lo funde el deduplicador del arranque en la nube
(inferido del código, no medido en device).

### Segunda review (sustituye D5' y precisa D3')

**D3'' · Casado** → clave única en el backend (contando todas las vivas) y entre las candidatas; una fila del backend
sin clave legible apaga el casado de su tabla. Las categorías del usuario no casan por nombre (renombrar para fundir
cruzaba identidades).

**D5'' · Deduplicadores** → la semilla superviviente deja de ser sospechosa solo si su clave de FUSIÓN (la del
deduplicador que la fundiría) es la de una fila sin explicar. Una semilla editada en el líder no casa ni se exime.

**D8 · Adopt con otro teléfono escribiendo** → fuera de este encargo, ticket propio: el corte global es a propósito.
