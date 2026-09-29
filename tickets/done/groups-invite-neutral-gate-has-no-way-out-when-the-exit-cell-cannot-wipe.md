---
id: groups-invite-neutral-gate-has-no-way-out-when-the-exit-cell-cannot-wipe
status: done
updated: 2026-09-29
priority: medium
area: "modo-nube, groups, onboarding"
created: 2026-09-11
source: "hallazgo de la review adversarial de `groups-invite-on-a-mirrored-store-crosses-data` (2026-09-11), lente de caminos muertos"
---

# La puerta del invitado dice «ahora no se puede» y la invitación se queda sin ninguna pantalla

## El síntoma, en lenguaje de usuario

Acepto una invitación en un teléfono que tiene datos de otra persona. La app me dice que no puede
prepararlo ahora mismo y me devuelve. Vuelvo a intentarlo y me dice lo mismo. **No hay ningún camino
por el que pueda entrar al grupo**, y tampoco nada que me explique qué tengo que hacer para que se
pueda.

## Dónde está

`WelcomeGroupsGateView.inviteNeutralEntryPhase()` devuelve `.unavailable` en dos casos, y los dos son
alcanzables:

- **La fase del coordinador no es `.idle`**: hay otro cierre de sesión en vuelo.
- **La celda de cierre no borra por archivos** (`.cloudSecureSignOut`, `.secondaryCloudSignOut`): uno
  haría un borrado distinto del que la pantalla promete y el otro ni siquiera toca el store del dueño.

La pantalla tiene una sola salida, «Volver», que lleva al chooser de Grupos. Y ahí las dos cards
tampoco sirven: «Tengo una invitación» abre `InviteRecoveryView`, que es la recuperación de un CKShare
—otro canal, no el del enlace que la persona tiene—, y «Crear mi primer grupo» no es lo que pidió.

**La invitación sigue viva** en `PendingJoinStore` (TTL 7 días) y el reconciler la re-submitea en cada
`.foreground`, así que el resultado es un bucle: la misma pantalla, la misma salida, el mismo sitio.

## Lo que este ticket NO es

No es «la puerta bloquea mal». La puerta hace lo correcto al no arrancar un borrado que su celda no
puede hacer — eso es el arreglo de la sesión anterior, no un defecto. Lo que falta es **qué se le
ofrece a la persona** cuando ese «no se puede» es el estado estable.

## Por dónde puede ir

1. **Decir POR QUÉ y qué hacer.** Las dos celdas tienen respuesta: con una sesión de nube viva, cerrarla
   desde Ajustes; de visita en el móvil de otro, salir de la visita. El copy actual
   (`welcome.groups.neutralUnavailable*`) dice «hay una sesión abierta que hay que cerrar desde Ajustes»
   — se escribió para el organizador y aquí es cierto solo en una de las dos celdas.
2. **Ofrecer el camino que sí existe**: en `.cloudSecureSignOut` la invitación se puede aceptar con la
   sesión de nube viva sin borrar nada (la celda F de la matriz: «llega una invitación → unirse con la
   sesión activa»). Es decir, puede que en esa celda la puerta no deba interponerse siquiera.
3. Medir antes de decidir: **cuál de las dos celdas llega de verdad a esta pantalla** y con qué
   frecuencia. La de la visita la corta el término `isSecondarySession` de `GroupInviteNeutralGateLogic`
   antes de llegar aquí, así que es cinturón, no camino.

## Cómo se sabe que está bien

Desde cualquier estado que hoy da `.unavailable`, la persona tiene **una acción concreta** que la
acerca a entrar al grupo, y la invitación no se queda dando vueltas hasta caducar a los 7 días.

## Resolución (2026-09-29)

**Qué cambia para quien usa la app.** Quien acepta una invitación en un teléfono con datos ya no se queda en un «ahora no»
con un solo «Volver»:

- **Con los datos en su cuenta de la nube y la sesión abierta**, entra al grupo sin pantalla en medio (matriz, fila F).
- **Si el teléfono está cerrando una sesión**, la pantalla lo reintenta sola cuando termina, tiene «Reintentar» y dice
  qué hacer si no avanza (cerrar Yala del todo y abrirla).
- **Si la cuenta de la nube acaba de prepararse** y el teléfono aún no se ha reabierto, dice «abre Yala otra vez».
- **Si los datos son de una cuenta de la nube con la sesión cerrada**, dice «entra con la cuenta de este teléfono» (si es
  tuya) o «únete desde tu teléfono» (si no).

**La premisa había cambiado** (medido): `.secondaryCloudSignOut` e `isSecondarySession` ya no existen. Quedaban dos
motivos: el cierre en curso y la celda `.cloudSecureSignOut`.

**Qué se tocó.** `GroupInviteNeutralGateLogic.decide` gana `personalDataLivesInLiveCloudAccount` (apaga solo el término
del corpus; el espejo sigue mandando). `WelcomeGroupsGateView`: el `.unavailable` del invitado con Reintentar y re-medida
sola, y dos fases nuevas (`inviteNeedsRelaunch`, `inviteNeedsCloudSignIn`). La rama del organizador no cambia. Cuatro
claves de copy en las 16 locales.

**Verificado.** `GroupInviteNeutralGateTests`: tabla de 16 celdas, desvío de `drive` con y sin sesión, scans de las
pantallas. Tres mutantes muertos (quitar el término, ponerlo delante del espejo, quitarle la sesión). Review adversarial
en dos lentes: cazó que sin exigir la sesión otra persona se unía sobre el corpus de una cuenta cerrada — corregido.

**No verificado a ojo.** Las pantallas nuevas no se han visto en el simulador: sus estados (cierre a medias, arranque
recién pasado a la nube, sesión caducada en `.cloud` sin onboarding) no tienen hook de XCUITest. Reusan el mismo
`noticeShell` que las demás pantallas de la puerta.

**Fuera, con ticket:** `groups-organizer-gate-unavailable-sends-to-settings-from-the-welcome` y
`born-cloud-sign-up-over-mirror-imported-rows-skips-the-corpus-check`.
