# CI: el runner de GitHub no puede crear el simulador iPhone 17 Pro en iOS 27.1 y bloquea todos los merges a 2.2

## Contexto
Card del tablero: `tablero-ci-el-runner-no-puede-crear-el-simulador-x8fd` (Yala, 2.2, asignada a frank).
Desde anoche el job `tests` de `.github/workflows/qa.yml` falla en el paso «Simulador del runner» (`qa/scripts/ci-simulador.sh`) antes de correr un solo test. Ejemplo: PR #602, run 39930117496, job 120336051949 (2026-10-23 04:12 Lima). El log dice «SDK de simulador: 27.1» y luego 8 veces `simctl create` falla con `com.apple.CoreSimulator.SimError, code=403` para iPhone 17 Pro en `com.apple.CoreSimulator.SimRuntime.iOS-27-1`, aunque CoreSimulator lista el runtime iOS 27.1 (24A94425). Hay runtime iOS 27.0 disponible también.
Hay cuatro PR a 2.2 en cola de auto-merge que no entran por esto: #602, #601, #576 y #571. La rama 2.2 compila con Xcode 27.1 desde el PR #555.
Hunch sin verificar: el device type iPhone 17 Pro puede no estar soportado por ese runtime beta en la imagen del runner, o el runtime 27.1 viene incompleto. Verifícalo con el log y con lo que expone la imagen (`simctl list devicetypes`, `simctl list runtimes -j`), no lo des por hecho.

## Qué se pide
1. Encontrar la causa real del 403 y arreglar el CI para que el job `tests` vuelva a tener simulador y corra la suite, de la forma más robusta (por ejemplo, caer a un device type o runtime compatible que la imagen sí soporte, o fijar la imagen/Xcode), sin bajar la cobertura ni apagar tests.
2. Que el banco `qa/scripts/ci-simulador-test.sh` cubra el caso nuevo.
3. PR a 2.2 con auto-merge. Cuando entre, relanzar los checks fallidos de los PR #602, #601, #576 y #571 (`gh run rerun --failed`) para que su auto-merge siga. Si alguno falla por otra razón, anotarlo en el cierre, no arreglarlo aquí.
4. Card x8fd: a done si el CI queda verde; si no, dejar la causa en la nota.

## Qué NO hay que tocar
- No tocar código de la app ni los PR de otros (solo relanzar sus checks).
- No desactivar el job `tests`, no marcarlo como no requerido, no saltarse protecciones de rama.
- La card `tablero-el-script-de-reintentos-del-ci-trata-el-2bab` es otra sesión; no la mezcles salvo que el arreglo la toque de lleno, y entonces dilo.

## Cómo se sabe que está bien
El job `tests` del PR de esta sesión crea el simulador y corre la suite en GitHub Actions, el PR entra en 2.2, y los checks de los cuatro PR en cola se relanzaron.

## Mini
Pipeline serial de Yala: si necesitas simulador local, uno solo, build sin sim booteado (`xcodebuild -jobs 2`), y al cerrar apagar y borrar el sim. Al lanzar y al cerrar, borrar sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No tocar los de la sesión viva «pendientes-de-jurgen-2-2». La Mini tiene ~22 GB libres.

/cerrar-total

## Paso 0 (Frank, 2026-10-23)

**Causa medida.** La imagen `xcode-27-arm64` 20261022.0305 (la del run 39930117496) trae dos
runtimes iOS: 27.0 (24A434) con los iPhone 17/18 y un 27.1 (24A94425) cuyo único simulador es el
**iPhone Duo** (README de la imagen, tabla «Installed Simulators»). `ci-simulador.sh` prefería el
runtime que casa con el SDK (27.1) y `simctl create` contestaba `403 · Incompatible device`. No es
un runtime roto: no admite el modelo. Hasta la imagen anterior solo había 27.0 y por eso funcionaba.

Decisiones, auto-contestadas:
1. **Arreglo en el script, no en la imagen.** GitHub no deja fijar la versión de una imagen
   hospedada; fijar Xcode no cambia los runtimes que trae. Se filtran los runtimes por
   `supportedDeviceTypes` (la clave existe: medida en la Mini con el simctl de Xcode 27.1).
2. **Segunda defensa:** si aun así `create` contesta «Incompatible device», ese runtime se excluye
   y se prueba el siguiente. Cualquier otro fallo de `create` se reintenta en el mismo, como antes.
3. **Se mantiene iPhone 17 Pro en iOS 27.0**, lo que el CI usaba hasta ayer. No se cambia a iPhone
   Duo: sería otro simulador, otra cobertura y una decisión de producto.
4. **`ci-sombra.yml`** repetía el mismo patrón («el runtime iOS más nuevo»): mismo filtro. Es CI de
   la Mini, solo `workflow_dispatch`; se dice en el PR.
5. La card `2bab` (reintentos) no se toca: este arreglo no pasa por `ci-reintentar-rojos.sh`.
