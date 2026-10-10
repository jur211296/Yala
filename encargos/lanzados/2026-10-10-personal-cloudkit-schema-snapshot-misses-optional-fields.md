---
esfuerzo: medium
---
# El esquema de iCloud del repo no tiene campos opcionales que la app escribe: diff y guía para la consola de CloudKit

**Card:** tablero-el-esquema-de-icloud-del-repo-no-tiene-c-o2li · **Prioridad:** high

Ticket: `tickets/backlog/personal-cloudkit-schema-snapshot-misses-optional-fields.md`. Bloqueante potencial del envío de 2.1: si iCloud de Production no conoce un campo que 2.1 escribe, ese registro no sincroniza y nadie se entera.

## Que se pide (sin desplegar nada: el deploy del esquema lo hace Jürgen)
1. Sacar del código de origin/2.1 el esquema ESPERADO del contenedor personal: todos los `@Model` que espeja SwiftData/CloudKit (`CD_<Entidad>` y `CD_<campo>`, tipos, opcionales, relaciones, índices que hagan falta).
2. Compararlo con el snapshot del repo y producir `docs/cloudkit-schema-diff-2.1.md`: tabla por record type de campos que faltan, sobran o cambian de tipo, con el commit que introdujo cada campo y la versión de app que lo escribe.
3. Guía paso a paso para Jürgen en el mismo doc: cómo exportar el esquema de Development y de Production desde la consola de CloudKit (o `cktool export-schema`), cómo compararlo con el diff, y cómo hacer «Deploy Schema Changes to Production» con seguridad (solo añadir; nunca borrar campos ni record types; qué pasa con versiones viejas de la app).
4. Actualizar el snapshot del repo para que sea fiel, y un test (o script en `qa/`) que falle si un `@Model` añade un campo que el snapshot no tiene.
5. Cierre: dejar claro en el aviso si el diff muestra campos que Production NO tiene (bloqueante para enviar 2.1) o si solo era el snapshot.

## Reglas de siempre
- Arranca sobre `origin/2.1` y trabaja sin esperar a nadie. Justo antes de abrir el PR: `git fetch` y rebase sobre `origin/2.1`, resolviendo ahí los conflictos (strict=false); si el rebase toca lo tuyo, recompila y repite los tests afectados con un solo simulador.
- Tickets nuevos al tablero (antes del `/cerrar-total`): por cada ticket nuevo en `tickets/`, mira con `tablero listar --proyecto Yala --todas` que no tenga card y, si no, `tablero crear --proyecto Yala --agente frank --asignado frank --estado backlog --prioridad <la del ticket> --titulo "<título claro en español neutro>" --contexto "<una línea>" --enlace "Ticket|https://github.com/jur211296/Yala/blob/2.1/tickets/backlog/<slug>.md" --enlace "PR #<N>|<url>"`. SIN --fecha (opcional desde el ADR-068; sin fecha de relleno). Lista esas cards en el aviso de cierre.
- Sin deploy, sin secretos y sin decisiones de UI de Jürgen: si algo lo pide, para y anótalo en el cierre.
- Cierre: `/cerrar-total` autónomo (PR a 2.1 en auto-merge, limpieza de simulador, worktree y DerivedData).

## Carga de la Mini (OBLIGATORIO)
- Todo xcodebuild va con `nice -n 10 xcodebuild -jobs 2 ...`.
- Nunca dos builds o tests a la vez (ni build + tests); pipeline serie: build → 1 simulador → tests → erase.
- Antes de cada build espera a que la carga baje de 8: `while [ $(sysctl -n vm.loadavg | awk '{print int($2)}') -ge 8 ]; do sleep 30; done`.
- Nunca pases xcodebuild por `| head` (mata el build): escribe a un log y lee el log.
- Los `-only-testing:` van en un array de zsh, no en un string.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

Hechos medidos antes de decidir: no hay token de `cktool` en la Mini (`cktool get-teams` → «No management token found»), así que el esquema VIVO de Production no se puede leer desde esta sesión. `CloudKitGroupsSchemaParityTests`, el molde que cita el ticket, ya no existe en el árbol. El script del ticket da falsos positivos (variables locales `var result`, `var dates`, `var components`) y se salta las relaciones a-uno.

**D1 · ¿De dónde sale el esquema esperado?** → Del `NSManagedObjectModel` que SwiftData genera para los 17 tipos personales (`makeManagedObjectModel(for:)`), traducido al tipo de campo que crea el mirroring.
Por qué: es el modelo que lee `NSPersistentCloudKitContainer`; un regex sobre el fuente se equivoca de tipos y de relaciones. Alternativa descartada: el script del ticket (falsos positivos medidos).

**D2 · ¿Qué es «snapshot fiel» si no puedo exportar Production?** → Los `.ckdb` de `yala`/`yala_dev` pasan a ser el esquema que Production DEBE tener: lo exportado más los campos que faltan, sin índices. El doc dice en grande que no es un export hasta que Jürgen re-exporte tras el deploy.
Por qué: el test necesita una fuente que el repo controle, y ese fichero sirve además para `cktool import-schema` a Development. Alternativa descartada: un fichero `expected` aparte — dos superficies que divergen.

**D3 · ¿Test o script?** → Test Swift Testing en `YalaTests/CloudSync/PersonalCloudKitSchemaParityTests.swift`, sobre los cuatro `.ckdb` personales; exige que cada campo que la app escribe exista con su tipo, y tolera campos de más.
Por qué: corre en el gate y en CI sin que nadie se acuerde. Campos de más se toleran porque CloudKit no deja borrarlos de Production.

**D4 · Tipos que no casan en el snapshot (p. ej. `CD_CashFlowOverride.CD_line` REFERENCE vs STRING)** → Se reportan en el doc como hallazgo y NO se reescriben a mano; el test los marca.
Por qué: un tipo no se puede cambiar en Production; si el export real dice REFERENCE es un bug de sync, no de snapshot, y eso lo decide el export de Jürgen. *(Se revisa tras medir.)*

**D5 · Grupos** → Fuera: los `Split*` viven en el contenedor `.groups` con CKSyncEngine; sus `CD_Split*` en `yala-production.ckdb` son restos que se toleran como «campos de más».
