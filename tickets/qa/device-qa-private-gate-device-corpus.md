---
id: device-qa-private-gate-device-corpus
status: qa
priority: high
area: "modo-nube, onboarding, groups"
created: 2026-09-13
source: "`groups-only-private-restart-skips-the-wipe-alert`"
---

# Device-QA · «Primera vez → privado» con datos ya en el teléfono

**NO es simulable, y el motivo está medido, no supuesto.** Dos cosas lo impiden, y hacen falta las dos:

1. **La puerta sale de largo bajo XCUITest.** `WelcomePrivateICloudGateView.measure()` abre con
   `guard !SwiftDataConfiguration.isUITesting else { onProceed(); return }` — la hermeticidad va ANTES de
   la red, así que con `-uitest` las cuatro pantallas nuevas son inalcanzables **por construcción**. Es
   deliberado y no se toca: sin eso, el simulador (que no tiene cuenta de iCloud) caería en «no pudimos
   revisar tu iCloud» y todo XCUITest que entre por «Es mi primera vez» vería una pantalla que antes no
   existía.
2. **El estado que dispara el aviso no lo produce ningún seam.** Hace falta el par «mount neutro + store
   con filas», y bajo `-uitest` el mount NO es neutro: con seed hay archivo de store, así que
   `isFreshInstallForNeutralMount` es `false`. La marca que sí lo fuerza
   (`cloudSync.groupsOnlyNeutralMount`) **no la arma ningún perfil de seed** —solo las dos altas
   solo-grupos— y `AppBootstrapper` la **purga** en el bloque de `-uitest-reset`.

Control positivo de que el camino determinista sigue intacto, medido el 2026-09-13:
`WelcomeFreshStartAlertUITests` + `WelcomeChooserUITests` + `OnboardingFlowUITests` +
`OnboardingPurposeStepUITests` + `FullModeActivationChooserUITests` → **15 casos, 0 fallos**. Que el alert
de siempre siga saliendo prueba que bajo uitest el mount no es neutro.

## Cómo montar el estado en device

El camino limpio **no** es el que decía el ticket original (`performPrivateReset` ya no existe: el cierre
de sesión solo-grupos arma el boot-wipe, borra el store personal y retira la marca). El que sí llega:

**Opción A · wipe remoto sobre un dispositivo solo-grupos** (el camino medido):

1. Teléfono **A**: entra en Yala por «Vengo por un grupo» y completa el alta del organizador. Queda en
   solo-grupos (tab bar con un solo tab). Deja al menos un grupo con un gasto.
2. Teléfono **B**, **mismo Apple ID**: Ajustes → Vaciar mis datos → confirma.
3. Vuelve a **A** y ábrelo. Debe aparecer la pantalla de bienvenida (el wipe remoto repone los dos flags
   de onboarding). **Los grupos siguen dentro**: `wipeAllUserData` no toca los `Split*`.

**Opción B · más rápida si tienes build de desarrollo**: en A, tras el alta solo-grupos, usa el panel
DEBUG para forzar la señal de wipe remoto.

## El guion

| # | Paso | Qué tiene que pasar |
|---|---|---|
| 1 | En **A** (estado de arriba), tapea «Empezar» → «Es mi primera vez» → «Tu cuenta en tu iCloud privado» | Sale **«Ya hay datos en este teléfono»**, con dos botones: «Dejarlo como está» y «Empezar de cero» |
| 2 | Tapea **«Dejarlo como está»** | Vuelve a la elección privado / nube. **No se borra nada**: sal al tab Grupos y comprueba que el grupo sigue |
| 3 | Repite el paso 1 y tapea **«Empezar de cero»** | Sale la segunda confirmación: «¿Seguro? Esto es definitivo.» con «Mejor no» y «Vaciar definitivamente» |
| 4 | Tapea **«Mejor no»** | Vuelve al aviso del paso 1, **sin haber borrado nada** |
| 5 | Vuelve a «Vaciar definitivamente» | Aparece «Borrando lo que había en este teléfono…» y después la pantalla **«reabre Yala»** |
| 6 | Cierra Yala del todo y ábrela | Arranca el **onboarding de cero**. Ni grupos, ni categorías de antes |
| 7 | Completa el onboarding privado y crea una transacción | Se guarda con normalidad |
| 8 | **Lo que solo se ve aquí:** espera a que iCloud sincronice y mira el corpus del Apple ID (otro dispositivo con la misma cuenta, o la app de otra sesión) | **NO debe aparecer nada de la etapa de grupos**: ni las bridgeadas, ni las categorías sembradas por el alta |
| 9 | En Ajustes, entra en Grupos | El dominio está **sellado**: el bridge no vuelve a meter gastos de grupo en el corpus personal hasta que se adopte Grupos otra vez |

## La otra celda, que también hay que mirar

Si el Apple ID **tiene** corpus en iCloud (una vida privada anterior) y además el teléfono tiene datos,
gana el aviso de iCloud («Ya tienes datos en tu iCloud», con «Traer mis datos»). Su borrado **también**
purga el dominio de Grupos y escribe el sello desde el 2026-09-13. Repite los pasos 5-9 por esa vía.

## Si algo falla

- **No sale ninguna pantalla y va directo a «reabre Yala»** ⇒ el término del corpus del teléfono no llegó:
  mira `WelcomeFlowContainer.deviceCorpusGate` (se apaga si el mount no es neutro) y
  `WelcomePrivateICloudGateView.measure()`.
- **Sale la pantalla pero al reabrir siguen los grupos** ⇒ el borrado no llegó a `wipeLocalGroupsDomain`.
- **Al reabrir aparece «te borraron los datos en otro dispositivo»** ⇒ la gracia del wipe remoto no se
  canceló antes del borrado.
