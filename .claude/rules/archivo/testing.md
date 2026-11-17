---
description: ARCHIVO de testing.md — entradas retiradas de la regla viva con su porqué. No se carga sola; se lee cuando una línea de la regla viva o un ítem de la checklist apunta aquí.
paths:
  - ".claude/rules/archivo/**"
---
# Archivo de `testing.md`

> **Qué es.** Entradas que salieron de `.claude/rules/testing.md` en la poda del 2026-11-17 (P5 de la propuesta
> de verificación; el método, en `docs/verificacion/revision-de-escapes.md`). **Nada se borró**: el texto está
> entero, tal como estaba en `origin/2.3` ese día.
>
> **Dos motivos, y solo dos.** *Cubierta*: la lección la comprueba un ítem de `qa/checklist-confiabilidad.yaml`
> en la revisión de cada PR que toque su disparador, y en la regla viva queda una línea con el título y el
> ítem. *No aplica*: describe código que ya no existe (medido con `git grep`, sin contar comentarios); no deja
> línea.
>
> **Para devolver una entrada a la regla viva**, cópiala de aquí, quita su línea de la regla y corrige los
> `regla:` del ítem que la cite. Las secciones `§N` no se renumeran: un `§` es una dirección estable.

## §1 · Y en el fixture tampoco: el «ahora» del test es una fecha fija, no el reloj (card tyzh, 2026-11-01).

> Archivada el 2026-11-17 desde `.claude/rules/testing.md` (líneas 134-141 de `origin/2.3` ese día). **Cubierta por la checklist de confiabilidad**: `ahora-fijo-en-pruebas` (`qa/checklist-confiabilidad.yaml`).

- **Y en el fixture tampoco: el «ahora» del test es una fecha fija, no el reloj (card tyzh, 2026-11-01).** Un helper
  `min(inicio de mes + N, ahora − 1 h)` tumbó 12 casos de `FullFinancialContextBuilderTests` en el CI de las 00:30 del
  día 1: «ahora − 1 h» caía en el mes anterior. Si el código acepta `now:`, la suite lleva un `now` fijo a mitad de mes y
  lo pasa siempre; si lee el reloj por dentro (Registros, presupuestos del Panel), `aMomentAgoToday()` de `TestHelpers`
  («hace 60 s» sin salir de hoy), nunca `Date.now.addingTimeInterval(-N)`. **Se prueba sin tocar el reloj de la Mac**:
  `TEST_RUNNER_TZ=Etc/GMT+<hora UTC>` deja el simulador en las 00:MM del día (el mismo mecanismo con que el CI fija Lima).
  Lo que salga rojo SOLO por la zona —fixtures con calendario de Lima— se separa con un control en Lima y otro a mediodía
  en otra zona: no depende del día (card `orwz`).

## §2 · Un XCUITest no cabe en los 5 s del aviso con «Deshacer» si encadena dos gestos (medido el 2026-10-25, iOS 27.0, lote 12.5)

> Archivada el 2026-11-17 desde `.claude/rules/testing.md` (líneas 187-200 de `origin/2.3` ese día). **Cubierta por la checklist de confiabilidad**: `aviso-deshacer-no-cabe-en-5s` (`qa/checklist-confiabilidad.yaml`).

- **Un XCUITest no cabe en los 5 s del aviso con «Deshacer» si encadena dos gestos (medido el 2026-10-25, iOS 27.0, lote
  12.5).** Borrar un segundo registro por el menú contextual tardó más de 5,4 s: el primero ya se había borrado de verdad
  y el caso de «dos borrados seguidos» salía rojo con el código bueno. ⇒ un caso que dependa de ese plazo lanza con
  `-uitest-undo-notice-seconds 30` (`UITestHooks.undoNoticeSeconds`, solo alarga el aviso y el plazo; no decide nada).
  Molde: `UXAudit22Lote08UITests.test_twoDeletionsInARow_undoBringsBothBack`.
  **En el runner del CI no hace falta encadenar dos gestos (medido el 2026-10-29):** allí cada consulta cuesta 1-3 s, y
  dos esperas seguidas antes de tocar «Deshacer» ya pasan de 5 s. Seis tests caían así cada noche y en local pasaban.
  ⇒ **todo caso que lea o toque el aviso después de otra espera lleva el seam**, no solo el que encadena gestos.
  **Y la carrera al revés:** el aviso vive en su propia ventana y se queda los toques de su cápsula (abajo, encima de la
  barra de pestañas; desde el 2026-10-31 pisa la parte baja del «+», y lo que asoma del «+» sí responde). Lo que quede
  bajo la cápsula no recibe el toque mientras dura: en una máquina rápida el test toca el
  aviso; en el runner lento, el aviso ya se ha ido y pasa. ⇒ antes de tocar algo en esa franja tras un aviso, espera a
  que se retire (`waitForNonExistence` del `noticeIdentifier`). Molde:
  `GroupsLote19DecididoUITests.test_archivedGroup_showsTheBanner_andTheListKeepsItsDebt`.
