---
id: adopt-window-uploads-what-reaches-the-mirror-after-the-icloud-check
status: backlog
priority: medium
area: "modo-nube, migración"
created: 2026-09-25
updated: 2026-09-25
source: "residual y review adversarial (lente de bypass) de `adopt-on-an-empty-store-uploads-what-the-mirror-imports-before-the-relaunch`, 2026-09-25"
---

# Lo que llega al espejo después de que el adopt le preguntó a iCloud sube a la cuenta sin prueba de linaje

## El problema, en lenguaje de usuario

Activo la nube en este iPhone con una cuenta que ya existe. Mi iCloud no tiene finanzas de Yala (o no tengo iCloud), así que
entra sin pedir nada. Antes de cerrar y volver a abrir la app pasa una de dos cosas:

1. Mi iPad —mismo Apple ID, todavía en iCloud— apunta un gasto.
2. Inicio sesión en iCloud en este iPhone, con mi Apple ID o con otro que ya tenía años de finanzas en Yala.

El iPhone recibe eso por iCloud y, al reabrir, lo sube a la cuenta en la nube.

## Lo medido (2026-09-25, en el código)

- El ticket padre hace que el adopt con el espejo adjunto y sin nada local que pida linaje le pregunte a CloudKit. Si ese
  iCloud tiene filas, espera a que el primer import termine y decide la guarda de linaje; con `none` o `noAccount`, entra.
- Entre esa respuesta y el relanzamiento el espejo sigue adjunto (la tarjeta de Almacenamiento no fuerza nada, y puede
  durar días) y el drain traduce todo lo que no escribió el motor, imports incluidos (`CloudSyncEngine.swift`, filtro por
  autor del drain). Lo que el espejo baje en la ventana sube en el primer drain, sin prueba de linaje.
- `noAccount` sale del `CKError.notAuthenticated` de ese instante. Con `.localNoMirror` el espejo está adjunto aunque no haya
  cuenta (`attachesCloudKitMirror`), y nada re-pregunta si la cuenta aparece después.
- Inferido, sin medir: que `NSPersistentCloudKitContainer` empiece a importar en el mismo proceso cuando aparece la cuenta.
- No se puede contar en la flota: el canario `cloudAdoptICloudCorpusChecked` cuenta respuestas, no lo que llega después.

## Por qué medium

El caso 1 es poco probable y el dato es del mismo dueño del Apple ID. El caso 2 puede traer el corpus entero de otro Apple
ID, y la ventana dura lo que la persona tarde en reabrir.

## Opciones, sin decidir

- Tras relanzar, antes del primer drain (`CloudSyncRuntime.start`, donde ya corre `restoreAdoptedRelayIdentitiesIfPinned`),
  mirar en el historial los inserts del espejo posteriores al adopt en las tablas que piden linaje. Primero como canario; si
  pasa, decidir qué se hace con ellos. **Es decisión de producto**: la nube ya está armada, el espejo ya no está, y no hay
  salida del adopt con `.cloud` persistido.
- Volver a preguntar a CloudKit justo antes de armar la nube acorta la ventana, pero no la cierra.
- Tratar `noAccount` como «esperar» solo cuando el mount adjunta el espejo deja esperando para siempre al teléfono sin iCloud.

## Relación

- Padre: `adopt-on-an-empty-store-uploads-what-the-mirror-imports-before-the-relaunch`.
- Hermano: `adopt-window-late-imports-overwrite-newer-cloud-edits` (la misma ventana, con filas que el backend sí conoce).
