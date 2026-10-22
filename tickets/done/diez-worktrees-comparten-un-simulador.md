---
id: diez-worktrees-comparten-un-simulador
status: done
priority: high
area: qa
created: 2026-09-07
updated: 2026-09-12
source: causa raíz de rojo-xcuitest-runner-muere-tras-el-primer-caso
---

# Diez worktrees comparten un solo simulador, y el gate no se serializa

## El hecho

**Subido a `high` el 2026-09-11: ya cobró su primera factura.** El ticket
`welcome-chooser-uitests-cannot-reach-the-chooser` nació `high` diciendo que siete XCUITest del
Welcome estaban rotos en `2.1`, con su bisección y todo. Los siete **pasan**: en `2.1` de hoy
(11/11), en la revisión exacta que se bisecó (11/11) y en la nocturna de CI sobre los 149 casos.
El rojo era de la máquina, no del árbol — y la sesión que lo midió estaba corriendo su propio
gate a la vez. Coste: un ticket `high` falso en el board y una sesión entera para refutarlo.

```
worktrees vivos:                 14   (2026-09-11; eran 10 el 07-sep)
DerivedData de Yala:             13
simuladores booteados:            1   (iPhone 17 Pro 9D0F6D32, iOS 26.5)
```

El paso 3 del `/gate` de **todas** las sesiones apunta al mismo
`-destination 'platform=iOS Simulator,name=iPhone 17 Pro'`. Dos sesiones que lleguen al gate a la
vez corren XCUITest sobre el mismo device y **se derriban entre sí**: comparten bundle id, así que
el runner de la segunda mata al de la primera. Las dos salen exit 65 con casos en `Failing tests`
que nunca imprimieron una línea de fallo. Medido y reproducido 2/2 en
[[rojo-xcuitest-runner-muere-tras-el-primer-caso]].

## Lo que ya se hizo, y por qué no bastaba

`qa/scripts/sim-libre.sh` **detecta** la colisión y el gate la consulta antes del paso 3. Eso evita
el diagnóstico falso —que era lo caro— pero **no resuelve la contención**: la sesión que llega
segunda tiene que esperar a mano, sin saber cuánto, y nada impide que dos arranquen en el mismo
segundo. Con sesiones autónomas nocturnas, que es justo cuando coinciden, no hay nadie mirando.

**Y el 2026-09-11 se le añadió el modo `--vigilar <pid>`**, un centinela que muestrea durante toda
la corrida y dice al final si estuviste solo. Tapa el agujero que dejaba la foto instantánea —una
corrida dura entre 3 y 40 minutos y la comprobación caducaba al segundo siguiente— pero sigue
siendo **detección, no prevención**: cuando canta, la corrida ya se perdió y hay que repetirla.

**El síntoma medido resultó ser más ancho de lo que decía este ticket.** No es solo que el runner
de la segunda mate al de la primera: la segunda **instala su `.app` sobre el mismo bundle id**, así
que la primera puede seguir viva tapeando un binario ajeno. Eso da rojos **con** su línea de fallo
y su mensaje de aserto —no el `Restarting after unexpected exit` sin veredicto— y por eso se leen
como bugs del producto. Es el modo de fallo que produjo el `high` falso de arriba.

## La decisión (Jürgen, 2026-09-11)

**Opción (2): un lock de fichero.** La segunda sesión **espera**; no falla y no instala encima.

Las tres que había sobre la mesa, y por qué esta:

| | Por qué sí / por qué no |
|---|---|
| 1 · **Un simulador por worktree** (clonar el device, `-destination id=<udid>` propio) | **No.** La Mini no aguanta varios booteados: con 4 arrancados el load llegó a **944** y el tiempo por corrida se **duplicó** (308 s → 727 s). Y cada clon pesa ~9 GB con el disco ya en 24 GB libres. |
| 2 · **Lock de fichero** | **Sí.** Barato, no cuesta disco y convierte el modo de fallo caro (un rojo que parece del producto) en una espera visible. El precio conocido y aceptado: **serializa el gate de todas las sesiones**. |
| 3 · **Dejarlo en la guardia** | **No.** Las sesiones autónomas nocturnas son justo las que coinciden, y ahí no hay nadie para esperar a mano. |

## Lo que se implementó (2026-09-12)

`qa/scripts/sim-lock.sh` envuelve el tramo que usa el simulador:

```bash
bash qa/scripts/sim-lock.sh -- xcodebuild -scheme "Yala Dev" … test …
bash qa/scripts/sim-lock.sh --estado          # ¿hay cola? sin entrar en ella
```

Decisiones de implementación que no venían dadas, todas medidas:

