---
id: late-remote-wipe-on-a-device-without-groups-cannot-return-the-rows
status: done
priority: medium
area: "groups, sync"
created: 2026-09-27
updated: 2026-09-28
source: "review adversarial de `late-remote-wipe-signal-undoes-the-rows-the-origin-reconverged` (2026-09-27, lente de sync); inferido por lectura, NO reproducido"
qa-status: not-replicable
qa-date: 2026-09-28
qa-notes: barrido 2026-09-28 sin device-QA - pide iPhone y iPad con el mismo Apple ID; cubierto por GroupsBridgeRestoreConvergenceTests y RemoteWipeSignalWiringTests
---

# Si el dispositivo que procesa tarde el vaciado no tiene Grupos, los gastos de grupo no vuelven

## El síntoma, en lenguaje de usuario

Uso Grupos en el iPhone; en el iPad nunca entré en mi cuenta de grupos. Vacío mis datos en el iPhone y los gastos de
grupo vuelven al abrirlo. Días después abro el iPad: se vacía, y en el iPhone los gastos de grupo desaparecen otra vez y
ya no vuelven.

## Lo medido (2026-09-27, leyendo código)

- Desde el ticket `late-remote-wipe-signal-undoes-the-rows-the-origin-reconverged`, el receptor que se lleva filas
  puenteadas posteriores a la señal pide la convergencia (`DataWipeService.wipeLocallyForRemoteWipeSignal`).
- El store de Grupos es local de cada dispositivo (`cloudKitDatabase: .none`) y lo llena el canal backend, que necesita
  sesión de la cuenta Yala en ese dispositivo (`GroupsSyncClient.startIfEligible`). Las `TransactionItem` puenteadas sí
  viajan por el espejo personal.
- `GroupsBridgeRestoreConvergence.convergeIfPending` re-puentea solo los `SplitExpense`/`SplitSettlement` locales. Sin
  ninguno, retira la petición igual. `GroupsPendingBridgeIntent` tampoco sirve: da por abandonado un id sin fila local.
- Lo mismo, en parte, con el canal parado (sesión caducada, kill-switch): lo que el receptor aún no conoce no vuelve.

## Decisión (Frank, 2026-09-27, en el encargo)

Quien tiene los grupos repone, y solo cuando las filas ya faltan. El receptor le dice qué filas se llevó.

## Qué cambia para el usuario

Vacío mis datos en el iPhone y los gastos de grupo vuelven. Si después abro el iPad, que no tiene Grupos, se vacía como
antes. En el siguiente arranque en frío del iPhone, después de que le llegue el borrado del iPad, los gastos y las
liquidaciones de grupo vuelven a lo personal, una vez. Si el iPad tenía algunos grupos, repone él esos y el iPhone el
resto.

## Qué se hizo

- **El receptor declara lo que no puede reponer.** En la rama «posterior a la señal», además de pedir su convergencia,
  `wipeLocallyForRemoteWipeSignal` escribe en el iCloud-KV del Apple ID una declaración: por cada gasto o liquidación que
  se lleva y que su convergencia no va a reponer (no lo tiene en local, o es una liquidación que allí sigue sin
  confirmar), la huella de cada fila posterior a la señal que borra (`createdAt` y si es de la cuenta de grupos). Lo
  anterior a la señal no se declara: el origen ya lo borró. La escribe ANTES de borrar, y se la apunta como suya.
- **Quien tiene los grupos repone por fila.** `GroupsRemoteWipeReturn.returnIfDeclared`, en `AppBootstrapper.retryPendingBridges`
  detrás de la convergencia, re-puentea un id cuando aquí ya no queda ninguna de sus filas declaradas. Mientras quede
  una, el borrado no ha llegado por el espejo y espera. Liquidaciones con el criterio de la convergencia: sin ninguna
  pata, confirmadas y fuera de grupos ocultos. Solo en una sesión privada que obedece la señal (iCloud).
- **Una vez por declaración.** Lo repuesto se apunta en local por declaración, y las declaraciones viven 30 días en una
  lista del KV, cada una con su id.

### Lo que la review tumbó de la primera versión

Tres lentes (sync, dinero, consumidores). La primera versión esperaba a que no quedara NINGUNA fila del gasto, y el
receptor lo declaraba todo para ser el único reponedor. Cayó por tres lados:

- Un receptor que solo había importado parte de las filas del gasto (la virtual sin la real), o un origen que había
  rehecho la virtual, dejaba el gasto «presente» para siempre y sin conciliar. Ahora la prueba es por fila.
- «Un solo reponedor» era falso: el canal de grupos del receptor puentea igual lo que baje. Ahora el receptor converge
  lo suyo y declara solo lo que le falta.
