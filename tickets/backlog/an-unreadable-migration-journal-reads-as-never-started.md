---
id: an-unreadable-migration-journal-reads-as-never-started
status: backlog
priority: very-high
area: "modo-nube, migración"
created: 2026-09-22
updated: 2026-09-22
source: "barrido del patrón durante `verify-reads-a-failed-local-fetch-as-an-empty-outbox` (2026-09-22)"
---

# Si el registro de la migración no se deja leer, la app dice que nunca empezó — y borra el motivo por el que paró

## El problema, en lenguaje de usuario

La app guarda en qué punto va el paso de tus datos a la nube (o la vuelta a iCloud), y también por qué se paró
si se paró. Si esa anotación no se deja leer, la pantalla de Almacenamiento no dice «no he podido comprobarlo»:
dice que **la migración nunca empezó**. Y de paso **borra el motivo del aborto**, que es justo lo que la persona
necesitaba para saber qué hacer.

## Por qué pasa (medido el 2026-09-22 en este árbol)

Dos sitios, y el segundo es el que convierte un problema de lectura en un problema de ESTADO:

1. `CloudMigrationController.readJournalSnapshot:1229` — el `catch` devuelve `(.notStarted, 0)` **y además limpia
   `cutoverBlocker`, `reverseAbortReason` y `hasPendingReverseExit`**. O sea que una lectura fallida no solo miente:
   destruye la nota que explicaba la parada.
2. `MigrationPhaseStore.journaledPhase:119` — el `catch` devuelve `.notStarted`.

Y `notStarted` **es fase ESTABLE** (`MigrationRuntimeGate`): es la fase de un dispositivo ADOPTADO, la que deja
pasar el gate del par `.cloud` + `mirrorOffArmed`. Leer una fase ilegible como estable es exactamente lo que ese
gate existe para impedir — el invariante está escrito en `.claude/rules/swiftdata-cloudkit.md`, sección «El par
que apaga el mirror».

Tres vecinos de la misma pantalla, con el mismo patrón y `try?` en vez de `catch`:

| Sitio | Devuelve | Consecuencia |
|---|---|---|
| `CloudMigrationController.refreshSyncBanner:1166` | `0` | `syncNeedsSignIn = false`: el aviso «tienes N sin subir» no sale |
| `CloudMigrationController.reverseEligibility:1244` | `hasCKMap = false` | el dispositivo sale NO elegible para la vuelta a iCloud |
| `CloudMigrationController.dryRunCounts:1269` | `0` por entidad | «Ver qué migraría» dice **cero** |

## Qué habría que decidir antes de hacerlo

1. **¿Cuál es el `notStarted` honesto?** No hay hoy una fase «no lo sé». Puede hacer falta un estado nuevo, o que
   la pantalla lo pinte como un error en vez de como una fase.
2. **La limpieza de `cutoverBlocker`/`reverseAbortReason` es una escritura, no una lectura.** Es probable que la
   respuesta más barata y más segura sea sacarla del `catch`, sin tocar el resto.
3. Los tres del `try?` son de la superficie de la pantalla y su default seguro puede no ser el mismo que el del
   journal; conviene decidirlos uno a uno.

## Criterios de aceptación

- [ ] Una lectura fallida del journal NO se presenta como `notStarted`.
- [ ] Y no borra el motivo del aborto.
- [ ] La pantalla de Almacenamiento dice algo honesto en ese caso.
- [ ] Test con la lectura lanzando + control positivo.

## Relacionado

- `verify-reads-a-failed-local-fetch-as-an-empty-outbox` — el mismo patrón sobre el fetch de `SyncOutbox`, cerrado.
