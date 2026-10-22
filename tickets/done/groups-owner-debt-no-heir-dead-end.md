---
id: groups-owner-debt-no-heir-dead-end
status: done
priority: high
area: groups
created: 2026-09-06
source: review adversarial de groups-owner-transfer-and-leave (2026-09-06)
updated: 2026-09-08
qa-status: passed
qa-date: 2026-09-08
---

# El dueño con deuda y SIN heredero sigue sin salida

## Qué le pasa al usuario

Soy el dueño de un grupo, hay saldos pendientes y **no hay nadie a quien cederle el grupo**. Entonces:

- **«Salir»** no se me ofrece — el servidor lo rechaza con `yala_owner_cannot_leave`.
- **«Transferir y salir»** no se me ofrece — no hay heredero elegible.
- **«Eliminar»** está deshabilitado — hay deuda en el grupo.

Las tres salidas cerradas. La app me lo dice con honestidad («hay saldos pendientes en el grupo»),
pero no me da nada que hacer.

## Cómo se llega ahí (tres caminos, los tres alcanzables)

Medido en la tabla de verdad de `GroupOwnerExitLogic.offer` durante la review de
[[groups-owner-transfer-and-leave]]:

1. **Único miembro activo, con saldo vivo de alguien que ya se fue.** `recomputeOutstandingDebt`
   fetcha **todos** los miembros de la zona sin filtrar por `isActive`, y
   `GroupBalanceService.calculateBalances` construye sus claves desde los mapas `paid`/`owes`, no
   desde el array de miembros ⇒ un miembro que salió con saldo sigue produciendo `netBalance ≠ 0`.
2. **Canal CloudKit-legacy.** Hay co-miembros de sobra, pero CKShare no sabe ceder ownership.
3. **Co-miembros sin cuenta** (`user_id NULL`): grupo migrado y no reclamado. No hay `auth.user` al
   que ceder.

## Por qué NO se resolvió en el ticket que lo destapó

La decisión de Jürgen del 2026-09-06 fue «Transferir y salir», y **descartó explícitamente** permitir
eliminar con deuda («borra deudas de terceros, es irreversible»). Esa decisión cubre el caso con
heredero y deja esta celda fuera. Inventar aquí una cuarta salida sería decidir por él.

## Salidas posibles (para que elija, no recomendación cerrada)

- **(a) Dejarlo como está.** El hint es honesto y el caso es raro. Coste cero, y el dueño sigue
  atrapado.
- **(b) Permitir eliminar cuando la deuda es SOLO con miembros inactivos.** Ataca el camino 1, que es
  el más probable de los tres, sin tocar el principio que Jürgen protegió (nadie pierde una deuda
  viva con alguien que sigue en el grupo). Requiere separar «deuda del grupo» de «deuda entre
  miembros activos» — hoy el bloqueo mira todos los saldos sin distinguir.
- **(c) Ofrecer archivar como salida.** «Archivar» ya funciona con deuda y hoy está en la pantalla;
  no le saca del grupo, pero se lo quita de la lista. Es la salida más barata y la menos completa.
- **(d) Ofrecer liquidar desde aquí.** Un atajo a la pantalla de saldos. No desbloquea nada por sí
  solo si la deuda es entre terceros.

## Criterio de hecho (AC)

- [ ] Decisión de Jürgen escrita en este ticket.
- [ ] Si la decisión cambia el bloqueo, `GroupOwnerExitLogic` gana el caso y su test.
- [ ] Copy en 16 `.lproj` si aparece texto nuevo.

## Relacionados

- [[groups-owner-transfer-and-leave]] — el ticket que lo destapó y cubre la celda CON heredero.
- [[groups-leave-rpc-error-10]] — el abuelo: el callejón original del dueño.


---

## Para decidir — preparado el 2026-09-08

**La pregunta, en una línea:** al dueño con deuda y sin heredero, ¿le damos una salida, y cuál?

### Lo que medí hoy, y que cambia una de las opciones

La tabla de verdad del ticket es **exacta**: `GroupOwnerExitLogic.swift:89-113`. Para el dueño,
`showsLeave` es siempre `false`, `showsTransferAndLeave` exige `eligibleHeirCount >= 1` (`:99-102`) y
`deleteEnabled = !groupHasOutstandingDebt` (`:109`). Con deuda y sin heredero, las tres cerradas.
Confirmado también el camino 1: `GroupSettingsView.swift:1011-1013` fetcha los `SplitMember` **solo
por `groupZoneID`, sin filtrar por `isActive`**.

