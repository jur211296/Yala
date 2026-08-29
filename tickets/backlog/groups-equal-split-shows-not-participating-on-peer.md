---
id: groups-equal-split-shows-not-participating-on-peer
status: backlog
priority: high
area: groups
created: 2026-08-28
updated: 2026-08-28
---

# Un gasto que A dividió mitad y mitad puede verse en B como si B no hubiera participado, y solo se actualiza cuando B fuerza el cierre de la app

Tres observaciones del mismo día y el mismo par de teléfonos, y **no** dicen lo mismo: en el primer
gasto pasó, y en las dos cosas que se hicieron después **no** pasó. El ticket registra las tres. No se
cierra con las que salieron bien.

## Observación 1 — el gasto «Test» (device, 2026-08-28, Lima)

TestFlight **2.1 build 12**. Dos teléfonos: **A** = personal (del owner), **B** = de pruebas. El
grupo **no** es nuevo: es el mismo que ya se venía usando en el device-QA de hoy.

1. En **A** se crea un gasto de grupo «Test», **20 soles**, repartido **mitad y mitad** (split
   equal).
2. En **A** el gasto se ve como corresponde: **dividido por igual**.
3. **B** tenía Yala en segundo plano. B **no** recibió aviso (ni push ni notificación local). El
   owner dice explícitamente que **eso no es el problema de este ticket** — ver «Qué NO es este
   ticket».
4. **B abre el grupo** — primera apertura, sin reiniciar la app — y en ese mismo gasto ve
   **«No participé»** (palabras del owner; el texto que hay en el árbol es «No participaste», ver
   «Medido en el árbol»).
5. El owner **fuerza el cierre** de Yala en B y **vuelve a abrir el grupo**. **Solo entonces** el
   gasto se actualiza: el «No participé» rancio desaparece.

Eso es TODO lo que hay de esta observación. No se inventa nada por encima de esto.

Los dos tiempos de este gasto:

| momento | qué se ve en B |
|---|---|
| primera apertura del grupo (app venía de segundo plano) | el gasto **como si B no participara** |
| tras force-quit + volver a abrir el grupo | el gasto **actualizado** |

## Observación 2 — contraste: un gasto posterior sí llegó bien, sin matar la app

Mismo día, **mismo grupo**, después de lo de arriba. En **A** se crea un segundo gasto compartido
**convirtiendo un borrador del Inbox** en gasto de grupo. Se revisa en **B** **sin** forzar el cierre
de la app.

**PASS del owner:** B vio el gasto con **su parte correcta**. No hizo falta matar la app ni volver a
abrirla.

Eso es TODO lo que hay de esta observación. Del segundo gasto no se anotaron importe, divisa, tipo de
reparto ni si B tenía la app en primer o segundo plano en ese momento. **No se inventa.**

## Observación 3 — contraste: una edición de importe también llegó sola

Mismo día. En **A** se **edita el importe** de un gasto de grupo que ya existía. Se revisa en **B**
**sin** forzar el cierre de la app.

**PASS del owner:** B vio el **importe nuevo**. Sin matar la app.

Eso es TODO lo que hay de esta observación. No se anotó de qué gasto se trataba (si era uno de los
dos anteriores u otro), ni el importe viejo y el nuevo, ni si la participación de B en ese gasto se
seguía viendo bien además del importe, ni en qué estado tenía B la app. **No se inventa.**

## Cuál es el defecto

**B puede enseñar el gasto como si B no hubiera participado mientras A ya lo tiene mitad y mitad, y
lo que lo refrescó fue forzar el cierre de la app y volver a entrar.**

Con las tres observaciones sobre la mesa, el defecto es **condicional, no constante**:

