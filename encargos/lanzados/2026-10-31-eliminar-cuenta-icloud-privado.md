---
esfuerzo: high
release: no
---
# «Eliminar cuenta» con iCloud privado guarda de forma durable que el servidor ya se borró

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`.
Slug: `eliminar-cuenta-icloud-privado` · Sesión cola **S32** · al cerrar → **S33** (`estadisticas-avisos-y-retoques`).

## Contexto
Residual de la review adversarial de la sesión vaciar-datos-mantiene-cuenta (PR #688): al eliminar la cuenta con iCloud privado no queda guardado que el borrado del servidor ya ocurrió, así que si la app se cierra a mitad el intento no es durable. Ticket: `tickets/backlog/account-deletion-private-close-has-no-durable-intent.md`.

Cards:
- `tablero ver tablero-eliminar-cuenta-con-icloud-privado-no-gu-5mi2`

## Qué se pide
1. Lee el ticket y el flujo de Eliminar cuenta tras #688.
2. Guarda un intento durable (p. ej. marca persistida) antes/después del borrado del servidor, y al reabrir la app se retoma o se completa el cierre local sin volver a pedir nada ni dejar datos a medias.
3. Tests del caso «se cierra la app a mitad» con iCloud privado. Ticket a hecho.
Al abrir el PR, cards a «in qa» de Jürgen si hay algo que mirar en dispositivo, o a «done» si no (con `--agente` de la sesión).

Haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR.

Pipeline serial de la Mini: limpiar, build con `xcodebuild -jobs 2` sin sim booteado, boot de 1 sim, tests, apagar y borrar el sim. Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No toques las de un worktree vivo.

## Qué NO hay que tocar
Vaciar datos (ya correcto en #688). No borres datos reales de ninguna cuenta de iCloud; solo simulador y tests. No lances otras sesiones Yala; ningún otro PR ni rama.

## Cómo se sabe que está bien
Lo de «Qué se pide» hecho, tests verdes, review adversarial del diff, PR a 2.2 con auto-merge y capturas antes/después en `capturas/` si el cambio se ve.

## Cierre autónomo
Ante una decisión abierta, toma la opción conservadora (la más reversible y de menor alcance), documéntala en la card y en el PR, y sigue. Lo que de verdad necesite a Jürgen (borrar datos de usuario, seguridad, diseño crítico): no lo hagas; crea una card `cierra-sola` asignada a jurgen con la decisión pendiente, termina el resto y cierra.
Al cerrar, Frank publica digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.

Termina con /cerrar-total.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Qué es el «intento durable»?** → Una key `cloudSync.accountDeletedAwaitingLocalClose` en `UserDefaults` (`StorageModePersistence`), escrita justo tras el `200` del servidor.
Por qué: es el molde de los arms de este repo (`armSignOutWipe`, `armICloudCorpusWipe`) y `cloudSync.*` no lo barre ningún borrado de preferencias. Alternativa descartada: fila en SwiftData (el cierre borra filas y el boot-wipe los archivos: moriría con lo que describe).

**D2 · ¿Qué celdas la escriben?** → Solo la D (iCloud privado con sesión privada, `!cloud && hasPrivateSession`).
Por qué: es lo que pide el encargo y la única con un cierre que puede fallar (quiescencia) y una zona de iCloud que el espejo repuebla. Alternativa descartada: E y F también (tienen la misma ventana durante las revocaciones, pero su cierre no falla y retomarlo en la nube pide otra prueba); quedan como ticket en backlog.

**D3 · ¿Quién la consume?** → El arranque (tras el bootstrap) y cada vuelta a primer plano, por `AccountDeletionService.resumePendingPrivateClose`, que entra por `deleteAccount` y va directo al cierre local: sin servidor, sin diálogo.
Por qué: sin sesión la fila de «Eliminar mi cuenta» ya no existe, así que esperar a la fila dejaría el teléfono a medias. Alternativa descartada: enseñar la fila sin sesión (cambio de UI no pedido).

**D4 · ¿El cierre retomado decide la celda en vivo o por la marca?** → Por la marca: con ella puesta, siempre el cierre de la D.
Por qué: tras relanzar, la sesión puede haber muerto y algo podría tocar el eje; la marca es lo que se decidió con la cuenta viva. Alternativa descartada: releer `hasPrivateSession` (podría mandar a la D por el cierre de la nube).

**D5 · ¿Quién la retira?** → El servicio cuando el cierre arma el borrado, y el boot-wipe (`performSignOutWipeIfArmed`) tras borrar los archivos. Si el boot-wipe aborta en `.icloud` (desarma), la marca se queda y el cierre se retoma.
Por qué: un kill entre el arm y el retiro dejaría la marca viva sobre un teléfono ya en el Welcome. Alternativa descartada: retirarla antes del arm (un kill entre medias vuelve al bug).

**D6 · Si el cierre retomado vuelve a fallar (quiescencia)** → `.failed(.localClose)` como hoy, la marca se queda y se reintenta en la siguiente vuelta a primer plano o arranque. Sin copy nuevo.
Por qué: menor alcance; el mismo desenlace que el reintento en memoria. 

**D7 · Tests** → Unit del servicio con dos instancias sobre la misma marca (la segunda es el relanzamiento), unit del boot-wipe (retira / conserva en el abort), source-scan del cableado del arranque, y un XCUITest con un seam DEBUG (`-uitest-account-deletion-pending-close`) que siembra la marca y comprueba que la app termina el cierre sola.
Por qué: el caso «se cierra a mitad» no se puede provocar matando la app en un test; la marca sembrada reproduce el estado exacto del relanzamiento. El seam se limpia con `-uitest-reset`.
