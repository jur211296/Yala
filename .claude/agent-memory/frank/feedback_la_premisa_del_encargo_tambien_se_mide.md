---
name: la-premisa-del-encargo-tambien-se-mide
description: El encargo hereda las premisas falsas del ticket y medirlas cambia el trabajo; y la cara B — a veces la premisa es buena y el que la leyó mal fui yo, así que la CORRECCIÓN también se mide antes de publicarla
metadata:
  type: feedback
---

La regla «mide antes de obedecer a un documento» **incluye el propio encargo**, no solo el ticket y
las docs del repo. El encargo lo redacta Jürgen leyendo el ticket, así que hereda sus errores y
llega con el tono de un hecho establecido.

**Why:** el 2026-09-06, el encargo de `groups-leave-rpc-error-10` afirmaba en su sección «Contexto»
que el caso #10 era `channelDisabled` (kill-switch) y avisaba «no confundir con `ownerCannotLeave`
(eso sería otra frase)». Era exactamente al revés, y el propio ticket marcaba esa lectura como
*inferencia sin comprobar*. Medirlo costó un script de Swift de 40 líneas: el tag que Foundation
imprime **no sigue el orden de declaración** (los casos con payload van primero). Con la premisa
buena, las dos «caras» que el ticket separaba resultaron ser el mismo defecto, y el punto 4 del
encargo («si el 10 es canal apagado…») se quedó sin objeto.

**How to apply:** cuando el encargo afirme un hecho **verificable** —un número, una coordenada, qué
caso de un enum es cuál—, mídelo antes de construir encima, sobre todo si el ticket de origen lo
marcó como inferido. No bloquea: el trabajo suele seguir siendo el mismo (aquí, «dar copy honesto»),
pero cambia cuál es el caso protagonista y qué hay que arreglar de verdad. Y díselo — no como
corrección, sino como el dato que reordena el ticket. Ver [[review-adversarial-caza-lo-mio]] y
[[mis-mediciones-fallan-por-el-filtro]].

## Segundo caso, el mismo día, y más fuerte: el defecto YA estaba arreglado

El encargo de `groups-pending-member-can-open-group` (2026-09-06) pedía «cerrar la puerta en el
cliente: la tarjeta del grupo no abre el detalle mientras el miembro esté en `pendingApproval`».
Medido antes de escribir código: **la tarjeta ya no lo abría**. `GroupCardView.handleTap` tenía un
`case .pendingApproval` que no navegaba desde `#26`, y el doc del helper lo decía con todas las
letras.

Lo que fallaba en el reporte de campo (TestFlight build 12, 28-ago) era la **identidad** que
alimentaba ese gate: `currentMemberStatus` resolvía por el flag `isCurrentUser`, que
`GroupsSyncClient.applyMember` **nunca enciende**, así que a quien llegaba por el pull le devolvía
`nil`, el modo caía en `.active` y la tarjeta abría. Y eso lo arregló **otro ticket**, `5ca4dd47`
(4-sep), ya en `2.1`. Dos comandos lo zanjaron: `git log -L '/func currentMemberStatus/,+4:<f>'` y
`git branch -a --contains`.

**Why:** el encargo describía el síntoma de un build de hace nueve días como si fuera el estado de
hoy. En un repo donde entran varios PR al día, **un reporte de campo caduca**, y el trabajo que
describe puede haberlo hecho ya un vecino sin saberlo. Si hubiera «cerrado la puerta» sin medir,
habría escrito un gate encima de otro y declarado arreglado algo que ya lo estaba — sin tocar
ninguna de las tres cosas que sí seguían rotas.

**How to apply:**
- Cuando el encargo venga de un **reporte de device con fecha y build**, lo primero es preguntarse
  «¿sigue vivo en `2.1`?». `git log -L` sobre la función sospechosa y `git branch --contains` sobre
  el commit que salga cuestan un minuto y contestan.
- **Que la premisa sea falsa casi nunca cancela el trabajo**: aquí quedaban tres cosas reales (el
  tap era un muro mudo, había dos puertas más sin gate, y el copy prometía lo que la decisión
  eliminaba). Lo que cambia es **cuál es el trabajo**, no si lo hay.
- Y díselo a Jürgen en esos términos: «el bug que reportaste ya no se reproduce, lo cerró X; lo que
  encontré abierto es esto otro». Ver [[mis-mediciones-fallan-por-el-filtro]].

## 2026-09-07 — la variante silenciosa: la cifra no era falsa, era de la magnitud equivocada

