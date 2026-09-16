---
id: reverse-offered-on-a-device-without-icloud
status: backlog
priority: medium
area: "modo-nube, migración"
created: 2026-09-16
source: "medición de `reverse-upload-has-no-ceiling-and-no-exit` (2026-09-16), decisión D4 de Jürgen: ticket aparte"
---

# «Volver a iCloud» se ofrece en un dispositivo sin iCloud, y esa vuelta no puede terminar nunca

## El problema, en lenguaje de usuario

Tengo mis datos en la nube de Yala y mi iPhone no tiene iCloud activo. En «Dónde viven tus datos» veo
«Volver a iCloud», paso las dos confirmaciones, la app me pide cerrarla y reabrirla, y al volver se queda
subiendo a un iCloud que no existe.

Desde `reverse-upload-has-no-ceiling-and-no-exit` ya no es un callejón: la pantalla dice que el dispositivo
no tiene iCloud activo y ofrece «Cancelar y seguir en la nube», y a las 72 h sin avanzar vuelve sola. Pero
la app me dejó empezar algo que sabía que no podía terminar, y durante la espera la nube de Yala está
congelada.

## Por qué pasa (medido)

- `ReverseEligibility.decide` mira el modo, el mapa CloudKit, la marca born-cloud y la fase. **No mira
  iCloud** (`MigrationWorkExecutor.swift`, `ReverseEligibility`).
- Sin cuenta, el relanzamiento monta `.localNoMirror`, que **adjunta el mirror** (medido 2026-08-10,
  `SwiftDataConfiguration.attachesCloudKitMirror`), así que `isMirrorConfirmedOn()` da `true` y la reversa
  avanza.
- La quiescencia se cumple sin import: `SubcategoryDedupGate.decide` devuelve `.run` sin import previo.
- La reversa llega a `reverseUpload` y el mirror no exporta: su error es `NSCocoaErrorDomain 134400`, que no
  es un `CKError` y no llega a `iCloudSyncService.lastExportError`.
- **Para una cuenta nacida en la nube pasaba otra cosa hasta el 2026-09-16:** el muestreo no veía sus filas (no
  tienen testigo `SyncIdentity`) y la vuelta se daba por hecha al instante, sin iCloud. Desde D15 de
  `reverse-upload-has-no-ceiling-and-no-exit` las cuenta, y espera como las demás. Si el espejo sin cuenta no crea
  sus tablas de metadata, todas salen `failed` y vuelve a «terminar»: `reverse-upload-sample-reads-unreadable-rows-as-drained`.

## Por qué no se cerró en el ticket del techo

La señal disponible, `SwiftDataConfiguration.isICloudAvailable()`, mide el token de **iCloud Drive**, no
CloudKit (`.claude/rules/swiftdata-cloudkit.md`). Ocultar el botón con ella se lo escondería también a quien
tiene Drive apagado y CloudKit sano, que sí puede volver. La ida (C-1) tomó la misma decisión: el token de
Drive nunca bloquea solo.

## Lo que hay que decidir

- **A · Bloquear la entrada con el token de Drive** y una nota («Activa iCloud en Ajustes»). Barata, con el
  falso negativo de arriba. Antes, medir en device qué hace `.localNoMirror` con cuenta y Drive apagado: si
  el mirror `.automatic` sincroniza, el falso negativo es real; si no, no lo es.
- **B · Una señal de CloudKit** (`CKContainer.accountStatus()`, hoy con 0 usos a propósito para no tener dos
  verdades). Más fiel, y es una decisión de arquitectura.
- **C · No tocar**: la salida ya existe y dice la verdad.

## Criterios de aceptación

- [ ] Medido en device: `.localNoMirror` con cuenta y con Drive apagado, ¿exporta?
- [ ] Elegida la vía, con el motivo escrito.
- [ ] Un dispositivo con iCloud sano sigue viendo «Volver a iCloud» (la mitad que no se puede perder).

## Relacionado

- `reverse-upload-has-no-ceiling-and-no-exit` — el techo y la salida de esta misma espera.
- `reverse-hidden-on-a-born-cloud-second-device` — la otra puerta de la misma card.
