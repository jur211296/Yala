# Grupos e iCloud: gastos de grupo atascados en la Bandeja, alta de Grupos a medias y movimientos de grupo sin cuenta

## Contexto
Sesión agrupada de 2.1 que junta tres cards del mismo tema: filas de grupo que, tras pasar por iCloud o por borrados, quedan sin el grupo o la cuenta que las explican. Las tres tienen su ticket en tickets/backlog/ de origin/2.1; léelos enteros antes de empezar.

(a) Card tablero-los-gastos-de-grupo-que-llegan-de-icloud-kfjr (2.1, media). Ticket: tickets/backlog/prior-icloud-group-records-summed-without-their-group.md
«Los gastos de grupo que llegan de iCloud sin su grupo no se pueden quitar de la Bandeja».
- Origen: la decisión de 4nt6. Al volver a iCloud y elegir «Sumarlos a mis datos», las filas de grupo ajenas se suman tal cual, porque en iCloud pueden ser de otro dispositivo con ese Apple ID que sí tiene esos grupos.
- El problema: los borradores `.groupExpense` no se pueden descartar (`DraftSourceType.blocksInboxDismissal`), y `OrphanedBridgedTxSweeper` solo mira zonas del canal backend que este teléfono conoce.
- Hecha cuando: tras sumar los datos de antes, la persona puede quitar de la Bandeja los gastos de grupo que no sabe explicar, y el otro dispositivo con esos grupos no pierde nada. Cualquier borrado local viaja por el espejo, así que la salida no puede quitarle nada al otro dispositivo. La idea del ticket es dejar descartar un borrador de grupo cuando su grupo no existe aquí y el canal de grupos está al día. Al cerrar, cierra el ticket.

(b) Card tablero-un-alta-de-grupos-a-medias-llega-al-avis-dzih (2.1, media). Ticket: tickets/backlog/groups-entry-left-half-done-reaches-the-private-gate-with-group-rows.md. Salió en el PR #470.
«Un alta de Grupos a medias llega al aviso de privado con filas de grupo».
- El camino: alguien entra con una cuenta de solo grupos, deja el alta a medias, vuelve a «Es mi primera vez → iCloud privado» y la puerta le dice «Ya hay datos en este teléfono» con sus propios grupos.
- Está inferido del código y sin reproducir. Primero reprodúcelo en el simulador (o con un UITest o un test de lógica).
- El ticket ofrece tres opciones:
  - A: cerrar la sesión al abandonar el alta, o no arrancar el canal de Grupos sin onboarding.
  - B: que la puerta privada no cuente como ajenos los grupos de la sesión viva.
  - C: aceptarlo.
- Si no se reproduce, documéntalo con la evidencia y propón C.

(c) Card tablero-los-movimientos-de-grupo-que-se-quedaron-cy2h (2.1, baja). Ticket: tickets/backlog/orphaned-group-records-stay-out-of-the-notice.md. Es el residual del PR #520 (aviso «Movimientos sin cuenta»).
- Una pata REAL de grupo que quedó sin cuenta no sale en el aviso.
- El caso contrario, inferido por la review adversarial: `GroupsAssociationDetach.action(for:)` y `OrphanedBridgedTxSweeper.decide` tratan `account == nil` como cuenta real. Una pata VIRTUAL con su cuenta de sistema sin hidratar puede soltar el puntero, aparecer en el aviso y, al moverla, contar dos veces.
- Hecha cuando: una pata real de grupo sin cuenta sale en el aviso (o en otra salida) y se puede devolver a una cuenta sin convertir en real una pata virtual.

Decisiones de producto: si una de estas cards necesita elegir entre opciones, elige la que no pierde datos de nadie, sobre todo del otro dispositivo o del otro miembro del grupo, y que sea reversible. Documenta en el PR y en el ticket qué elegiste y por qué. Las tres cards tocan el puente de grupos (OrphanedBridgedTxSweeper, BridgedEditPolicy, Bandeja); mira si una sola regla de «fila de grupo sin grupo o sin cuenta» las resuelve juntas antes de hacer tres arreglos.

## Qué se pide
1. Medir o reproducir cada caso con tests (de lógica, de servicio o UITest) antes de arreglarlo.
2. Arreglar (a), (b) y (c), con tests que fallen antes y pasen después. Si lo ves conveniente, una review adversarial del puente.
3. Mover los tickets a su estado (done, o qa si necesitan iPhone real) y actualizar docs/TICKETS.md.
4. Uno o varios PR a 2.1, con capturas de antes y después en _capturas/ cuando haya cambio visible (Bandeja, aviso del Panel, puerta privada).