En `el-job-de-tests-del-ci-no-tiene-timeout` el ticket traía una tabla de duraciones y una
conclusión: «~80 minutos de media», con la recomendación de «un `timeout-minutes` alrededor de 120».
Nada de eso era mentira. Pero:

- **la muestra eran 4 runs.** Con los 39 que había (todos los que dispararon el job en dos días), la
  mediana real es **89**, no 80, y el p95 sube a 99,5. Cuatro puntos no sostienen un percentil, y el
  ticket llamaba «percentil alto» a lo que era el máximo de cuatro.
- **y sobre todo, medía el objeto equivocado.** La decisión que el propio ticket recogía sacaba la
  UI del PR; en cuanto la sacas, el número que gobierna el tope del PR ya no es el del job entero
  sino el de **build + unit**, que nadie había medido: p95 **27,2**, máximo **29,9**. El «alrededor
  de 120» del ticket habría sido un tope cuatro veces mayor que el peor caso real — o sea, ninguno.

La única forma de ver esto fue medir **por paso**, no por job (`/actions/runs/<id>/jobs` trae cada
step con `started_at`/`completed_at`). Coste: un bucle de `gh api` y un script de 30 líneas.

⇒ a la lista de premisas verificables se añade una que no parece premisa: **una cifra correcta pero
agregada al nivel equivocado**. La pregunta no es «¿es cierto este número?» sino «¿mide el objeto
que mi decisión va a acotar?». Cuando la decisión cambia la forma del trabajo —aquí, partirlo en dos
corridas—, las mediciones del ticket describen un mundo que ya no existe, y sirven de línea base, no
de respuesta. Y desconfía de un percentil con menos de ~20 puntos: dilo como «máximo observado».

## 2026-09-08 — la premisa que dice DÓNDE NO MIRAR es la más cara de todas

`goldens-de-staging-solo-pasan-a-trozos` afirmaba, en negrita y como el hecho central del
diagnóstico: **«Los 10 fallos son timeouts. Cero aserciones fallidas — ni una en ninguna corrida.
Eso importa: no hay ningún fallo de lógica.»**

Había dos fallos de aserción, y **eran la respuesta entera**. El bump de canon a `c2` del 7-sep
había dejado dos `expect(...).toBe("c1")` sin actualizar. El ticket incluso los tuvo delante: su
corrida 3, con el manifest sincronizado, dio «14 · 11, ligeramente PEOR» — esos dos rojos nuevos
eran los asserts, y se leyeron como ruido que empeoraba la hipótesis en curso.

Y no era la única premisa falsa del mismo ticket: los conteos de grupos estaban **cruzados** entre
los dos usuarios y con otros números (decía A=677/B=511; medido, A=530/B=678), lo que importaba
porque la hipótesis apuntaba al usuario A y el test que más sufre pullea al B. El «factor 70x, ~69 s
por test» era el promedio de repartir el total entre 25 tests que van de 0,0 s a 130 s.

**Why:** una premisa que dice «no hay nada de esta clase» es una **poda del espacio de búsqueda**, y
por eso cuesta más que una cifra mal copiada: no te manda a un sitio equivocado, te prohíbe uno
correcto. Aquí bastó correr la suite una vez mirando el tipo de cada fallo — 5 minutos — para
tumbarla.

**How to apply:** cuando un ticket clasifique los fallos («todos son timeouts», «todos de la misma
familia», «ninguno es de lógica»), esa clasificación es una **afirmación verificable y barata**, no
un contexto. Re-córrelo y clasifica tú. Es la versión de «cuando un documento te diga no mires aquí,
mira» aplicada a la taxonomía del propio fallo. Ver [[rojo-conocido-no-exime-de-bisecar]].

---

## La premisa «esto no se puede probar en simulador» es la más cara de todas (2026-09-08)

En el barrido de `tickets/qa/` **tres** tickets declaraban en su propio cuerpo que su verificación
era imposible en simulador. Las tres eran falsas, y las tres llevaban meses **inflando la cola de
device-QA de Jürgen**:

| Lo que decía el ticket | Lo que medí |
|---|---|
| «Ningún seed es multi-divisa (son PEN)» | `DevSeedAccounts.swift:22-36` crea cuenta **PEN** y cuenta **USD** |
| «No hay histórico real de tasas con una fila incompleta» | Las filas sembradas traen **solo PEN/EUR/USD** de 48 divisas: parciales **por construcción** |
| «La card de P&L no aparece en XCUITest; su cobertura es cero por construcción» | Aparece con el seed `minimal`, sin tocar nada |

