---
updated: 2026-09-04
tags: [now, punto-de-retomada]
---

# NOW — 2026-09-04 (Lima)

**Rama** `2.1` · HEAD al día tras el borrado del recorrido muerto y el arreglo del rechazado. TestFlight build **12** (CPV 12). **Subida Yala (TF/store) = solo Mini.**
**`yala-app.pe` sirve la web nueva desde hoy** (PR #62 mergeado; detalle en
`Web/REVISION-WEB-UX-A11Y-2026-09-03.md`).

## El día, en dos líneas

El CI llevaba día y medio sin ejecutar un test; se arregló y salieron 16 XCUITest en rojo —ninguno
bug de la app— más el de identidad del recién llegado a un grupo. Luego la web, desplegada; y el
Panel, que para quien instale ahora arranca con cuatro secciones y cuatro widgets.

## Te espera a ti

1. **Publicar la app.** Los dos avisos de Grupos están completos en servidor y en los dos entornos;
   falta el cliente iOS. Ahora llevaría además el fix de identidad y los predeterminados del Panel.
2. **La tanda de QA: 24 tickets en 4 montajes.** Guion en **`qa/guion-tanda.md`**, sin tocar. Dos
   entraron hoy y ninguno está en el guion: `guest-decline-has-no-screen` (servidor listo y verificado
   en producción, falta verlo en la app publicada) y `rejected-member-cold-tap-does-nothing`, cuyo
   device-QA son cinco minutos: ser rechazado, matar la app, tapear un enlace nuevo, y comprobar que
   al admin le llega la solicitud **una sola vez**. **En el mismo montaje entra ahora
   `rejoin-tap-renotifies-admins`** (servidor ya en producción): con la solicitud pendiente, tocar el
   enlace tres veces más y comprobar que al admin **no le llega nada nuevo**. El tercero,
   `groups-equal-split-shows-not-participating-on-peer`, necesita la precondición correcta: **B se une
   por enlace y NO relanza la app** antes de que A cree el gasto — sin eso no reproduce.
3. **Dos decisiones de la web** (§9 del informe): el **texto legal de Grupos** —dice «vía iCloud, no
   por servidores nuestros» y el backend propio está al 100 % en prod— y si Vercel debe desplegar al
   mergear (hoy su rama de producción es `1.0`).

## Abiertos, por prioridad

Revisados los 7 `in-progress` uno a uno el 2026-09-04, verificando contra el árbol lo que cada
ticket afirma. Hallazgo: **ninguno esperaba una decisión tuya** — la tanda del 3-sep las cerró
todas. Tres salieron ese día (dos en el saneamiento, `guest-journey` al ejecutarse); **quedan 4, y
los 4 esperan código**. De los dos de `backlog` que se listaban aquí,
**`rejoin-tap-renotifies-admins` se cerró la noche del 4-sep** —migración + Worker, los dos en
producción— y pasa a `qa/`; queda el otro.

- **`group-joiner-flag-consumers-still-narrow`** (high, en `backlog`) — al recién llegado ya se le
  reconoce, pero su gasto no llega a su cuenta personal hasta un arranque posterior y aterriza en la
  cuenta «Grupos». Trece consumidores del flag siguen estrechos.
- **`invite-link-five-causes-one-message`** — piezas 2, 3 y 4 son código. Sin tocar. Su pieza 2
  (cablear `branded`) se dejó aquí a propósito al podar el recorrido del invitado: la medición a
  fondo vive en este ticket y duplicarla era la forma segura de divergir.
- **`secondary-visitor-writes-owner-domain`** y **`secondary-guest-exit-lock-and-outbox`** — las
  decisiones del 3-sep están tomadas y **el código aprobado no está escrito**. Alcance real hoy: cero
  (SECONDARY_SESSION al 0 % en prod), pero bloquean el encendido.
- **`reentry-counts-as-fresh-install`** — parado por falta de tiempo, no por bloqueo. Su área lleva
  22 días sin un commit.
- Los **2 de `blocked`** esperan **hardware**, no trabajo.

**Al retomar cualquiera: las coordenadas de los tickets están sistemáticamente caducadas** (en uno,
14 de ~20, y dos aterrizan hoy en código no relacionado). Greppea, no abras la línea citada.

## Release 2.1 (sin cambios)