## Cómo trabajar
- Pipeline serial con 1 simulador, como manda la norma de la Mini (16 GB):
  1. limpiar sims muertos, DerivedData de sesiones cerradas y cachés de XcodeBuildMCP de worktrees que ya no existen
  2. build con `xcodebuild -jobs 2` sin ningún simulador encendido
  3. encender 1 simulador
  4. tests
  5. apagar ese simulador y borrarle los datos
  No compiles con un simulador encendido ni corras tests mientras compila. Si creas un simulador propio, bórralo al cerrar: solo deben quedar «iPhone 17 Pro» y «iPad Pro 11-inch (M5)», apagados.
- Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees retirados. No toques los de otra sesión viva.
- Gate después del CI del PR anterior: la sesión arranca ya, sobre origin/2.1. El PR #521 (ficha en/pt-BR) puede seguir en auto-merge. Justo antes del gate, mira si sigue en CI: si sigue, espera a que entre y rebasa una sola vez con el simulador apagado. Si 2.1 no se movió, sigue de frente. Si ese CI falla, no esperes: rebasa con lo que haya y sigue. El build y el simulador van después de ese rebase, una sola vez.
- Pruébala tú misma todo lo que se pueda, con simulador, tests y capturas, según /barrido-qa. Solo lo que de verdad necesite un iPhone real (dos dispositivos con el mismo Apple ID, iCloud real) pasa a «in qa» para jurgen, con un guion corto de 3 a 5 pasos en el siguiente paso de la card. Lo demás va a «done» con evidencia: PR, tests y capturas.
- Cada ticket nuevo que añadas a docs/TICKETS.md lleva su card en el tablero: créala con `tablero crear --proyecto yala ... --agente frank`, o enlaza una que ya exista. Versión 2.1 si es de borrados, sync o datos del usuario; 2.2 si no es importante para el lanzamiento.
- Antes de cada PR: `git fetch origin && git rebase origin/2.1`. No esperes al CI para seguir.

## Qué NO hay que tocar
- En el árbol principal ~/Yala hay cambios sin commitear en «Cloudkit Schemas/yala_dev-development.ckdb», «Cloudkit Schemas/yala_dev-production.ckdb» y Yala.xcodeproj/xcshareddata/xcschemes/Yala.xcscheme. No los toques, no los commitees y no los descartes.
- Nada de esquema de CloudKit en Production ni de despliegues de backend o gateway a prod.
- No toques sesiones tmux salud--* ni sat-lab--*.

## Cómo se sabe que está bien
- (a): un gasto de grupo sin su grupo se puede quitar de la Bandeja en este teléfono, y un test demuestra que no se borra nada que el otro dispositivo necesite.
- (b): reproducido y arreglado con la opción elegida, o justificado con evidencia como no alcanzable.
- (c): una pata real de grupo sin cuenta se puede devolver a una cuenta, y una pata virtual nunca se convierte en real (sin doble conteo), con tests de los dos lados.
- PR a 2.1 rebasado sobre origin/2.1, con tests en verde en local. Tickets y cards al día: done con evidencia, o in qa para jurgen con guion solo por lo que necesite iPhone real. Tickets nuevos con su card.
- Al terminar, ciérrate sola con /cerrar-total: simulador apagado y borrado, DerivedData de la sesión borrado y worktree retirado si el PR ya entró. Solo para si hace falta una validación URGENTE de Jürgen.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**Hechos medidos antes de decidir (árbol `2e82c374c`):**
- `OrphanedBridgedTxSweeper.decide`, `GroupsAssociationDetach.action` y `LegacyGroupsRetirement.decide` delegan en `classifyForSoftDelete(transactionAccountIsSystem:)` con `tx.account?.isSystemAccount == true`: sin cuenta = REAL → sueltan punteros. Tres tests lo fijan como contrato (`sinCuentaEsReal`, `txWithoutAccount_countsAsReal`, `retire_txWithoutAccount_isReleasedNotDeleted`).
- El freeze (`computeFreezePlan`) y el propio puente (`bridgeExpense`, `existingRealTx`/`existingVirtualTxs`) ignoran una fila sin cuenta: ni la sueltan ni la borran.
- Pata REAL de gasto = `-total` en la divisa del gasto y solo si pagué yo (Caso A). Virtuales: préstamo `+prestado` (subcat sistema), `-miParte` (subcat nil/usuario), saldos iniciales (subcat sistema). Liquidación: la real (Caso C) lleva la subcat de sistema «Liquidación enviada»; las virtuales, «Pago de liquidación»/«Cobro de préstamo».
- La subcategoría de sistema se reconoce solo por NOMBRE en todos los idiomas (`GroupBridgeSystemEntities`, no hay campo de rol).
- Los borradores `.groupExpense` viajan por el espejo (iCloud) y por el canal personal de la nube; rechazarlos o borrarlos cambia la fila en el otro dispositivo, y en el Caso A su `[.account]` es lo único que crea allí la pata real.

