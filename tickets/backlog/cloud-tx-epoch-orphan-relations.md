---
id: cloud-tx-epoch-orphan-relations
status: backlog
created: 2026-07-17
updated: 2026-08-26
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
