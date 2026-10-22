# Implementar ticket: cloud-killswitch-hides-the-only-door-to-detach-groups

## Contexto
Cola autónoma bypass (Jürgen 2026-09-11). Tras #145 (welcome-chooser era medición falsa). Este high: con el kill-switch de la nube bajado, la fila «¿Dónde viven tus datos?» desaparece y quien tiene cuenta de grupos asociada se queda sin puerta para soltarla (Grupos sigue con su propio flag).

## Decisión de producto (Frank, cola autónoma)
Opción **(1)** del ticket: el gate de la fila gana un término — visible también si hay cuenta de grupos asociada (`GroupsAccountAssociation.shared.hasAssociation`). Misma lógica de `isEngaged` («usuario ya dentro conserva su panel»). Es más barata y respeta el escape ante incidente. **No** mudamos la sección a fila propia (opción 2). Déjala escrita en el PR/docs.

MODO AUTÓNOMO HASTA TERMINAR: gate, commit, board, `docs/TICKETS.md`, merge, `/cerrar-total` sin preguntar. Bugs/decisiones nuevas → ticket `--solo-crear`. Ambigüedad NUEVA: lo más seguro alineado con (1) y el ticket; regístralo. Device-QA → `tickets/qa/`.

Avisos a Frank: (1) bloqueo acceso real; (2) PR; (3) `/cerrar-total` resumen producto; (4) idle una vez. No avisar por test/build a reintentar ni CI advisory.

No lances el siguiente: Frank encadena. No marketing/. Paso 12 solo mínimo.

## Que se pide
1. Leer ticket + `StorageRowGateLogic` + sección de asociación.
2. Implementar (1): fila visible con asociación de grupos aunque `remoteEnabled` esté abajo; desasociar sigue alcanzable.
3. Tests del gate (incluye variante absentDefault / fresca si aplica).
4. PR a `2.1`; board/`TICKETS.md`; `/cerrar-total`.

## Que NO hay que tocar
marketing/. Mudar la sección a fila propia (opción 2). Wipe de prod. Paso 12 salvo mínimo.

## Como se sabe que esta bien
Con kill de nube bajado + asociación presente, la fila se ve y se puede desasociar; sin asociación el kill sigue ocultando la fila personal; tests en verde; PR mergeado; `/cerrar-total`.

## Paso 0 — decisiones (resueltas en autónomo, bypass)

Resueltas por Frank el 2026-09-11 sin nadie delante. Cada una se discute en el PR.

**D1 · ¿Opción (1) del ticket o (2)?** → **(1)**, como manda el encargo: el gate de la fila gana un
término. La (2) —mudar Grupos a fila propia— queda descartada y escrita.

**D2 · ¿Qué predicado abre la fila?** → **«hay una cuenta de grupos que esta pantalla pueda soltar»**
(`GroupsAssociationLogic.offersDetach` sobre el estado vivo), **no** el literal
`GroupsAccountAssociation.shared.hasAssociation` que nombra el ticket. Medido: la sección ofrece el
botón «Desasociar» en sesión privada con **sesión viva y sin registro persistido**, celda alcanzable
por el «empiezo de cero» del Welcome (borra el espejo local, sella el dominio y NO cierra la sesión en
la nube) y por cualquier sesión anterior al paso 10 sin backfill. Con el literal del ticket, esa
población seguía sin puerta: el arreglo habría dejado vivo el bug que arregla. Y por el otro lado, el
registro viaja por el iCloud-KV del Apple ID, así que en un dispositivo solo-grupos abría la fila a una
pantalla sin sección. El predicado del ticket es la intención; éste es la intención medida.

**D3 · ¿Abrir la fila abre «Migrar a la nube»?** → **No.** Medido: la card de migrar no tenía ningún
candado propio del kill-switch —ni en la vista ni en `CloudMigrationController`—, así que su cierre
durante un incidente era una CONSECUENCIA de que la fila estuviera oculta. Se escribe explícito
(`StorageRowGateLogic.offersCloudMigrationEntry`) y se re-mide también en la ACCIÓN, no solo en el
render: un flujo empezado antes de que bajara el flag llegaba a `startMigration` igual.

**D4 · ¿Se arregla el hueco de `.needsRelaunch`, el 403 del kill de Grupos y el CTA de asociar sin
gate?** → **No, ticket cada uno.** Los tres son preexistentes, ninguno es regresión de este cambio y
los tres tienen dueño propio. Se crean en `tickets/backlog/`.

**D5 · ¿XCUITest del caso nuevo?** → **No, y la razón cambió a mitad de sesión.** Bajo `-uitest` el flag
sale de `absentDefault`, que depende del scheme: con `"Yala Dev"` (el que corren el gate y el CI) es
`true` ⇒ el kill no se puede bajar ahí. Con el scheme `Yala` sí baja —lo comprobé sin querer al correr
la suite con el scheme equivocado: los 5 casos cayeron con «No aparece la fila»—, pero un test cuyo
veredicto dependa del scheme rompería el CI. El caso positivo necesita además el seam de asociación
sembrada, que ya tiene ticket. Se cubre con unit + source-scan del cableado, y el recorrido real va a
device-QA.