**D1 · ¿Una regla común para las tres cards?** → Sí para (a) y (c): «una fila de grupo solo se toca con lo que se puede PROBAR aquí». (c) la aplica a la cuenta (real/virtual/no se sabe, `GroupLegKindLogic`, compartida por barredor, desasociar, retirada de legacy y aviso); (a) la aplica al grupo (si el grupo no existe aquí, la salida es local). (b) es otra cosa (la puerta privada del Welcome) y va aparte.
Por qué: los cuatro sitios resolvían la misma duda cada uno a su manera, que es el bug. Alternativa descartada: tres parches locales.

**D2 · (c) ¿Cómo se distingue una pata real de una virtual sin cuenta?** → Con cuenta manda la cuenta. Sin cuenta: virtual si su subcat es de sistema y no es «Liquidación enviada»; real si es «Liquidación enviada» en una liquidación, o si el gasto sigue aquí, lo pagué yo, no es saldo inicial, no hay otra pata real y la fila vale exactamente `-total` en la divisa del gasto; si no, «no se sabe».
Por qué: es la forma exacta que el puente le da a la pata real; la única virtual con el mismo importe (`-miParte` = total, sin préstamo) deja el mismo neto, así que no hay doble conteo posible. Alternativa descartada: heurística por importe sin mirar el gasto (confunde `-miParte` con la real cuando pagó otro).

**D3 · (c) ¿Qué hacen barredor, desasociar y retirada con un «no se sabe»?** → No tocan la fila (sin soltar ni borrar). Con «virtual» sin cuenta, borran como con una virtual hidratada; con «real», sueltan como siempre.
Por qué: soltar es lo que la mete en el aviso como movible; no tocarla la deja como hace ya el freeze, y el editor ya ofrece su salida cuando el puntero no resuelve. Alternativa descartada: soltar «por si acaso es real» (es justo el doble conteo de la review).

**D4 · (c) ¿Dónde sale la pata real sin cuenta?** → En el mismo aviso «Movimientos sin cuenta», solo las PROBADAS reales. Al moverlas conservan sus punteros (siguen siendo la pata real del gasto, el puente las reconoce) y no se convierten de divisa (`AccountRemovalLogic.rowConverts` ya las bloquea: pasan en su moneda).
Por qué: es la salida que la persona ya conoce y el ticket pide. Alternativa descartada: soltar los punteros al mover (el siguiente re-puente crearía otra pata real: doble conteo).

**D5 · (a) ¿Qué es «quitar de la Bandeja» un gasto de grupo sin su grupo?** → Ocultarlo SOLO en este teléfono: una lista local (UserDefaults, no viaja por iCloud ni por la nube) de `splitExpenseID` ocultos. No cambia ninguna fila de SwiftData. Se ofrece solo con el borrador `.groupExpense` pendiente cuyo grupo no existe aquí (ni `SplitGroup` de su zona ni su `SplitExpense`), y deja de ocultarse solo si el grupo llega.
Por qué: rechazar o borrar viaja por el espejo y en el otro dispositivo se llevaría la pregunta de «¿de qué cuenta?» que crea su pata real. La lista local es reversible y no le quita nada a nadie. Alternativa descartada: rechazar/borrar con un gate de frescura (sigue viajando).

**D6 · (a) ¿Hace falta el gate de frescura del canal de grupos?** → No. Es reversible: si el grupo aún estaba bajando, al llegar el borrador vuelve a salir.
Por qué: el gate existe para acciones que destruyen o mutan filas sincronizadas; esta no escribe ninguna. Alternativa descartada: exigir canal al día (deja fuera para siempre a quien no tiene sesión de Grupos, que es la población del ticket).