- **No hay `flock(1)` en macOS** (es de util-linux). El lock se toma con `python3` +
  `fcntl.flock`, que es el mismo lock del kernel: **lo suelta el kernel al morir el proceso,
  incluso con `kill -9`**, así que no hay huérfanos que limpiar en `/cerrar`. `shlock(1)` sí existe
  en macOS y se descartó: es PID-based y los PIDs se reciclan.
- **El PID no cambia**: el wrapper encadena `exec` hasta el `xcodebuild` en vez de lanzarlo como
  hijo, así que `sim-lock.sh … & sim-libre.sh --vigilar $!` sigue siendo válido — el centinela
  exige el PID del `xcodebuild` y rechaza el de un shell envoltorio.
- **El lockfile vive fuera del repo** (`~/Library/Caches/Yala/simulador.lock`). Uno versionado
  serían catorce locks, uno por worktree, y ninguna cola. `/tmp` y `$TMPDIR` tampoco valen: macOS
  los limpia por antigüedad y un fichero que desaparece bajo un dueño vivo rompe la exclusión.
- **La espera no tiene tope**; `--timeout N` es opcional y sale **75 sin ejecutar el comando**. Una
  corrida dura entre 3 y 40 min: un tope corto sería el rojo que veníamos a evitar.
- **Cubre los pasos 2 y 3 del `/gate` y la batería de `/l10n-check`**, no solo el XCUITest: los
  unit tests también corren dentro del simulador y `sim-libre.sh` los cuenta como ocupación.
  Serializar solo el paso 3 haría cantar al centinela contra quien se portó bien.
- **Al `/qa` de producto no se le pone lock**: es QA a mano, con un humano delante.
- **Sin `python3` no se ejecuta el comando** (exit 2). Un candado que se salta a sí mismo cuando le
  falta una pieza produce justo la corrida sin cola que venía a impedir, y encima invisible.

Y una corrección del centinela que iba con esto: **mientras tu corrida hace cola, `--vigilar` no
mide** (arranca cuando tu `xcodebuild` aparece él mismo ejecutando tests). Sin eso vería al dueño
legítimo del turno y convertiría el caso normal en un rojo falso. Si el vigilado muere sin ejecutar
un solo test sale **2**, no 0.

**El turno se toma en dos tiempos, y la segunda mitad la descubrió la review.** Tener la cerradura
no significa tener el simulador: el runner de XCUITest **no es hijo de `xcodebuild`** —cuelga de
`launchd_sim`, dentro del simulador— así que si una corrida muere de golpe (Ctrl-C, un `kill`, la
sesión que se cierra) el kernel suelta el lock **en ese instante** y su runner sigue vivo. Medido con
una corrida real: **1 runner vivo a los 1, 3, 6 y 10 s de matar el `xcodebuild`, con el lock ya
LIBRE**. El siguiente de la cola entraría a instalar su `.app` con el runner ajeno dentro — el modo de
fallo exacto que la cola viene a impedir, colándose por la puerta buena. Ahora, tras la cerradura, el
turno **espera a que el simulador se quede quieto**; pasados 60 s, si no hay ningún `xcodebuild … test`
vivo, ese runner no es de nadie y se retira, y si lo hay, se avisa de que alguien corre sin cola y de
que el veredicto puede no valer.

**Y el propio lock destapó un defecto del centinela que hasta ahora no podía verse.** Su última
muestra se tomaba hasta 5 s DESPUÉS de morir el vigilado, y con la cola puesta en esos 5 s ya está
corriendo el siguiente de la fila, legítimamente: la corrida de delante salía marcada como pisada.
Sin cola detrás nunca había nadie a quien señalar, así que el defecto era invisible; con la cola
habría cantado **cada vez que dos sesiones coincidieran**, que es el caso que veníamos a arreglar.
Ahora una muestra solo cuenta si el vigilado llegó vivo al final de ella, y si no hay ninguna
muestra sale 2.

**El lock no jubila al centinela.** `sim-lock.sh` vive en el árbol de trabajo, como `.githooks/`:
un worktree cuya rama sea anterior al 2026-09-12 no lo trae y no hace cola, y un `xcodebuild` a
mano tampoco. `--vigilar` sigue siendo obligatorio; lo que cambia es que ahora, cuando canta, el
intruso es identificable.

## Cómo se midió

**Banco sintético** — `bash qa/scripts/sim-lock-test.sh`, **37 casos**, sin tocar el simulador ni
compilar nada (usa un `xcodebuild` de mentira y su propio lockfile). Lo corre el CI en cada PR y en
los push a `2.1`, en el job `coverage-index`. Lleva **control negativo** —sin lock los tramos SÍ se
pisan— porque sin él el caso positivo saldría verde sin medir nada. Verificado con **nueve mutantes**,
todos contra el banco final:

| Mutante | Casos que caen |
|---|---|
| quitar `os.set_inheritable(fd, True)` (el lock se evapora en el `exec`) | **13** |
| devolver la reentrada a un PID vivo (las dos llaves maestras) | 4 |
| dejar que el sondeo se pase del `--timeout` | 4 |
| devolverle al centinela la muestra post-mortem | 3 |
| quitarle al centinela la fase de cola | 2 |
| `pgrep -f` sin corchetes (la foto se cuenta a sí misma) | 1 |
| el parseo del centinela mirando solo `$1` | 1 |
| que «no pude medir» cuente como «no hubo solape» (con el lock roto) | **13** |
| quitar la espera a que el simulador se quede quieto | 1 |
| *(sano, y control tras revertir)* | **0 / 0** |

**Y un caso del banco no discriminaba, lo que obligó a cambiar el producto.** El «cero solape» con
dos tramos de 2 s salía **verde con el lock roto**: lo que separaba las corridas no era la cerradura,
era la siesta de 5 s entre reintentos. Se arregló por los dos lados — el sondeo bajó a **1 s** (que
además es mejor cola: el simulador deja de estar parado mientras el siguiente duerme) y los tramos
del caso subieron por encima del sondeo.

**Dos corridas reales de XCUITest simultáneas**, las dos por el lock, sobre el iPhone 17 Pro
compartido (`CategoriesCrudUITests` y `BudgetsCrudUITests`, `test-without-building`, simulador
caliente y corrida de calentamiento descartada):

```
A  [.. arranca 095,64 .. termina 149,26 ]   53,6 s   exit 0   2 casos passed
B  [                  arranca 149,89 .. termina 192,55 ]   42,7 s   exit 0   2 casos passed

solape: −0,63 s  ⇒  DISJUNTOS. B arrancó 0,63 s DESPUÉS de que A terminara.
centinela A: ✓ estuviste solo (11 muestreos, máx. 1 runner)
centinela B: ✓ estuviste solo ( 9 muestreos, máx. 1 runner)
«Restarting after unexpected exit»: 0 en las dos.
```

Los instantes se toman del **proceso** (`pgrep -x` para el arranque real tras la cola, `wait` para el
fin), no del wrapper: medir el wrapper metía hasta 5 s de error y no habría distinguido «hizo cola»
de «se pisaron un poco».

**Esa medición pagó por sí sola**: la primera pasada cazó un defecto que solo existe CON el lock —el
centinela de la corrida de delante cantaba señalando a la que esperaba detrás— y que sin la cola no
se habría visto nunca.

**El control negativo real —dos corridas SIN lock— no se repitió a propósito**: está medido dos veces
(2026-09-07, 2/2 reproducido; 2026-09-11, el `high` falso) y repetirlo hoy habría derribado la
corrida de cualquier sesión que entrara a mitad. El control negativo del mecanismo lo da el banco,
que sí lo ejercita sin daño.

## La review adversarial, y lo que encontró

Tres lentes independientes (fallo silencioso · carreras y concurrencia · las reglas del repo leídas
CONTRA el diff). **Diez defectos eran míos, de esta misma sesión**, y dos de ellos dejaban correr dos
corridas a la vez **sin un solo mensaje**, que es justo lo que este ticket viene a impedir:

| | Qué era | Cómo se comprobó |
|---|---|---|
| **Dos llaves maestras en la reentrada** | la marca se fiaba de un PID: `YALA_SIM_LOCK_HELD=0` hacía que `os.kill(0,0)` señalara al propio grupo y nunca fallara ⇒ pase libre universal; y el PID de un proceso de otro usuario daba `PermissionError`, que se leía como «vivo, es mi ancestro» ⇒ lo mismo | reproducidas las dos: exit 0 y comando ejecutado. Ahora la marca es un **token** que tiene que coincidir con el del lockfile: las cinco marcas inventadas del banco salen 75 |
| **`--quiet --vigilar PID` apagaba el centinela** | el parseo miraba solo `$1`, así que caía a la foto instantánea y **salía 0 sin vigilar nada**, callado por el propio `--quiet`. La única forma de pedir un centinela silencioso era la que lo desactivaba | reproducido (exit 0 instantáneo). Ahora las banderas se combinan en cualquier orden |
| **El caso estrella del banco daba verde sin datos** | el comparador de solapes devolvía 2 («no pude medir») y el `if` lo metía en la rama del ✓: con la traza vacía —porque los comandos no llegaron a correr— el banco certificaba que el lock funciona | los tres códigos van ahora a ramas distintas, y el mutante M8 lo fija |
| **El banco podía saltarse su propia cola** | su marca de «ya estoy en cola» era una variable de entorno: un `export` suelto y sus falsos `xcodebuild` salían a molestar a las corridas ajenas | ahora viaja como argumento, que no se hereda |
| **Aserción que no podía fallar** | el caso del PID miraba `ps -o command=`, y la línea de comando del python3 envoltorio **contiene** la palabra `xcodebuild`: habría dado ✓ justo en el fallo que vigila | cambiado a `ps -o comm=` |
| **Ruta de lockfile relativa** | se aceptaba sin validar: cada worktree habría cerrado sobre su propio fichero, catorce locks y ninguna cola | rechazada con exit 2, con su caso |
| **Inodo desenlazado** | si alguien borra el lockfile bajo un dueño vivo (`~/Library/Caches` es purgable), el siguiente crea otro inodo y la exclusión mutua se acaba en silencio | se comprueba `fstat == stat` tras tomar el turno, y se reabre |
| **Errores de entorno con traceback** | `os.open` sin `try` salía con 1, que se lee como «los tests fallaron», en vez del 2 que promete la cabecera | capturados |
| **Tramos más cortos que el sondeo** | el caso de cinco corridas usaba tramos de 1 s con un sondeo de 1 s: medía la siesta, no el lock | subidos |
| **`«$VAR»` mata el script** | bash lee el nombre de la variable hasta el primer carácter que no valga, **y los bytes altos de `»` le valen**: intenta expandir `VAR»` y con `set -u` muere con «unbound variable» y exit 1. Me mordió **tres veces el mismo día**, escribiendo en español | las tres arregladas a `«${VAR}»`, y buscadas todas con un `grep -P` sobre `qa/scripts/` y `.githooks/` |

**Y tres que no eran míos**, preexistentes, que salieron por estar en el camino:

- **`pgrep -f 'UITests-Runner'` se contaba a sí mismo.** Medido con CERO runners vivos: devuelve **1**,
  porque empareja los argumentos de los otros `pgrep` que corran a la vez. **Dos fotos simultáneas se
  declaraban «ocupado» mutuamente 6 de 6 veces con el simulador en reposo** — o sea, un gate bloqueado
  por nada, que es el falso positivo contrario al que perseguíamos. Arreglado con `'[U]ITests-Runner'`
  (0 de 6 tras el cambio) porque estaba en la pieza que se estaba tocando.
- **`.claude/rules/testing.md` contaba «~10 worktrees» (son 14) y situaba el XCUITest en el «paso 4»
  del gate (es el 3).** Corregidos los dos; son afirmaciones verificables en el fichero que se editaba.
- **`/l10n-check` dice que corre 15 tests y corre 13 de 17**, y con `-quiet` no puede darse cuenta.
  Ticket propio: `l10n-check-corre-13-de-17-tests`.

**Una lección de método, y costó un susto:** una de las lentes leyó `qa/scripts/sim-libre.sh` **mientras
una batería de mutantes lo tenía mutado**, y reportó como defecto grave lo que era el mutante. Se
refutó leyendo el fichero real. **Una review y una tanda de mutantes no pueden compartir árbol.**

## Criterio de hecho

- [x] Elegida una de las tres y escrita como decisión. → **(2)**, arriba, y en
      `.claude/rules/testing.md`.
- [x] Si es (1) o (2), implementada y con dos sesiones simultáneas midiéndolo.

## Lo que este ticket NO cierra

- **Un worktree con rama vieja sigue sin hacer cola.** No tiene arreglo desde aquí (el script viaja
  en el árbol); se cubre con el centinela, y desaparece según las ramas se actualizan.
- **La cola no es FIFO.** Con varios esperando, el turno lo reparte el kernel. Con dos o tres
  sesiones da igual; si algún día una se queda sin entrar, ahí hay ticket.
- **Cinco recetas del repo siguen lanzando `xcodebuild test` sin cola** —los cuatro
  `qa/prompts/translate-*.md` y `qa/prompts/README.md`, más `qa/scripts/add-l10n-key.sh` y
  `qa/cloud/README.md`—. Son de otro flujo (traducciones y nube) y ampliar ahí era salirse del
  encargo: ticket `prompts-de-traduccion-corren-xcodebuild-sin-cola`. Una de ellas
  (`translate-ja.md`) hace además `xcrun simctl install booted`, que es literalmente el modo de
  fallo «la otra corrida instala su `.app` encima».

## Relacionados

- [[rojo-xcuitest-runner-muere-tras-el-primer-caso]] — la medición que lo destapó
- [[welcome-chooser-uitests-cannot-reach-the-chooser]] — descartado el 11-sep: el `high` falso que
  costó esta contención, y el modo de fallo «la otra corrida instala su app encima»
- `.claude/rules/testing.md` — la regla, el criterio de clasificación del rojo y las trampas del
  banco