Y el `docs/ESTADO.md` que yo mismo escribí repetía la primera.

**Why:** esta familia es peor que una coordenada envejecida por dos motivos. Uno, **se
autoconfirma**: nadie intenta lo que el documento declara imposible, así que la premisa nunca se
contrasta y se copia de ticket en ticket (aquí saltó de un ticket de FX a otros dos y al ESTADO).
Dos, **su coste no es tiempo perdido sino trabajo desviado a la persona equivocada**: cada una de
esas tres frases mandaba a Jürgen a coger el teléfono para algo que se veía en 5 minutos aquí.

**How to apply:** cuando un ticket diga «necesita device», «no es simulable» o «cobertura cero por
construcción», trátalo como **la afirmación más sospechosa del fichero**, no como el contexto.
Comprobarlo cuesta un `grep` al seed: `DevSeedAccounts`, `DevSeedExchangeRates`, `DevSeedGroups`
dicen exactamente qué corpus existe. Y la pregunta que separa de verdad las dos colas no es «¿el
camino real pasa por la red?» sino **«¿se puede sembrar el ESTADO FINAL que hay que mirar?»** — casi
siempre sí. Lo que de verdad no se simula es corto y reconocible: push APNs de verdad, sign-in real,
un RPC que devuelve un código que solo emite el servidor, Apple Pay, y dos teléfonos a la vez.

Corolario que salió el mismo día: **a veces el bloqueo es real pero la causa está mal atribuida.**
`groups-owner-transfer-and-leave` figura como device-QA, y lo que impide verlo es que **ningún
perfil de seed escribe `userID`**, así que `eligibleHeirCount` es siempre 0 y el botón no se pinta.
Eso no lo arregla un teléfono: lo arregla el seed. Distinguir «no se puede aquí» de «no se puede
**todavía** aquí» es lo que convierte una cola física en un ticket de backlog.

## Y la premisa heredada no siempre es del encargo: el 2026-09-09 vino del `docs/ESTADO.md`

El NOW decía «**cinco** tickets de FX bloqueados por `qa-no-puede-crear-cuenta-en-otra-divisa`», y
escribí «éste es el **sexto**» en el ticket, en el PR y a punto de mandarlo. Al contar: **tres** se
declaran *no* simulables por esa causa y **dos** más piden el mismo montaje declarándose *sí*
simulables. Ni cinco ni seis, y la diferencia importa porque esa cifra es la que justifica priorizar
la palanca.

**Why:** una cifra de un documento se copia sin fricción — no parece una afirmación, parece un dato.
Y en este repo la documentación envejece más rápido que el código.

**How to apply:** **toda cifra que vayas a REUSAR se re-mide**, venga del encargo, del ticket o del
estado. Cuesta un `grep -rl`. Y si al medirla sale otra, dilo en el sitio donde la reusaste **y
corrige el documento de origen**: dejarlo pasar es lo que hace que la próxima sesión herede el mismo
número.

## La LETRA de una decisión puede no cumplir su propósito con los datos reales (2026-09-10, paso 6)

Jürgen decidió «un faro que apunta a una cuenta inexistente se limpia solo en cuanto [I] lo descubre», y
el motivo era el fresh start de producción. La lectura literal —«el hash del faro es el de la sesión y el
backend dice que no existe»— **no habría disparado nunca en ese caso**: el hash es del uuid de Supabase, y
al borrarse `auth.users` volver a firmar da OTRO uuid. Lo que sí lo probaba era el método (Sign in with
Apple solo firma con el Apple ID del teléfono, que es el mismo cuyo iCloud-KV guarda el faro).

**How to apply:** antes de implementar el mecanismo que una decisión nombra, pasa **el escenario que la
motivó** por el modelo de datos, paso a paso. Si el mecanismo literal no lo cubre, la decisión describe el
QUÉ y el CÓMO hay que buscarlo — y se dice en el Paso 0 con la medición que lo prueba, para que Jürgen pueda
discrepar leyendo.

## La cara B, y da más vergüenza: la premisa era buena y el que leía mal era yo (2026-09-10)

En el paso 0 del rediseño (`retire-guest-vocabulary-for-session-terms`) el ticket decía: «los dos
strings ES **y sus 15 hermanos** se retiran cuando `WelcomeGroupsGateView` pierda la rama
secundaria». Medí `welcome.groups.secondary*` en el catálogo ES, salieron **dos** keys, y escribí en
el ticket y en el PR una fila que decía «**Falso: son 2**».