| | Observación 1 (gasto «Test») | Observación 2 (convertido del Inbox) | Observación 3 (edición de importe) |
|---|---|---|---|
| Qué hizo A | crear gasto de grupo, 20 soles, mitad y mitad | crear gasto convirtiendo un borrador del Inbox | **editar el importe** de un gasto ya existente |
| Qué vio B sin matar la app | **como si B no participara** | **su parte, correcta** | **el importe nuevo** |
| ¿Hizo falta force-quit? | **sí**, fue lo que lo refrescó | **no** | **no** |
| Veredicto del owner | defecto | PASS de ese gasto | PASS de esa edición |

Una de tres observaciones falló. Eso dice que **no es constante**; **no** es una medida de con qué
frecuencia pasa. Son tres cosas hechas el mismo día con el mismo par de teléfonos: sirven para
refutar un «siempre», no para estimar un «cada cuánto».

Lo que **no** es, leído contra estas observaciones (deducción del reporte, no medición de código):

- **No** es un descuadre permanente de split: no hay un reparto guardado en A y otro distinto en B
  para siempre. El paso 5 de la observación 1 demuestra que B llega al estado correcto sin que nadie
  edite el gasto.
- **No** es «nada de lo que hace A llega a B sin matar la app». Las observaciones 2 y 3 lo refutan:
  con el mismo par de teléfonos, un gasto nuevo (ese sí en el mismo grupo) y una edición de importe
  llegaron solos y a la primera.

Lo que queda: **un gasto de grupo puede quedarse en B con la versión equivocada hasta que el usuario
mata la app, y todavía no se sabe qué distingue el caso que falla de los que no.** Ese «qué
distingue» es el trabajo de este ticket, y no está resuelto aquí.

## Qué ve el usuario

B abre el grupo y lee que **no participó** en un gasto en el que sí participa. No es un número raro
que invite a dudar: es una frase que afirma con seguridad algo falso, y no viene acompañada de nada
(«cargando», «falta información») que avise de que la pantalla todavía no está segura. Si B no fuerza
el cierre de la app se queda con esa versión, y los dos teléfonos cuentan el mismo gasto de forma
distinta. Forzar el cierre de la app no es algo que un usuario sepa que tiene que hacer, ni algo que
la pantalla le sugiera.

Que no pase siempre (observaciones 2 y 3) no lo hace más leve: lo hace **menos creíble de puertas
afuera**. Un grupo en el que casi todo sale bien y de vez en cuando un gasto dice «no participaste»
es un grupo en el que ya no se puede confiar en ninguna cifra sin comprobarla en el otro teléfono. Lo
que falla de forma intermitente no se aprende a esquivar: se deja de creer entero.

## Qué NO es este ticket

- **No es el ticket de notificaciones.** B no recibió aviso, y el owner lo deja fuera a propósito. No
  convertir esto en un bug de entrega de notificaciones ni cruzarlo con el ticket de notificaciones
  de TestFlight.
- **No es un descuadre permanente de split** guardado en A vs guardado en B (ver arriba).
- **No es un número mal convertido.** El síntoma reportado es la participación, no el importe: 20
  soles, una sola divisa.
- **No es un ticket cerrado.** Los PASS de las observaciones 2 y 3 son PASS **de ese gasto** y **de
  esa edición**, no del ticket. Los casos que salen bien no cierran el que salió mal: sigue en
  `backlog`.

## Lo que este ticket NO decide

Este ticket **no** declara causa raíz. En concreto, no afirma ninguna de estas:

- que sea un problema de identidad ni de a qué miembro se resuelve B,
- que el share de B no viaje por el canal («que falte en el cable»),
- que sea FX o conversión de moneda,
- que sea **solo** refresco de UI,
- que sea **solo** aplicación tardía del share en B.

Y con las observaciones 2 y 3 encima, tampoco afirma:

- que la **vía de creación** sea lo que distingue los casos (gasto de grupo directo vs convertir un
  borrador del Inbox). Es **una** diferencia anotada, no la causa.
- que el force-quit de la observación 1 dejara a B «arreglado» para lo que viniera después. Es otra
  diferencia anotada: las observaciones 2 y 3 se revisaron después de esa relanzada.
