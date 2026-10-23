---
id: reopen-yala-only-for-private-icloud
status: qa
priority: medium
area: "modo-nube, onboarding, grupos"
created: 2026-10-21
updated: 2026-10-23
source: "tablero-reabre-yala-solo-cuando-la-persona-entra-ypit (QA guiado TF19, 2026-10-20)"
---

# «Reabre Yala» solo cuando la persona entra en su iCloud privado

## La regla de Jürgen (2026-10-20)

«Solo deberíamos pedir reabrir cuando el usuario pida algo privado. Es el único momento en el que se justifica con
privacidad el que tenga que reabrir.»

## Inventario (medido en el código el 2026-10-21, árbol `4593908e1`)

Hoy Yala pide reabrir en 9 situaciones. 3 entran en el iCloud privado (las justifica la regla) y 6 son nube, Grupos o
salidas de sesión.

| # | Qué ve la persona | Dónde sale | Por qué hoy reabre | Clase | ¿Sin reabrir? |
|---|---|---|---|---|---|
| 1 | «Un último paso: reabre Yala» | Es mi primera vez › privado; Restaurar / Traer mis datos; Activar Yala completo › privado | Monta el espejo de iCloud sobre un store sin él | Privado | No: encender el espejo con la app abierta no está medido, y montar un segundo contenedor sobre el mismo fichero deja la app vacía (`WelcomeMirrorRelaunchLogic`) |
| 2 | «iCloud ya disponible · ciérrala y vuelve a abrirla» | Yala arrancó sin iCloud y luego se entró en iCloud | Igual que el 1 | Privado | No |
| 3 | «Ya casi está · Al abrirla otra vez, empiezan a subir a tu iCloud» | Ajustes › Volver a iCloud | Monta el espejo | Privado | No |
| 4 | «Ya casi está · Tus datos ya están en tu cuenta de la nube» | Final de «Activar la nube» y de «Activar la nube en este dispositivo» | Apaga el espejo | Nube | Bloqueado (ver abajo) |
| 5 | «Tus datos siguen en la nube · La vuelta a iCloud se detuvo» | «Cancelar y seguir en la nube» tras montar el espejo, o el techo de la espera | Apaga el espejo | Nube | Bloqueado |
| 6 | «Un último paso: reabre Yala · Ciérrala del todo y vuelve a abrirla» | Ya tengo una cuenta › nube, o Es mi primera vez › Tu cuenta en la nube, **solo si el proceso arrancó con el espejo montado** (en una instalación nueva no sale) | Apaga el espejo | Nube | Bloqueado |
| 7 | «Abre Yala otra vez para unirte» | Vengo por un grupo › Tengo una invitación, con cuenta en la nube y finanzas propias, recién pasadas a la nube con el espejo aún montado | Es el relanzamiento pendiente del 4 | Grupos | Bloqueado |
| 8 | «Ya casi está · Sesión cerrada» (y «Yala se reiniciará y seguirás con tu invitación») | Vengo por un grupo › Crear / Tengo una invitación con el espejo montado | Cierra la sesión privada: borra archivos al arrancar | Grupos | Con sesión privada, bloqueado por el espejo. **Con sesión solo-grupos ya se podría** (ver «Barato») |
| 9 | La misma pantalla del 8 | Cerrar sesión en la nube (ya va en caliente; la pantalla solo sale si el cambio falla), borrar la cuenta en la nube o solo-grupos, cerrar la sesión privada | Salida de sesión | Salidas | Nube: ya en caliente. **Borrar cuenta (nube y solo-grupos): se podría** |

**El mecanismo que ya existe:** `PersonalContainerSwap` cambia el contenedor sin relanzar, y hoy solo lo usa el cierre
de sesión en la nube. Se niega cuando el montaje lleva el espejo (`PersonalSwapReleaseLogic.mountAdmitsSwap`), porque
medido: el espejo emitió 5 eventos en los 10 s después de soltarlo. Por eso los 4, 5, 6 y 7 están bloqueados por lo
mismo: apagar el espejo con la app abierta.

**Ya resuelto antes de este inventario:** «Tengo una invitación» en una instalación limpia dejó de pedir el espejo el
2026-10-20 (`WelcomeMirrorRelaunchLogic`).

## Propuesta (aprobada por Jürgen el 2026-10-22, 05:42)