Estuvo a punto de quedarse escrito. Los «15 hermanos» **son los otros 15 locales**: la app tiene 16
y las dos keys viven en los 16, así que el paso 12 retira **32 strings**, no 2. El ticket tenía
razón, y mi «corrección» habría metido en el repo un error donde no lo había — con el agravante de
que iba en la tabla de «lo medido», que es la que la próxima sesión creerá sin comprobar.

**Why:** todo lo de arriba entrena a buscar dónde miente el documento, y eso crea el sesgo
contrario: cuando un número no casa con mi medición, la explicación cómoda es que el documento se
equivocó. Casi siempre hay una tercera lectura —una palabra que significa otra cosa en ese
dominio— y no cuesta nada descartarla. Aquí bastó `ls Yala/Resources/*.lproj | wc -l`.

**How to apply:**
- **Una corrección es una afirmación, y se mide igual que la premisa que corrige.** Antes de
  escribir «el ticket dice X y es falso», pregúntate qué tendría que ser cierto para que X lo fuera.
  Si esa lectura existe y no la has descartado, no publiques la corrección.
- Sospecha de las palabras vagas de un ticket —«hermanos», «variantes», «los demás»— **en el dominio
  del ticket**: en l10n «hermano» es un locale, no una key.
- Y el corolario del mismo día: **el checklist de un ticket puede llegar hecho a medias.** Cuatro de
  las cinco entradas de glosario que este pedía **ya existían**, escritas por el commit del propio
  ADR. Comprobar el estado real antes de escribir cuesta un `grep` y evita re-escribir encima. Es la
  misma familia que «el defecto YA estaba arreglado», pero por dentro del alcance en vez de fuera.

## La forma más cara de todas: el ticket trae su propia BISECCIÓN, y no bisecó nada (2026-09-11)

`welcome-chooser-uitests-cannot-reach-the-chooser` llegó `high`, con tabla de siete casos, el log
del timeout citado y esta frase: «**No son flaky y no son de nadie**: se reprodujeron dos veces
seguidas en el árbol de trabajo y otras dos en un worktree limpio de `2.1` (`1a9cbb83`). Es la
bisección que los clasifica como preexistentes.»

Los siete **pasan**. Medido: 11/11 en `2.1` de hoy (×2 corridas), 11/11 en `1a9cbb83` —la revisión
exacta de la «bisección»— y los once verdes en la nocturna de CI del 11-sep dentro de los 149 casos.

**Por qué la bisección no valía, y esto es lo que hay que reconocer al leerla:**

- **Las dos suites eran byte-idénticas entre las dos revisiones.** Un `git diff --stat A..B --
  YalaUITests/` (3 segundos) lo dice: tocaba un solo fichero, y era otro. Si el objeto medido no
  cambia entre los dos extremos, **no hay bisección posible** — sea cual sea el resultado, el
  cambio está fuera del eje que se cree estar recorriendo.
- **«Dos veces seguidas» no es aislar, es repetir la condición.** Si lo que contamina es el entorno
  —aquí, otra sesión en el mismo simulador—, cuatro repeticiones miden cuatro veces lo mismo. La
  repetición solo refuta el azar; contra una condición persistente no prueba nada.
- **La hipótesis se caía con un grep.** El ticket acusaba a `WelcomeHeroView.handleEmpezar()` de
  «encaminar» a algún sitio nuevo; son cuatro líneas que llaman `onContinue()`, y el faro que
  nombraba se consulta un paso después. **Leer el código que el ticket acusa va ANTES de montar la
  reproducción**: es más barato que compilar.

**How to apply:** ante un ticket de test rojo con bisección incluida, el orden es (1) `git diff
--stat <base>..<head> -- <ruta del test>` para ver si el sujeto cambió siquiera, (2) leer la función
acusada, (3) buscar una medición INDEPENDIENTE de esta máquina —la nocturna de CI la da gratis con
`gh run view <id> --log`— y solo entonces (4) reproducir. Los tres primeros pasos cuestan minutos y
los cuatro rojos del ticket hermano salieron de la misma corrida, o sea que el log ya estaba pagado.
Ver [[dos-corridas-un-simulador]] y [[rojo-conocido-no-exime-de-bisecar]].

## 2026-09-14 — la premisa nombra un MECANISMO que existe, y ese mecanismo hace otra cosa

