---
id: cloud-tx-epoch-orphan-relations
status: qa
priority: medium
created: 2026-07-17
updated: 2026-10-08
source: YalaWiki/Bugs/qa_cloud-tx-epoca-relaciones-huerfanas.md
---


# TX de época nube pierde sus relaciones (cuenta/subcategoría nil) — detectada tras la reversa

## Síntoma (device QA, 2026-07-17, build HEAD `d460480b` + fix alert)

TX "Prueba staging" (−500 PEN), creada en `.cloud` (~20:42Z) con cuenta ("Cuenta principal PEN") y
subcategoría ("Supermercados") asignadas. Tras la reversa completa (~20:48Z, VERDE en todo lo demás),
la TX local aparece **sin cuenta y sin subcategoría**: invisible en Registros (los listados filtran/agrupan
por cuenta), hallada solo vía Buscar. El owner reasignó a mano y persiste bien.

## Evidencia clave (fija la ventana del daño)

- **La fila de staging porta las TRES refs pobladas** (`account_ref=20f78316…`, `subcategory_ref=d9d3d94d…`,
  `category_ref=e6495df9…`, hlc `2026-07-17T20:42:12.170Z`, server_seq 4144) — el emit del drain deriva las
  refs de la RELACIÓN VIVA (`Emit.ref(m.account?.shortcutID)`) ⇒ a las 20:42 las relaciones locales existían.
  ⇒ la pérdida ocurrió LOCAL, entre el push (20:42) y la observación post-reversa (~20:50).
- **Solo ESA TX** — las 2311 TXs pre-época quedaron intactas, incluidas las cientos que apuntan a la MISMA
  "Cuenta principal PEN" ⇒ los objetos Account/Subcategory nunca se borraron ⇒ se descartan:
  `healDuplicates` (merge re-apunta, no nil-ea; no cubre Subcategory), cascades `.nullify` (habrían
  arrastrado a todas las TXs del account), y borrado+reimport del related.
- Algo escribió `tx.account = nil` / `tx.subcategory = nil` **sobre esa TX concreta**. La única maquinaria
  que escribe relaciones de una TX individual es el **applier del pull** (resuelve `account_ref` → objeto y
  setea la relación).

## Hipótesis de trabajo (a discriminar)

**El ECO del pull en `.cloud`**: la TX es la única del corpus que vivió el ciclo push → pull con su propia
fila de vuelta (eco). Si el applier re-aplica el row propio (¿el guard HLC-idempotente no lo suprime?) y la
resolución de refs falla o el orden de campos deja las relaciones nil, el daño ocurre YA en la época
`.cloud` — la reversa solo lo hizo visible. Alternativa (menos probable): un apply durante la reversa
(re-drain de verify mismatch — pero el verify convergió a la 1ª; el sweep de zombies es read-only sin
applyPage).

## Experimento discriminante — ✅ EJECUTADO (2026-07-17, misma corrida): ECO EXONERADO

En el nuevo `.cloud` post-re-migración: TX `qa-eco` creada con las MISMAS cuenta/subcategoría del caso
original → push capturado con las 3 refs (`server_seq 23547`, ids idénticos al caso) → ≥2 ciclos de
cadencia en foreground → detalle OK → **kill + relaunch → detalle OK** (relaciones intactas, sin caches).
**Evidencia adicional (misma corrida, Fase D adopt):** el adopt post-sign-out re-materializó el corpus
COMPLETO desde el backend (pull desde cursor 0) y AMBAS TXs ("Prueba staging" re-anotada y `qa-eco`)
llegaron con cuenta/subcategoría correctas ⇒ **el applier resuelve refs bien también en materialización
fresca**. El bug es exclusivo del camino de la reversa.

⇒ El eco del pull en `.cloud` estable NO nil-ea relaciones. **La ventana del daño queda en la REVERSA**:
sospechosos restantes, en orden — (a) apply/re-drain dentro de la reversa (aunque el verify convergió a
la 1ª, ¿corrió algún applyPage?); (b) la ventana remount del mirror (replay export + catch-up import
simultáneos sobre una TX sin CKRecord previo cuyas relaciones apuntan a records preexistentes);
(c) interacción con el timing corto TX-creada→reversa (~4 min). Repro sugerido para la sesión de
investigación: migrar sim/device pequeño → crear TX → reversa inmediata → inspeccionar relaciones.

## Datos del entorno

- Cuenta: sub `39a05cda-264c-44a8-ba9b-7cbcb472c4e6` (`bfyhcnnt84@privaterelay.appleid.com`, Hide My Email
  de `admin@yala-app.pe`), staging `fostjbbwstyuunmmefuk`.
