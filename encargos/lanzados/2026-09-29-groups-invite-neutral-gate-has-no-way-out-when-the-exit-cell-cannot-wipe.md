# La puerta del invitado deja sin salida cuando no puede borrar

## Contexto
Cierre limpio de PR #299 (carril adaptativo, paso 5). Cola A autónoma sigue armada; turno Cola A (alternancia A → adaptativo → A). Una sola sesión Yala a la vez. Ticket: `tickets/backlog/groups-invite-neutral-gate-has-no-way-out-when-the-exit-cell-cannot-wipe.md`.

## Qué se pide
Que aceptar una invitación en un teléfono con datos de otra persona nunca deje al usuario sin pantalla ni sin camino: si la puerta dice que ahora no se puede, tiene que haber salida clara (qué hacer / reintentar / otra vía), no un bucle de «no se puede».

## Qué NO hay que tocar
Simuladores del carril adaptativo (`YalaLane-Adapt-*`). Producción. Cola B / rediseño UI.

## Cómo se sabe que está bien
Criterios del ticket. Gate/tests verdes. PR a `2.1` y cierre.

## Paso 0 (Frank, 2026-09-29)

**Medido antes de decidir** (la premisa del ticket, del 11-sep, cambió):

- `.secondaryCloudSignOut` y el término `isSecondarySession` **ya no existen** (el rediseño retiró la visita). Hoy
  `inviteNeutralEntryPhase()` da «ahora no» por **dos** motivos: el cierre de sesión del teléfono no está en reposo, o la
  celda es `.cloudSecureSignOut` (datos personales en la cuenta de la nube, `storageMode == .cloud`).
- `.cloud` + onboarding sin terminar + (datos o espejo) llega poco: la adopción marca el onboarding al empezar; el alta
  nacida en la nube deja el espejo montado **hasta reabrir** (`activateBornCloudStorage`). La fase del coordinador vive en
  memoria: reabrir la app siempre la devuelve a `.idle`.

**Decisiones (auto-contestadas, sin nadie delante):**

1. **Con los datos en la nube y sin espejo, la puerta no se interpone** (ticket, vía 2; matriz fila F «unirse con la
   sesión activa»). El daño que cierra —gastos del grupo exportados al iCloud de otro— necesita espejo; en `.cloud` sin
   espejo no hay adónde exportar. Es además más estrecho que lo que la puerta ya acepta: con el onboarding terminado
   sigue en todas las celdas. Término nuevo en `GroupInviteNeutralGateLogic.decide`, sin default.
2. **En `.cloud` con el espejo aún montado**: pantalla «reabre Yala» — al reabrir el espejo se va, el reconciler
   re-submite la invitación y la puerta deja pasar. Acción concreta, sin bucle.
3. **Cierre en curso**: pantalla que lo dice, **se reintenta sola** cuando el cierre vuelve a reposo, botón
   «Reintentar» y, si no avanza, «cierra y vuelve a abrir Yala» (la fase muere con el proceso). No se reconoce
   (`acknowledgeBlocked`) un bloqueo ajeno: sería quitarle su estado a otra pantalla.
4. Fase nueva solo para el invitado (`inviteUnavailable(reason)`); la del organizador y su copy **no se tocan**
   (fuera del encargo; se anota en «Encontrado»).
5. Copy nuevo en las 16 locales vía `add-l10n-key.sh` y traducido a mano. Sin decisión de producto pendiente.
6. Review adversarial: sí (puerta de invitación = sync/datos cruzados), acotada al diff.

**Corregido tras la review adversarial (mismo día):**

- El término 1 exige además **sesión viva** (`personalDataLivesInLiveCloudAccount`). Sin ella, el corpus es de una cuenta
  que nadie tiene abierta, la invitación pediría entrar y el alta de grupos no pasa por el guard cross-cuenta: otra
  persona se uniría y sus gastos caerían en esa cuenta. Ese caso tiene su pantalla: «entra con la cuenta de este
  teléfono» (si es tuya, «Ya tengo una cuenta»; si no, únete desde tu teléfono).
- El texto de Reintentar ya no afirma una causa: también se llega con el cierre en reposo (la celda cambió entre medir y
  arrancar). «Cierra Yala» dice «del todo (deslízala fuera del selector de apps)», como el resto del catálogo.
- El cierre del `onChange` pasa a una línea que llama a una función (regla del CI de Xcode 26.6).