**D7 · (a) ¿Clave del oculto?** → El `splitExpenseID`, no el borrador.
Por qué: el otro dispositivo re-puentea y crea borradores nuevos del mismo gasto que bajan por el espejo; con la clave del borrador volverían a salir. Se retira con los demás datos de la persona (`DataWipeService`).

**D8 · (b) ¿Se reproduce?** → Alcanzable con condiciones, medido por traza (citas en el PR): `onEnterGroupsOnly` deja la sesión viva y ninguna salida atrás la cierra ni purga Grupos; el canal arranca sin mirar el onboarding (`GroupsLoopRestartLogic.shouldStart`), y en este recorrido lo arranca la vuelta a primer plano (inferido); con el montaje neutro de una instalación nueva la puerta cuenta TODOS los `SplitGroup` (`readWelcomeDeviceDataForTheGate`) y da «Ya hay datos». Peor que el ticket: su «Borrar» usa el alcance de traspaso, que purga y SELLA el dominio de Grupos de la propia persona y retira su sesión. El camino real no se puede conducir en el simulador (montaje nunca neutro bajo XCUITest; el seam de lectura finge la lectura entera), así que se reproduce con un test de la cadena de decisiones.

**D9b · (b) ¿Qué opción?** → B, con la pieza que ya existe: `onEnterGroupsOnly` escribe `LateNoticeKeptGroupsMark` atada a la sesión que la persona acaba de abrir, **solo si la sesión la abrió ese intento (`sessionOpenedHere`) y en ese instante el teléfono no tiene ningún `SplitGroup`**. Con eso, lo que el canal baje después es de ella, y todos los lectores de esa marca (la puerta, la alerta de «Empezar de cero», el borrado del teléfono, el portal del relanzamiento) dejan de tratarlo como de otra persona. La marca muere al completar el onboarding y la invalida otra cuenta.
Por qué: no pierde datos de nadie y es reversible (sin marca, todo vuelve a ser como hoy). A (cerrar la sesión al abandonar, o no arrancar el canal sin onboarding) rompe la unión por invitación —que necesita el canal antes del onboarding— y obliga a volver a firmar; C deja el borrado que sella los grupos propios. La condición «sin grupos en ese instante» es la que impide que una sesión de una persona anterior (sobrevive a una reinstalación en el llavero) haga pasar sus grupos por los de quien entra.

**D11 · Review adversarial (3 lentes) — qué se cambió por ella.** (1) Mover una pata real de gasto re-puentea su gasto: retira el borrador «¿de qué cuenta?» que dejó un re-puente anterior (aprobarlo creaba una segunda pata real) y rehace las virtuales. (2) La pata real de una liquidación solo se prueba si no hay un borrador pendiente suyo (re-puentear una liquidación borraría la pata movida). (3) La marca de (b) exige `sessionOpenedHere`: el Welcome reutiliza una sesión del llavero sin pedir nada, y tras reinstalar puede ser de la persona anterior. (4) Lo que el desasociar deja intacto entra en el libro de conservados (si no, re-asociar la cuenta lo duplicaba). (5) El banner del editor no manda a la Bandeja a buscar un borrador oculto. (6) «Quitar de aquí» sin deslizamiento completo. (7) Nota propia para las patas de grupo que pasan en su moneda. (8) Lecturas más baratas en el Panel y la Bandeja. Residuales: si la sesión de (b) se va sin borrado, «sin sesión» sigue dando la marca por buena (semántica heredada); una fila sin cuenta y sin prueba se queda tal cual y su salida es el editor, que no distingue real de virtual (camino anterior al cambio).

**D12 · Rojo ajeno destapado en el gate.** `SpikeR3ContainerReleaseTests` eje 4a caía en la suite completa con las suites nuevas: contaba los descriptores del store en el mismo instante en que moría el container, y Core Data los cierra en su cola un momento después («release verificado en 0 ms · descriptores 3»). Verde aislado 3/3 y sin las suites nuevas; la carga lo destapaba. Arreglo en el harness (DEBUG): espera acotada (2 s) a que se cierren; el release verificado sigue exigiendo cero descriptores antes de borrar.

**D9 · Entrega** → Un solo PR (las tres cards comparten el puente y la evidencia). Device-QA en iPhone solo para lo que pide iCloud real con dos dispositivos.

**D10 · Limpieza del entorno** → DerivedData de esta sesión en `/Volumes/ExtDev/DerivedData/Yala-grupos-icloud` (se borra al cerrar). Las cachés de XcodeBuildMCP de otros proyectos no se tocan: no son de un worktree de Yala retirado.