2.0.5 no se lanza; release = 2.1. A7 y M5: **HOLD, no flip**. Prod: CLOUD_MODE 100 · GROUPS_BACKEND
100 · CLOUD_ONBOARDING_CHOICE 0 · SECONDARY_SESSION 0. Cola C: 9 ACs owner/device, no corrida; D-R1
sigue sin `ok_`. **Cero `ok_` inventado.**

## Board

100 tickets · backlog 48 · in-progress 4 · qa 25 · blocked 2 · done 16 · discarded 5. Índice cuadrado
(100 filas = 100 ficheros, status y ruta de cada fila comprobados contra el disco). `qa` significa
«esperando la tanda», no «cerrado».

**Arreglado el re-tap que renotificaba al admin, y pasa a la tanda (`qa`).** Quien esperaba aprobación
y volvía a tocar su enlace despertaba al admin una vez por tap. El guardián del servidor lo prometía y
no lo cumplía: decidía por `status`, que es **ambiguo** —vale `pendingApproval` para el alta nueva y
para el no-op—, así que tapaba el caso `active` y dejaba pasar justo el del re-tap. Ahora el RPC dice
si hubo transición real (`changed`, g13_04). `rebound` no servía: dos ramas que sí son transiciones
también lo traen `false`. **Migración y Worker, los dos en producción** (`89823cc3`), medido contra el
motor real en transacción revertida. **Dos residuos deliberados:** la BD de **staging no lleva
g13_04** —no hay credencial de DDL accesible, sólo JWTs de usuario— y su Worker tampoco se desplegó,
porque arrastra dos commits ajenos; el drift es inocuo (los goldens no miran el campo y se comprobó
que pasan sin él). El conteo de push en un teléfono sigue siendo tuyo.

**Arreglado el rechazado que tapeaba en frío, y pasa a la tanda (`qa`).** A quien rechazaron de un
grupo, tapear un enlace nuevo con la app cerrada ya vuelve a pedirle la entrada — antes no hacía nada
y así se quedaba. El arreglo obvio no valía: se auto-anulaba, y su versión ingenua habría mandado
solicitudes fantasma al admin en cada arranque. La pieza que lo cierra es que «acaba de tapear» vive
en memoria del proceso y nunca en disco. **Falta verlo en un teléfono**: la cadena está medida en
código y fijada por tests (verificados por mutación), no observada. Alcance real: sólo `rejected` —
a `left` y `removed` el servidor no les baja la fila, a propósito.

**Cerrado el recorrido muerto del invitado (`4f01484e` + el commit del pin).** Para el usuario no
cambia nada: era código que ningún camino podía alcanzar. Se fueron `GroupReconnectView` con sus
ocho modos, tres intents sin emisor, el alert de «oferta de restaurar» y el trigger `.remoteInsert`
—41 ficheros, −821 líneas—. Lo que **no** se fue, y es lo que hay que recordar: el copy
`groups.reconnect.*` en los 16 locales, porque producción lo usa por la key cruda y porque es el
texto que necesita el bug de arriba. `groups-reconnect-prune-or-rewire` se cierra con él: preguntaba
podar-o-recablear y la respuesta ya está ejecutada.

**Saneado el 2026-09-04.** `ci-verde-con-la-suite-en-rojo` → `done`: su alcance —el que tú fijaste,
hasta el paso 2— está completo y verificado; lo que quedaba fuera vive ahora en
`ci-warns-but-does-not-block` (backlog), incluido el dato que manda el orden: **no existe ningún pase
nocturno**, así que sacar la suite de UI del push la dejaría sin corrida automática.
`guest-decline-has-no-screen` → `qa`: su bloqueo declarado («falta aplicar a producción, no la veo
desde aquí») estaba **caducado y al revés** — medido hoy contra el servidor, `g13_02` está aplicada
en producción con las dos condiciones de la policy, y lo invisible es staging. Solo falta publicar el
cliente y mirarlo en la tanda. Y **el «sin rutas rotas» de ayer era falso**: el mapa de origen tenía
6 punteros a ubicaciones antiguas; corregidos.

**Del Panel, lo que vuelve a morder:** «aún no hay preferencias» se renderizaba como «enséñalo todo»,
así que los predeterminados se resuelven ahora también en LECTURA, no solo al sembrar. Y el área
`panel-dashboard-logic` cubría 20 ficheros de vistas pero ninguno de los que definen los
predeterminados: tocarlos no disparaba ni un XCUITest. Corregido.