1. **Barato, sin riesgo nuevo** — los tres caminos cuyo montaje ya va sin espejo pasan por el cambio en caliente que ya
   usa el cierre de sesión en la nube: la celda solo-grupos del 8 y los dos «Borrar mi cuenta» del 9
   (`attemptSignOutSwap()` tras el arm, como `CloudSessionSignOut.swift:1768`). Recomendado.
2. **Los de apagar el espejo (4, 5, 6, 7)** — antes de tocar nada, una medición en un iPhone real: soltar el contenedor
   con espejo justo después de exportar el marcador y montar el mismo fichero sin espejo, mirando si CloudKit escribe
   algo después. Si no escribe, se amplía `PersonalContainerSwap` a esa salida. Si escribe, se quedan como excepción
   aprobada.
3. **Los privados (1, 2, 3)** se quedan: son los que la regla justifica.

## Hecha cuando

Solo entrar en el iCloud privado pide reabrir; o cada excepción de las 4-7 tiene la aprobación de Jürgen.

## Hecho (2026-10-23)

**Los dos «barato, sin riesgo nuevo»**, con el cambio en caliente del cierre de sesión en la nube y la misma red (el
borrado se arma ANTES; si el cambio no puede, el arranque siguiente hace lo de siempre):

- **La celda solo-grupos del cierre de sesión** (fila 8, y el mismo camino desde Ajustes): `armAfterCredentials`, solo con
  `kind == .groupsOnly`. El destino del Welcome (crear el grupo o seguir con la invitación) lo escribe ahora el
  coordinador pegado al arm (`destinationOnArm`), porque con el cambio en caliente la jerarquía se desmonta en la misma
  vuelta y la entrega de SwiftUI que lo escribía en `ContentView` puede no llegar. Va también en el cierre en la nube, que
  ya cambiaba en caliente y tenía el mismo hueco (inferido, sin medir en device).
- **«Borrar mi cuenta» en la nube y en solo-grupos sin sesión privada** (fila 9): `closeLocalAfterAccountDeletionCloud`
  devuelve si cerró en caliente y `AccountDeletionService` vuelve a `.idle` en ese caso (con `.awaitingRelaunch` el
  `onAppear` de Perfil la cerraría al abrirla y un borrado nuevo no arrancaría). El borrado solo-grupos CON sesión privada
  monta el espejo y se queda con el relanzamiento, a propósito.

Lo fijan `ReopenOnlyForPrivateICloudWiringTests` (el orden contra el arm, en los tres sitios), `WelcomeGroupsGateDestinationTests`
y los dos casos nuevos de `AccountDeletionServiceTests`. El cambio en sí no se puede ejercitar en el simulador: pide una
sesión real y soltar el contenedor de verdad. **Device-QA, guion abajo.**

**Los cuatro que apagan el espejo con la app abierta (4, 5, 6 y 7) no se tocan.** El simulador no tiene iCloud ni exporta
a CloudKit, así que no puede demostrar que soltar el espejo en caliente no escribe nada después (el spike R3 midió 5
eventos en los 10 s posteriores al release). Siguen en `reopen-yala-mirror-off-in-place-needs-an-iphone-measurement`.

## Device-QA (iPhone de QA, Yala Dev de este PR, contra staging)

**A · Borrar la cuenta sin reabrir**
1. Con una cuenta de la nube de prueba ya abierta en Yala Dev: Perfil → Tu cuenta de Yala → Eliminar mi cuenta → Continuar
   → Eliminar.
2. Esperado: tras «Eliminando…», Yala vuelve sola a la bienvenida, **sin** «Ya casi está · Cierra Yala y vuelve a abrirla».
   Si sale esa pantalla, anótalo y reabre: es la red de siempre, no una pérdida de datos.
3. Bienvenida → Ya tengo una cuenta → la misma cuenta → tiene que decir que no existe.

**B · Cerrar la sesión solo-grupos sin reabrir**
1. Instalación limpia → Vengo por un grupo → Crear mi primer grupo → crea la cuenta y un grupo «QA».
2. Perfil → Cerrar sesión → confirma.
3. Esperado: vuelve a la bienvenida **sin** pedir reabrir.
4. Vengo por un grupo → entra con la misma cuenta → el grupo «QA» sigue ahí.