- Reversa VERDE en todo lo demás: `prefsDrainSentinelCleared count=2`, marker/beacon/mode/complete OK,
  sin `historyTokenIncomparable`; counts de zombies/rebinds/dedup no capturados (buffer Console reciclado).
- Guion madre: [[MODO-NUBE-I14-GUION-DEVICE]] hallazgo H-2026-07-17-4.

## Dónde mirar (código)

- Applier del pull del runtime personal (resolución de `account_ref`/`subcategory_ref`/`category_ref` →
  relaciones) y su idempotencia por `field_hlcs` ante el ECO de la propia fila.
- Supresión de eco: ¿el pull aplica rows cuyo `hlc` == unit clock local? ¿compara por unidad de coherencia?
- Reversa: `reverseDrainAll`/applyPage y el orden remount→reconcile (solo si el experimento exonera al eco).

## Clasificación

SERIO (bloqueante-de-investigación para D9): la reversa es feature v1 y el modo nube estable no puede
perder relaciones. Con 1 TX de época se vio de casualidad; un usuario con semanas de época nube tendría
N TXs huérfanas silenciosas. NO se toca código en la sesión de QA — investigación con repro propio.

## Evidencia nueva (2026-07-18, barrido de canarios AE del Bloque 2)

`cloudSyncMerkleDivergence tx_items ×8 + inbox_drafts ×8` en `yala_metrics_staging` — el Merkle
PERSONAL del device A (`.cloud`, sub 39a05cda) detecta divergencia PERSISTENTE en exactamente las 2
tablas de este ticket, una vez por ciclo de verificación (~cada 30 min), y la remediación
una-vez-por-sesión NO la cierra. Compatible con filas residuales de los resets/corridas QA del
Bloque 1 O con la misma ventana de la reversa investigada aquí. Si es local-ahead
(fila local con syncID que el backend no tiene), es la clase INCONVERGIBLE por diseño → dry-run del
panel DEBUG en A (diagnóstico FX/diverged) es el primer paso de la investigación. Query de
reproducción en qa/cloud/README § /metrics (SQL API con el token OAuth de wrangler).

migrated from YalaWiki Bugs/qa_cloud-tx-epoca-relaciones-huerfanas.md @ 1934e8ad

## Medido en 2.1 (triage 2026-10-08)

- Nadie lo ha investigado desde el 2026-07-17: no hay commits posteriores de la reversa sobre relaciones, y `docs/DECISIONS.md` lo deja como H-4 «abierto pre-D9».
- La reversa sigue siendo una función viva de 2.1 («Volver a iCloud», unos 30 tickets `reverse-*` abiertos).
- Sube a `high` porque es daño a datos en un camino normal (la única TX de época observada perdió las dos relaciones). No va a `very-high` solo porque no se ha vuelto a reproducir desde que se reescribió media reversa. **Siguiente paso:** la repro del ticket (migrar → crear TX → reversa → mirar relaciones). Si se reproduce, `very-high`.

Triage 2026-10-08: abierto · sin prioridad → high · daño a datos observado en la reversa, nunca investigado; sube a very-high si la repro lo confirma.

## Repro (2026-10-08, build `2.1` @ `4e22b6036` + esta rama): NO se reproduce en nuestro código

**Variante usada: test de integración, no nube real.** La reversa espera a que el espejo de CloudKit exporte
(`reverseUpload`) y el simulador no tiene cuenta de iCloud; la sesión de la nube en el simulador pide además
`YALA_DEV_SHARED_SECRET`, que no está en `~/Secrets`. La repro de extremo a extremo queda para el device-QA de abajo.

`YalaTests/CloudSync/ReverseEpochTxRelationsTests.swift` recorre los pasos REALES del `MigrationWorkExecutor` que
escriben en el store personal durante la reversa —`reverseDrainOnce` (drain + push + pull), `verify` (pull + Merkle),
`sweepZombies`, `verifyRebinds`, `healDuplicates`, `reverseUploadStatus`— y el dedup del arranque siguiente
(`CategoryDeduplicationService.runAllDeduplication`), sobre un store on-disk y contra un backend falso que GUARDA lo
subido y lo devuelve por `server_seq`: el movimiento de la época recibe su propio eco, como en staging. Lee las
relaciones en caliente y tras «matar y reabrir» (contenedor nuevo sobre el mismo disco), por IDENTIDAD
(`shortcutID`/`syncID`), y exige una sola cuenta y una sola subcategoría y cero `SyncDanglingRef`.

Cinco variantes, las cinco verdes en dos corridas (antes y después del rebase):

