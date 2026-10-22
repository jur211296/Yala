---
name: dos-corridas-un-simulador
description: Antes de creerme un rojo de XCUITest, vigilar la corrida ENTERA (no solo la foto de antes) — y saber que un rojo CON línea de fallo tampoco es veredicto si otra corrida instaló su app encima
metadata:
  type: feedback
---

**Un rojo de XCUITest no se interpreta hasta saber (a) si había otra corrida encima y (b) si el caso
imprimió su línea de fallo.** Las dos son un comando y ninguna de las dos la hacía yo.

**Why:** el 2026-09-07 un ticket `high` llevaba días diciendo que «el runner muere tras el primer
caso de cada suite» y señalaba la memoria como causa principal, con el disco ya descartado a 14 GB.
Las dos hipótesis eran falsas y las dos se descartaron midiendo: el swap estuvo **lleno** durante 12
corridas de control que dieron 124 casos sin un fallo, y bajar el disco a **12 GB** a propósito (con
un fichero de relleno, reversible) tampoco reprodujo nada. La causa era que **dos `xcodebuild test`
sobre el mismo simulador se derriban entre sí**: comparten bundle id, la segunda mata al runner de la
primera. Reproducido 2/2 lanzando dos corridas con 25 s de diferencia, y con el control en la
dirección contraria — la corrida solitaria inmediatamente posterior vuelve a 11/11 verde, o sea que
no es desgaste del simulador.

En esta máquina hay **un solo simulador** y conviven ~10 worktrees, todos con el mismo
`-destination name=iPhone 17 Pro`. La colisión no es rara: es lo normal cuando dos sesiones llegan al
gate a la vez. Eso explica lo que cuatro tickets distintos no cuadraban — **por qué fallaba en TANDA
y pasaba AISLADO**: una tanda son ~3 min de ventana para que otra sesión entre; un test suelto, 30 s.

**How to apply:**

- **Antes del paso 3 del gate: `bash qa/scripts/sim-libre.sh`.** Lo escribí ese día y el gate ya lo
  invoca. Si sale 1, esperar — correr igual no da veredicto, da ruido que parece tuyo.
- **Clasificar el rojo antes de mirar ningún test**, con `grep -c "Test Case .* failed"`:
  - **0** con un bloque `Failing tests` ⇒ murió el runner. No hay veredicto. No archives esos nombres:
    dependen del orden, no de qué esté roto.
  - **>0** con su mensaje de aserto ⇒ eso sí es un rojo de test… **pero solo si estuviste solo**, y
    esa mitad me faltaba (ver abajo).
- **`bash qa/scripts/sim-libre.sh --vigilar <pid del xcodebuild>` DURANTE la corrida**, no solo la
  foto de antes. Lo escribí el 11-sep, con sus cuatro controles; el gate ya lo lanza en paralelo.
- **Los `JetsamEvent` contestan «¿fue la memoria?» en un minuto y suelen decir que no.** Viven en
  `/Library/Logs/DiagnosticReports` (los del sistema; los de `~/Library` no traen jetsam) y se leen
  sin `sudo` porque `jur` está en `_analyticsusers`. Filtrar por `reason`: casi todo es `idle-exit`,
  que es ruido normal. Aquí ni `xcodebuild`, ni el runner, ni la app aparecieron **nunca** con
  `reason` en los 8 eventos desde el 1-sep — y el día del ticket **no había ni uno**. Ojo: los
  `jettisoned` / `vm-compressor-space-shortage` que sí aparecen matan daemons de **iOS**
  (`CommCenter`, `UIKitSystem`, `homed`), o sea que son jetsam **dentro** del simulador, no de macOS.
- **Para separar disco de memoria, la variable barata y reversible es el disco**: `dd` un fichero de
  relleno hasta el objetivo, correr, y borrarlo con un `trap ... EXIT`. `mkfile -n` **no sirve**: crea
  un fichero sparse y en APFS no baja el espacio libre. Inducir presión de **memoria** global, en
  cambio, no lo hago: con 14 sesiones vivas eso mata trabajo ajeno.

Relacionado: [[el-arbol-base-contesta-si-es-mio]] · [[rojo-conocido-no-exime-de-bisecar]] ·
[[bisect-de-un-flaky-miente]] · [[la-premisa-del-encargo-tambien-se-mide]]


## La mitad que faltaba, y costó un ticket `high` falso (2026-09-11)

**«Tiene línea de fallo» NO prueba que el rojo sea tuyo.** La segunda corrida, antes de matar al
runner de la primera, **instala su `.app` sobre el mismo bundle id**. Desde ese instante la primera
sigue viva y tapeando **un binario que no es el suyo** — el del árbol de la otra sesión, con su
trabajo a medias dentro. Lo que sale entonces no es `Restarting after unexpected exit` sin
veredicto: es un `waitForExistence` que se agota, con su `Test Case … failed` y su mensaje de
aserto. Indistinguible de una regresión.

Así nació `welcome-chooser-uitests-cannot-reach-the-chooser`, `high`, con siete casos, su log y una
«bisección». Los siete pasan (11/11 local en las dos revisiones, y verdes en la nocturna de CI sobre
149 casos). Una sesión entera para refutarlo.

**How to apply:**

- El criterio de clasificación de arriba distingue «murió el runner» de «falló una aserción». **No**
  distingue «falló una aserción **de mi árbol**» de «falló contra el binario de otro». Para eso hace
  falta saber si estuviste solo, y eso solo lo sabe un centinela: la foto previa caduca al segundo
  siguiente y una corrida dura entre 3 y 40 minutos.
- **Antes de abrir un ticket por un rojo de XCUITest**, una corrida aislada con el centinela en
  verde. Un ticket `high` en el board cuesta mucho más que repetir una corrida.
- Y busca la **medición independiente que ya está pagada**: la nocturna de CI corre la suite completa
  en una máquina limpia. `gh run list --workflow qa.yml --event schedule` y `gh run view <id> --log`
  contestan en dos minutos si el rojo existe fuera de esta Mac.

Relacionado: [[la-premisa-del-encargo-tambien-se-mide]] · [[xcuitest-completo-por-lotes]]