- Unir declaraciones bajo un id nuevo hacía que el primer receptor perdiera su marca de «es mía». Ahora son una lista.

Y la huella solo por hora no distinguía la real de la virtual de un mismo gesto del bridge. Lo cazó un test que falló.

La re-review del rediseño añadió dos cosas: el receptor da por suya solo la liquidación que su convergencia repondrá
(confirmada y fuera de grupos ocultos), y no declara lo anterior a la señal, que solo agrandaba la declaración y el
alcance de la carrera entre dispositivos con grupos.

## Verificado

- Unit, 33 casos en la suite de comportamiento más la lógica pura:
  - El orden del ticket: el origen convergió, el receptor sin grupos procesa tarde, no se repone con las filas presentes,
    llega el borrado, vuelven una vez y un segundo arranque no crea nada.
  - El receptor con solo parte de las filas (la real y la virtual en el mismo instante, separadas solo por la cuenta). El
    origen que rehízo la virtual. El receptor con grupos parciales (declara solo lo que le falta), con una liquidación
    local sin confirmar (la declara) y con todos (no declara). El orden normal (no declara). El espejo redondea la hora
    al milisegundo en todos los casos.
  - Quien declara no atiende la suya. Una segunda declaración se atiende otra vez. Una vez por declaración. Lo que aún
    no ha bajado se repone al llegar.
  - Caducidad, sesión solo-grupos y sesión que no obedece la señal. Grupo oculto. Liquidación con pata viva. Lo no
    atendido va a la intención durable. La marca «es mía» sobrevive al reset de preferencias en `.standard`. El relevo
    de persona la retira.
  - Scans de cableado: el arranque la llama tras la convergencia y detrás de sus gates; el receptor declara antes de
    borrar; el predicado por defecto es el del receptor de la señal.
- Mutantes y gate: ver el PR.

## Fuera, con ticket

- Una liquidación ya aprobada vuelve a pedir su cuenta, porque D7 no deja rastro:
  `settlement-approval-leaves-no-trace-so-a-rebridge-asks-again`.
- Una liquidación con dos patas de un mismo gesto (el formulario con cuenta) de la que el receptor solo importó una: la
  otra sigue en el origen, no se re-puentea (el bridge borraría la real) y la que se llevó no vuelve.
- Una fila cuya cuenta el receptor aún no tenía hidratada se declara sin tipo y casa con las dos: si en el origen hay
  otra del mismo gesto que el receptor no se llevó, se espera hasta que la declaración caduca.
- Dos dispositivos con grupos que re-puentean el mismo id antes de cruzarse por el espejo duplican. Es la misma clase que
  el canal de cualquier dispositivo con grupos. Un dispositivo recién instalado ve ausentes las filas que aún no importó.
- La cuota de 1 MB del iCloud-KV: con miles de filas la declaración puede no subir, y la relectura de la caché local no
  lo ve.
- Sigue siendo en el arranque en frío: `wipe-data-group-rows-return-only-on-the-next-cold-launch`.

## Guion de device-QA

Hacen falta dos dispositivos con el mismo Apple ID, en modo iCloud y con sesión privada. El iPad NO debe haber entrado
nunca en la cuenta de grupos.

1. En el iPhone, entra en tu cuenta de grupos. Crea un grupo con un gasto que pagues tú y una liquidación confirmada.
2. Abre el iPad y comprueba en Registros que le han llegado el gasto y la liquidación del grupo. Cierra la app del iPad
   desde el selector de apps.
3. En el iPhone: Perfil → Ajustes → «Vaciar datos», conservando los grupos. Cierra la app del todo y vuelve a abrirla. El
   gasto y la liquidación deben estar en Registros.
4. Espera un par de minutos con el iPhone abierto, para que suba a iCloud.
5. Abre el iPad: se vacía.
6. Espera un par de minutos con el iPad abierto. Después cierra la app del iPhone del todo y vuelve a abrirla.
7. En el iPhone: el gasto y la liquidación de grupo están en Registros, una sola vez cada uno, y el Inbox tiene un solo
   borrador por cada uno. Pasado un minuto, comprueba lo mismo en el iPad.
8. Si en el paso 7 no están, repite el paso 6 una vez: el borrado del iPad puede tardar en llegar por iCloud.

## Barrido de `qa` · 2026-09-28 · cerrado sin device-QA

Sale de la cola de device-QA por el barrido semanal (encargo `2026-09-28-barrido-qa-in-qa-semanal`), con el criterio del 2026-09-23 (#224). El guion pide dos dispositivos con el mismo Apple ID (un iPhone con grupos y un iPad sin ellos). Lo cubren `GroupsBridgeRestoreConvergenceTests` y `RemoteWipeSignalWiringTests`.