| Variante | Qué cubre |
|---|---|
| reversa inmediata | el caso original (~4 min): el eco baja DENTRO de la reversa, en el pull del drenaje |
| reversa tras varios ciclos | la espera larga: el eco ya bajó en la nube estable |
| re-pull completo | el cursor a 0 dentro de la reversa: el corpus entero se re-aplica |
| verificación en desacuerdo | el Merkle no cuadra a la primera (el device tenía divergencia en `tx_items`) y la reversa vuelve al drenaje |
| movimiento creado en otro contexto | la vista guarda en su contexto y la reversa corre en otro con las inversas ya cargadas |

**Control rojo:** con el applier de `account_ref` de `tx_items` cambiado por `m.account = nil` las cinco caen (14
aserciones en la corrida de cuatro variantes). Un mutante más débil —la búsqueda de la cuenta devuelve `nil`— sigue
VERDE, y es información: deja un `SyncDanglingRef` y el pase final de `pullAndApplyOnce` (`reresolveDanglingRefs`)
lo re-adjunta en el mismo ciclo. Para que la pérdida dure, la cuenta tiene que NO encontrarse por `shortcutID` ni en el
apply ni en el pase final.

## Lo que deja la investigación

- **La asimetría es la pista:** se perdieron cuenta y subcategoría, que el applier resuelve por `shortcutID`
  (`EntityApplyMap.findAccount/findSubcategory(byShortcutID:)`), y sobrevivió la categoría, que resuelve por `syncID`.
  En nuestro código, lo único que escribe las relaciones de UN movimiento es ese applier, y solo la fila de la época
  queda por encima del cursor. Si el `account_ref` del eco no casa con el `shortcutID` local, la relación queda en
  `nil` con un dangler que nadie vuelve a resolver tras la reversa (en `.icloud` no hay pull).
- **No encontré quién cambie esos `shortcutID` en la ventana:** `repairCollapsedIdentityUUIDs` (el único que regenera
  justo cuenta, subcategoría y etiqueta, nunca categoría) aborta en `.cloud` con la migración en curso; la regeneración
  del arranque es one-shot con centinela; la restauración del relevo y el linaje no tocan cuentas ni subcategorías.
- **Fuera del alcance del test**, y por tanto sospechosos que quedan: (1) el espejo de CloudKit al remontar (export del
  movimiento sin CKRecord e import de la zona); (2) el bucle del runtime que sigue corriendo en las fases previas al
  montaje (`performCycle` no re-mira `canRunDomain`), aunque aplica las mismas filas con los mismos resolvers; (3) un
  duplicado de cuenta o subcategoría que llegue tras el montaje y lo fusionen `healDuplicates` o el dedup del arranque:
  re-apuntan por la inversa y borran al perdedor con `.nullify`. Esto último invalida una de las exclusiones de arriba:
  un merge hacia un ganador con el mismo nombre dejaría las 2.311 transacciones «intactas» en pantalla.
- **Baja de `high` a `medium`**: no se reproduce en ninguna variante del camino de la reversa que vive en el repo, y
  queda la guardia. Vuelve a `very-high` si el device-QA lo reproduce.

## Device-QA (iPhone de pruebas, ~45 min, la mayor parte esperando)

Montaje:
1. Un iPhone de pruebas con sesión de iCloud, por cable al Mac.
2. Xcode: scheme **Yala Dev** (va a STAGING), compilado desde `2.1` con este PR, Run al iPhone.
3. En el Mac, abre **Consola**, elige el iPhone en la barra lateral, pulsa «Iniciar» y escribe `danglingRef` en el
   buscador. Déjala abierta todo el rato.

Reversa rápida (el caso original):
1. Ajustes › Dónde viven tus datos › **Migrar a la nube**, con la cuenta de pruebas. Espera a «Nube activa».
2. Crea dos movimientos de gasto, cada uno con **cuenta** y **subcategoría**: «QA rápida 1» y «QA rápida 2».
3. Antes de 5 minutos: Dónde viven tus datos › **Volver a iCloud**. Cuando lo pida, cierra y abre Yala; espera a que
   termine.
4. Registros: los dos aparecen bajo su cuenta. Ábrelos: cuenta y subcategoría siguen puestas.
5. Cierra Yala del todo (deslizar en el selector de apps) y ábrela: lo mismo.
6. Mira la Consola: ¿alguna línea `CloudSyncApply danglingRef tx_items.account_ref` o `…subcategory_ref`? Anota sí o no.

Espera larga:
7. Migra otra vez a la nube, crea «QA lenta» con cuenta y subcategoría y deja Yala abierta 30 minutos.
8. Volver a iCloud y repite los pasos 4 a 6 con «QA lenta».

Si algún movimiento pierde la cuenta o la subcategoría: anota cuál, si la Consola mostró `danglingRef` y si en
Ajustes › Cuentas aparece la cuenta duplicada. Con `danglingRef` es el applier; sin él y sin duplicado, es el espejo.