- que la diferencia esté en **crear vs editar** un gasto.
- que **los importes viajen y las participaciones no**. La observación 1 no cuadraba en la
  participación y la 3 cuadraba en el importe, pero de la 1 no se anotó qué importe enseñaba B ni de
  la 3 si la participación se seguía viendo bien: son dos observaciones incompletas, no un contraste
  limpio entre dos tipos de dato.

Las diferencias entre las corridas van listadas **sin orden de sospecha**. Nombrarlas no es
elegirlas. El force-quit de la observación 1 prueba una cosa y solo una: el estado correcto **era
alcanzable** en B sin editar el gasto. No descarta nada más. Quien retome esto mide primero y escribe
la causa con evidencia de device (o con un repro), no a partir de la lectura de este párrafo.

## Medido en el árbol

Todo lo de esta sección está medido sobre `2.1` @ `2175e53e` — el árbol en el que se escribe el
ticket, **no** el build 12 del device. Si al retomarlo el árbol ya no es ese commit, re-medir: es un
grep, y en este repo la documentación envejece más rápido que el código.

**Nada de esto prueba la causa de ninguna de las tres observaciones.** Son coordenadas para quien
retome, no veredicto.

- El texto que vio B es la key `groups.expense.notIncluded`, y en español dice **«No participaste»**:
  `Yala/Resources/es-419.lproj/Localizable.strings:3121` (igual en `es`, `es-ES`, `es-AR`). El owner
  lo citó como «No participé»: misma caption, palabras del owner.
- Se pinta en dos sitios distintos, y cada uno resuelve la perspectiva por su cuenta:
  - **fila del feed** — `Yala/App/Views/Groups/GroupRecordsView.swift:234-238` resuelve, y la caption
    la pone `Yala/App/Views/Shared/GroupExpenseAmountView.swift:49` (el importe, `:39-40`, queda en
    `EmptyView`). El mapa de shares le baja desde `GroupDetailView.swift:412`.
  - **detalle del gasto** — `Yala/App/Views/Groups/GroupExpenseDetailSheet.swift:103-109` resuelve y
    `:283-288` pinta la fila «tu parte» con esa caption. El share le entra desde
    `GroupDetailView.swift:287`.

  **No se anotó en cuál de los dos lo vio B.**
- La caption sale de `PersonalShareStatus.notIncluded`, y en
  `Yala/App/Logic/GroupExpenseAmountResolver.swift:36-41` ese caso exige **dos** condiciones a la
  vez: que el current member **no** sea el pagador **y** que no haya `SplitShare` suyo para ese
  gasto. El pagador nunca cae en `notIncluded` (`:36-38`).
- El `share` que recibe ese resolver sale del mapa `mySharesByExpense`, que se arma en
  `Yala/App/ViewModels/GroupDetailViewModel.swift:306-314` filtrando `shares` por `currentMemberID`.

**Medido:** los ficheros, las líneas, el texto de la caption, y que `notIncluded` exige esas dos
condiciones juntas. **Ni medido ni inferido aquí:** cuál de las dos condiciones se cumplía en B en la
primera apertura, ni por qué.

## Qué falta del device (pendiente owner)

De la observación 1:

- Si B lo vio en la fila del feed, en el detalle del gasto, o en los dos.
- Cuánto tiempo pasó entre la creación en A y la primera apertura en B, y cuánto hasta el force-quit.
- Qué monto enseñaba el gasto en B en esa primera apertura (el total, cero, o ninguno).
- Si el resto de la pantalla de grupo (balances, deudas, lista de miembros) se veía bien en B en esa
  primera apertura.
- Cuántos miembros tenía el grupo en esa corrida y quiénes eran los dos lados de la «mitad».
- Si B ya era miembro aprobado de antes (el grupo venía usándose hoy) o si seguía en algún estado
  pendiente en esa corrida.