**Pero la opción (b), tal como está enunciada arriba, no funciona.** Y esto es lo que hay que saber
antes de elegirla:

> **Los netos suman cero por moneda.** El bloqueo se calcula en `GroupSettingsView.swift:1020` como
> `balances.contains { abs($0.netBalance) > 0.01 }`. Si el que se fue debe 50, el **dueño activo
> tiene +50** — así que «quedarse solo con los balances de miembros activos» **sigue bloqueando**,
> porque el activo es justamente el otro extremo de esa deuda.

Para expresar «deuda solo con gente que ya no está» hay que **cambiar de métrica**: pasar de netos a
**pares** (`GroupBalanceService.calculateBalances:102` construye las claves desde
`Set(paid.keys).union(owes.keys)`; lo que haría falta es `calculateDebts:126` y el tipo `Debt`) y
exigir que ninguna pareja tenga los dos extremos activos. Eso no es un filtro: es un criterio nuevo.

**Y la opción (c) es mucho más barata de lo que el ticket sugiere, porque ya está construida.**
«Archivar» **ya vive en esta misma pantalla** (`GroupSettingsView.swift:157-159`, sección
`:773-792`), **ya funciona con deuda** — solo añade el confirm `archiveWithDebtWarning` (`:239`) — y
está pintada **antes** que transferir y eliminar (`:161-171`). Lo único que falta es que el hint del
callejón la mencione: hoy dice «hay saldos pendientes» y se calla la salida que sí tiene delante.

### Las opciones, con su coste medido

| | Qué le das al dueño | Coste medido |
|---|---|---|
| **(a)** nada, hint honesto | sigue atrapado | 0 |
| **(b)** eliminar si la deuda es solo con inactivos | sale de verdad | **4-5 ficheros + métrica nueva** (netos → pares) + 2 claves × 16 `.lproj` |
| **(c)** ofrecer archivar | se lo quita de la lista, no sale | **2 ficheros + 1-2 claves × 16 `.lproj`** — la funcionalidad ya existe |
| **(d)** atajo a liquidar | no desbloquea si la deuda es entre terceros | 1 fichero + 1 clave × 16 |

### Mi recomendación: **(c) ahora**, y (b) solo si aparece demanda real

Tres motivos, en orden de peso:

1. **Hoy el hint miente por omisión.** Le dice al dueño que no puede hacer nada, teniendo «Archivar»
   dos secciones más arriba, funcionando y con su propio aviso de deuda. Eso no es una feature nueva:
   es dejar de esconder la que hay.
2. **(b) cuesta una métrica nueva sobre el cálculo de saldos de Grupos**, que es justo el terreno
   donde un error sale caro — y el ticket lo pedía creyendo que era un filtro. Gastar eso en un caso
   del que no tenemos ni un reporte real no se sostiene.
3. **(c) no cierra la puerta a (b).** Archivar no borra deuda de nadie, así que no toca el principio
   que protegiste el 6-sep. Si mañana aparece un dueño atrapado de verdad, (b) sigue disponible y con
   el diagnóstico ya escrito.

Lo que **(c) no hace**, y conviene tenerlo delante al elegir: no le saca del grupo. Sigue siendo
dueño, sigue contando para los saldos, y si alguien le escribe seguirá recibiendo lo del grupo. Es
«quítamelo de la vista», no «sácame de aquí».

### Si eliges (c), el AC es

- [ ] El hint de bloqueo nombra «Archivar» como salida disponible cuando lo esté.
- [ ] La sección de Archivar queda visible/alcanzable en el mismo camino donde hoy se lee el bloqueo
      (hoy ya se pinta antes; comprobar que no queda por debajo del fold tras el cambio de copy).
- [ ] Copy nuevo en las **16** `.lproj` del target app (`Yala/Resources/*.lproj`; las otras 17 son de
      YalaShare y YalaWidgets y no llevan este texto).
- [ ] `GroupOwnerExitLogic` gana el caso en su tabla y su test.

### Si eliges (b), el AC es

