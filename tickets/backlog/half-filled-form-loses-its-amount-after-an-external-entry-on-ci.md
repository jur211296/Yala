---
id: half-filled-form-loses-its-amount-after-an-external-entry-on-ci
status: backlog
priority: medium
area: "entradas desde fuera, formulario de registro, testing"
created: 2026-10-29
updated: 2026-10-29
source: "encargo ui-tests-2-2-tres-tandas-rojo (PR #690), dispatch 40939651475 y nocturnas del 23 al 29-oct"
---

# Un «Nuevo registro» a medias vuelve vacío o cerrado al entrar a Yala desde fuera (solo en el runner del CI)

## Qué se ve

`ExternalEntryForeignSheetUITests` deja «Nuevo registro» abierto en Estadísticas con `1234`, manda Yala al fondo y la
trae con un enlace de fuera (voz, foto compartida o enlace al Panel). Lo que el caso protege es que el formulario
sobreviva con lo escrito. En el runner del CI, una a tres veces por noche, no sobrevive:

- **El formulario sigue abierto con «0.00»** (lo más frecuente), o
- **el formulario se ha cerrado** (`XCTWaiterResult 1`: la espera de «no se cierra» se cumplió).

Medido en las nocturnas (`gh run view <run> --log`):

| Noche | Casos rojos |
|---|---|
| 23-oct (39961068142) | `voiceEntry` 1 |
| 25-oct (40196433512) | `panelLink` 1 |
| 27-oct (40521740498) | `voiceEntry` 2 (una vez «0.00», otra cerrado) |
| 28-oct (40712443281) | `voiceEntry` 2, `sharedPhoto` 1, `panelLink` 1 |
| 29-oct, dispatch 40939651475 | `voiceEntry` 3 de 3 (dos veces «0.00», una cerrado) |

## Lo que ya se descartó

- **No es el tecleo.** Desde el PR #690 el test espera a que `1234` esté en el campo antes de pulsar Inicio. En el
  dispatch esa espera pasó y el rojo siguió: el importe estaba escrito y se perdió al volver.
- **No es el test en local.** En el simulador de la Mac (iPhone 17 Pro, iOS 27.0) el caso pasa: 5 corridas seguidas
  del de voz el 29-oct, y la suite entera en el gate del PR.
- **No hay restauración de escena** que pudiera reabrir el formulario vacío: el repo no usa `@SceneStorage` ni
  `stateRestorationActivity`.

## Hipótesis (sin medir)

El runner va justo de memoria y el sistema descarta la escena (o el proceso) de Yala mientras está en segundo plano.
Al volver, la jerarquía se reconstruye y el formulario, que vive en un `@State` de `NewTransactionView` colgado de
`DetailContainerView`, nace de cero. Con el proceso muerto saldría cerrado; queda sin explicar cómo sale **abierto** y
vacío. Si se confirma, en un iPhone con poca memoria pasaría igual: se pierde lo escrito sin aviso.

## Qué hacer

1. Medirlo en el CI, que es donde sale: `NSLog` en `NewTransactionView.init`/`onAppear`, en `sceneDidDisconnect` y en el
   arranque, y leerlo de la consola del `.xcresult` (`xcresulttool export diagnostics`; regla de `swiftui-ds.md` sobre
   rojos que solo salen en el CI). Hace falta subir el `.xcresult` de la tanda como artefacto.
2. Con la causa medida, decidir con Jürgen si un formulario a medias tiene que sobrevivir a que iOS descarte la escena
   (es producto: guardar el borrador o no).

Mientras tanto el test **no se salta**: es la única red que lo ve, y su rojo dice lo que pasa.