- Si tras el force-quit el gasto quedó bien **de forma estable**, o si volvió a torcerse.

De la observación 2 (hace falta para poder comparar, que es el trabajo del ticket):

- Importe, divisa y tipo de reparto del gasto convertido.
- Si B tenía la app en primer plano, en segundo plano, o cerrada-no-matada cuando se revisó.
- Cuánto tiempo pasó entre la conversión en A y la revisión en B.
- Si B seguía en la misma sesión de app que arrancó con el force-quit de la observación 1, o si hubo
  otra relanzada en medio.
- Si B estaba dentro del grupo en ese momento o entró desde fuera.

De la observación 3:

- En qué grupo fue, y de qué gasto se editó el importe: uno de los dos anteriores, o un tercero.
- Importe viejo e importe nuevo.
- Si además del importe la **participación** de B en ese gasto se seguía viendo bien (es lo que
  falló en la observación 1, y de la 3 no se anotó).
- En qué estado tenía B la app y cuánto tardó en verse el cambio.

Sin esto no hay repro cerrado ni comparación limpia. No inventar los valores.

## Distinto de

Ids citados sin afirmar su status: hay movimientos en vuelo y el índice se mide, no se recuerda.

- `group-notif-credits-payer-not-editor` — a quién atribuye la notificación. Aquí no hay
  notificación de por medio.
- `groups-approval-banner-stays` — un aviso que se queda puesto después de aprobar. Otra pantalla y
  otro estado, aunque también sea algo rancio que no se retira.
- `groups-background-emitter-no-upload` — el emisor en segundo plano no sube. Aquí el gasto **sí**
  estaba en la lista de B en la primera apertura; lo que no cuadraba era la participación.
- `groups-ghost-tx-on-delete` — espejo que sobrevive a un borrado. Otro sentido: borrado, no
  creación.
- `inbox-convert-draft-to-group-expense` — la vía por la que se creó el gasto de la observación 2.
  Se cita porque es el camino que se usó, **no** como culpable ni como sospechoso: la observación 2
  es justamente la que salió bien.
- `distribution-balance-kpi-skips-fx` y `fx-partial-rate-rows-silent-1to1` — familia de números y
  FX. Este no es un importe mal convertido.

## HOLD

- Status sigue `backlog`. **Sin implementación: cero Swift en este ticket.**
- **No cerrar el ticket con las observaciones 2 y 3.** Esos PASS son de un gasto y de una edición, no
  del ticket.
- No inventar PASS ni `ok_`.
- A7 / M5 siguen en HOLD, sin flip (`docs/ESTADO.md`). Sin subida a TestFlight, sin tag, sin store.
- Sin tocar `qa/coverage-index.json` en el alta: no hay código nuevo bajo `Yala/`.

## Acceptance Criteria

- [ ] Repro escrito con dos teléfonos: A crea un gasto equal en un grupo que B ya conoce y tiene en
      segundo plano, y B abre el grupo **sin** forzar el cierre de la app.
- [ ] En esa primera apertura, B ve su parte del gasto — no «No participaste» — o, si de verdad no
      participa, la pantalla no contradice a A.
- [ ] B no necesita matar la app para llegar al estado correcto.
- [ ] La causa se escribe con evidencia (device o repro), no a partir de este ticket. Si resulta ser
      más de una, el ticket se parte entonces, no antes.
- [ ] La causa que se escriba **explica las tres observaciones**: por qué el gasto «Test» se quedó
      rancio en B, y por qué el gasto convertido del Inbox y la edición de importe llegaron bien a la
      primera. Una explicación que solo cubra la que falló no cierra este ticket.
- [ ] Si se confirma que el estado correcto tarda en llegar, la pantalla no afirma «No participaste»
      mientras no lo sabe (copy por definir; leer `docs/planning/BRAND-VOICE.md`).
- [ ] Device-QA en los dos teléfonos. No inventar PASS.
