# Arreglar el paso advisory Unit tests (pure-logic) que sale en rojo en 2.1

## Contexto
En jur211296/Yala el workflow de tests queda en verde porque `Unit tests (pure-logic)` es continue-on-error, pero ese paso está en rojo de forma repetida (PRs #331–#335 y ya en 2.1, HEAD reciente 98759c9 / b281c97). Runs de referencia: 37094436816 y 37095716630. Fallo concreto que viste en el log: en el job tests del run 37094436816 (HEAD 98759c9, último tests COMPLETADO en 2.1) el paso pure-logic hace `xcodebuild test-without-building -only-testing:YalaTests` (saltando las suites context-based) y termina ** TEST EXECUTE FAILED ** / ##[error] exit 65 tras -retry-tests-on-failure (la API marca el step success solo por continue-on-error). Failing tests:
1) PrivateSessionMarkWiringTests.theWipeCopyReadsTheSameAxisAsItsScope() — PrivateSessionMarkTests.swift:337, las 3 iteraciones. El #expect exige que el fuente de la pantalla contenga `PrivateSessionMark.hasPrivateSession()` + `L10n.Settings.resetDataDescription` y no lo contiene. Mensaje: «la descripción de la pantalla volvió a leer otra cosa mientras el alcance lee la marca. Divergen justo en el caso del eje: una sesión solo-grupos leía «solo tu perfil y tus preferencias» sobre un `.wipeDataFull`.»
2) SpikeR3ContainerReleaseTests.eje1y2_releaseVerificadoYRemount() — SpikeR3ContainerReleaseTests.swift:48 y :53 (xcodebuild lo lista dos veces). Línea 48: el log contiene «CONTROL ROTO: cero descriptores con la conexión abierta» y el test exige que NO. Línea 53: el log NO contiene «EJE 1 · CONEXIÓN CERRADA». Mensajes: «con un ModelContext retenido el container murió ⇒ el sentinel no discrimina» y «el objeto murió pero quedaron descriptores abiertos ⇒ el release deja de ser verificable». El propio log dice que el container murió en 0 ms y que el instrumento de fds midió 0 descriptores incluso con la conexión viva.

Al lanzar, origin/2.1 era b281c97 (merge de #335). El QA de ese push (run 37097761931) seguía in_progress en el mismo paso pure-logic; no había un tests más nuevo ya terminado en verde.

La sesión arranca en contexto limpio. Base: origin/2.1 (el comando ya hace fetch; no partas del checkout local de Jürgen).

Pipeline serial obligatorio en la Mini (16 GB, disco apretado): (1) limpiar sims muertos (2) xcodebuild -jobs 2 SIN simulador booteado (3) boot de 1 simulador (4) tests (5) apagar y borrar data de ese simulador. Prohibido solapar swift-frontend + SpringBoard + app + UITests. Un solo simulador. limpiar-mac umbral 32 GB.

Al terminar: /cerrar-total autónomo. Dejar la Mini limpia: apagar el sim, erase/limpiar data del device, y si el PR quedó mergeado quitar el worktree. Si creas alguna key en el Llavero, no la dejes solo ahí: anótalo en el cierre para que Frank la pase a 1Password (vault Yala; nunca keys de firma en Shared with Grok Bot).

## Que se pide
Dejar verde el paso `Unit tests (pure-logic)` en el CI de la rama del PR, sin cambiar comportamiento de producto para tapar un test que tenga razón. Si el test está mal, corrígelo. Si el código está mal, corrige el código. Alcance: solo ese rojo. No rediseñes UI, no toques Cola B, no metas otros tickets.

## Que NO hay que tocar
Marketing, otros tickets de Cola B, el árbol de trabajo de Jürgen, merges a mano si el repo ya tiene auto-merge. No abras un segundo simulador. No desactives el paso ni lo marques continue-on-error para esconder el rojo (ya lo es).

## Como se sabe que esta bien
El paso `Unit tests (pure-logic)` pasa en CI en el PR (no solo en local). PR hacia 2.1. Cierre limpio con /cerrar-total.

## Paso 0

Decisiones (auto-contestadas, MODO AUTÓNOMO):

1. **`theWipeCopyReadsTheSameAxisAsItsScope` — el test está mal, no el código.** La pantalla sigue
   leyendo `PrivateSessionMark.hasPrivateSession() ? L10n.Settings.resetDataDescription`
   (`UserDataResetView.swift:91-92`). El refactor `2c9f800d2` (Vaciar datos en lista agrupada)
   bajó la sangría de 40 a 28 espacios y el `contains` llevaba la sangría dentro del literal.
   ⇒ La aserción compara con los espacios colapsados. El mutante que importa (otra lectura del eje)
   sigue muriendo.
2. **`eje1y2_releaseVerificadoYRemount` — el instrumento está mal, no la plataforma.** El contador de
   descriptores barre solo 0..<1024. El CI repite la suite 3 veces en el MISMO proceso (25 872
   tests) y en la 3.ª pasada el proceso ya pasa de 1024 descriptores (en la 2.ª ya se ve el fd 805):
   los del store caen fuera del barrido y el control positivo lee 0 con la conexión viva. Pasa en
   las pasadas 1 y 2 de los dos runs (37094436816, 37095716630) y cae en la 3.ª de ambos.
   ⇒ El techo del barrido pasa a ser el límite real del proceso (`RLIMIT_NOFILE`, acotado por
   `kern.maxfilesperproc`), con un test que ocupa el tramo bajo y exige que el descriptor del store
   se cuente por encima de 1024.
3. **Otras aserciones con sangría en el literal** que hoy pasan: no se tocan (alcance: solo el rojo);
   se cuentan en el PR.
4. Asumido: el fichero de cobertura se actualiza en el área de CloudSync por tocar el harness.