El encargo de `remote-wipe-alert-skips-the-router` decía: «presentar por el router / cola
(`RouterEntryGate` / `.remoteWipe`), **como el otro productor**». Las dos mitades sonaban igual de
firmes y solo una lo era. La vía sí: el aviso tenía que ir por la cola. El CASE no: `.remoteWipe` no
presenta nada — su drenaje llama `handleRemoteWipeSignal`, que **borra** el corpus local. Reusarlo
habría convertido una pregunta («¿empiezo de cero?») en un borrado silencioso, y además habría
chocado con un escáner que fija que ese intent se emite desde un solo sitio.

**Why:** cuando la premisa nombra un símbolo que EXISTE, se lee como ya verificada — el nombre casa,
el fichero está, el grep encuentra. Lo que no se comprueba es qué hace al drenarse. Es la variante
más fácil de tragarse de toda esta lista, porque no hay ningún dato que contradiga nada: hay un
parecido de nombre.

**How to apply:** si el encargo (o el ticket) te manda reusar un mecanismo «como el otro», **lee el
consumidor de ese mecanismo, no su productor**. La pregunta es «¿qué pasa cuando esto llega al
otro extremo?», y se contesta con un grep al `case` del switch que lo drena. Y cuando la premisa se
parte en dos —la vía buena, el case malo—, dilo así en el Paso 0 y en el PR: no es «el encargo
estaba mal», es «de las dos cosas que decía, esta se sostiene y esta no».

## 2026-09-15 — la premisa falsa era MÍA, y venía de la memoria

En el Paso 0 de `groups-push-reads-an-offline-token-refresh-as-a-session-expiry` escribí «el canal personal (Modo Nube
apagado) → ticket `low`», y lo repetí en el ticket. Lo saqué de una memoria del 14-sep («`storageMode` es siempre
`.icloud` hoy»). Una lente lo tumbó con una línea del propio código: el docblock de
`CloudSyncFlags.bornCloudChoiceEnabled` dice que producción sirve la tarjeta de alta en la nube al 100 % desde el
2026-09-09, medido con `curl`. O sea que puede haber cuentas `.cloud`, y en ellas Grupos cicla dentro del runtime
personal que yo dejaba fuera. El ticket subió a `medium`.

**Why:** una premisa de población decide prioridades, y la mía no llevaba la fecha delante: «apagado» era cierto antes
de un cambio de percent que se hizo sin tocar el código. Es la familia del reporte de campo que caduca, pero por la
memoria en vez de por el encargo.

**How to apply:** antes de bajar la prioridad de algo porque «no le llega a nadie», busca la PALANCA que lo enciende
—el flag compilado y el percent remoto— y lee qué dice hoy. Una memoria que diga «X está apagado» es una afirmación
con fecha, y los percents se mueven sin tocar el código.

## Tercer caso (2026-09-24): el encargo prescribía la SALIDA equivocada

El encargo de `leader-displaced-after-the-cutover-pushes-its-residual-in-the-reconcile` pedía que el
teléfono desplazado «pare y salga con el texto del relevo, misma familia que #237». Después del cutover
esa salida no existe sin romper «el cutover jamás hace rollback»: el marcador ya se exportó. El ticket sí
admitía «sale **o se recupera**», y la recuperación (esperar sin subir, unirse cuando el otro cierra) era
lo correcto. **How to apply:** cuando el encargo diga *cómo* arreglarlo, comprueba que ese cómo es legal en
la fase del caso, no solo en la del ticket hermano del que copia el molde; y déjalo por escrito en el Paso 0.

## Cuarto caso (2026-09-25): implementé el arreglo del encargo y la premisa era falsa

Esta vez el encargo lo escribí yo, la noche anterior, con un «inferido» de una lente: el líder desplazado tras
el cutover «se devuelve una identidad que el backend no conoce». Lo implementé tal cual, con tests y seis
mutantes muertos, y no me paré a medir la premisa. Estaba mal: al reconcile de `done` solo se llega tras la
verificación en `.match`, y el Merkle lleva el `sync_id`. Así que el backend SIEMPRE tiene esa identidad. Lo
cazaron dos lentes a la vez, y el arreglo además abría un duplicado en el caso principal. Se retiró: ticket a
`discarded` y código intacto.
**How to apply:** antes de implementar, ve al «Inferido» del ticket y pregunta qué paso del flujo lo haría
imposible. Aquí bastaba recorrer la máquina de estados hacia atrás desde el efecto: una pregunta sobre qué ha
tenido que pasar para llegar a él. Si el encargo te «elige la opción robusta», elige solo entre opciones que
arreglen algo que exista.