- [ ] El criterio se expresa sobre **pares de deuda**, no sobre netos, y su test incluye el caso que
      hoy engaña: activo con `+50` frente a inactivo con `-50` ⇒ debe permitir eliminar.
- [ ] `recomputeOutstandingDebt` filtra por `isActive` **en memoria** (es computed sobre `status`,
      `SplitMember.swift:59`, y no es predicable en SwiftData).
- [ ] Sigue siendo imposible eliminar con deuda viva entre dos miembros **activos**.

### Decisión de Jürgen

**(c) Ofrecer Archivar.** Contestada el 2026-09-08.

**Implementada en el mismo PR.** `GroupOwnerExitLogic` gana el caso `.debtArchiveInstead` —el último
del enum, para no renumerar los que ya existían— y `Facts` gana `isArchived`, porque a un grupo ya
archivado no se le puede proponer archivarlo: ese camino conserva el hint honesto de antes, y es el
único que queda para `.debtNoTransferAvailable`.

**Prioridad del hint, de más a menos salida real:** transferir (le saca del grupo) → archivar (se lo
quita de la vista) → constatar el hecho.

**Lo que NO cambia, y era el punto:** «Eliminar» sigue bloqueado con deuda. Archivar no borra la
deuda de nadie, así que el principio que protegiste el 6-sep queda intacto — hay un test que lo fija
(`archiveHint_doesNotUnlockDelete`).

**(b) queda descartada, y con el motivo medido**, por si alguien la vuelve a proponer: los netos
suman cero por moneda, así que «eliminar si la deuda es solo con inactivos» exige cambiar de métrica
(netos → pares), no un filtro. Si el caso aparece de verdad, el diagnóstico ya está escrito arriba.

---

## QA Visual · 2026-09-08

**Veredicto: PASS.** iPhone 17 Pro (iOS 26.5), `Yala Dev`, seed `grupos`
(`-uitest -uitest-reset -uitest-skip-onboarding -uitest-pro -uitest-seed grupos -uitest-groups-consent -uitest-deeplink groups`).
Grupo **«Viaje a Cusco»** — soy dueño, 3 miembros, deuda viva (Te deben S/ 190,00 + $ 46,67).

### Lo que se vio en Ajustes del grupo

| Criterio | Resultado |
|---|---|
| Sección **«Archivar grupo»** visible y por encima | **Sí** — y es tapeable |
| **«Eliminar grupo»** deshabilitado | **Sí** — aparece en el árbol solo como texto, **no** como elemento tapeable |
| Su hint **nombra Archivar** | **Sí**, literal: «Hay saldos pendientes en el grupo. Si quieres quitártelo de la lista, **archívalo**: las deudas se conservan.» |

Que «Eliminar grupo» exista como texto pero **no** como destino tapeable es la prueba de que está
deshabilitado: el árbol de accesibilidad lista «Archivar grupo» entre los botones y a «Eliminar
grupo» no. Ya no es el hint mudo de antes: el callejón sin salida tiene salida y está nombrada.

### Por qué este corpus cae justo en la celda del ticket (medido, no supuesto)

El caso exige «dueño **con** deuda y **sin** heredero». Lo segundo sale gratis con cualquier seed, y
conviene dejarlo escrito porque no es evidente:

- `GroupService.swift:1006` — `eligibleHeirs = activeCoMembers.filter { $0.userID != nil }`
- `grep -c 'userID\|memberKey' Yala/Seed/DevSeedGroups.swift` → **0**

Ningún perfil de seed escribe `userID` ni `memberKey` en los miembros, así que `eligibleHeirCount`
es **siempre 0** y el offer del dueño cae siempre en `.debtArchiveInstead`. El escenario de este
ticket es, de hecho, el único que los seeds saben producir.

**Corolario que afecta a otro ticket:** por esa misma razón `groups-owner-transfer-and-leave` **no
es simulable hoy** — su botón «Transferir y salir» exige `eligibleHeirCount >= 1` y nunca llega a
pintarse. No es una limitación del teléfono: es el seed.

### Captura

- `qa-owner-debt-no-heir-01-hint-archivar-20260908-212100.png`

### Lo que no se cubre

No se llegó a **archivar** de verdad desde este hint (el ticket pedía la salida, no ejecutarla).
Que el archivado funcione lo cubre `groups-archived-group-rejects-join` / `archivado-no-acepta-entradas`.
