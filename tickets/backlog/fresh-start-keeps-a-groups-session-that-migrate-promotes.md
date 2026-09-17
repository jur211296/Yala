---
id: fresh-start-keeps-a-groups-session-that-migrate-promotes
status: backlog
priority: high
area: "modo-nube, handover"
created: 2026-09-16
source: "review adversarial de `settings-migrate-to-cloud-adopts-silently-instead-of-migrating` (lente de identidad, hallazgo 2), 2026-09-16"
---

# Tras «Empiezo de cero», «Activar la nube» sube las finanzas de la persona nueva a la cuenta de grupos de la anterior

## El problema, en lenguaje de usuario

Me dan un iPhone que usaba otra persona para sus grupos. En la bienvenida elijo «Empiezo de cero», registro mis
finanzas y un día toco «Activar la nube». La tarjeta dice «Usarás tu cuenta de Yala actual, la de Google» y sigo. Mis finanzas acaban en
la cuenta de la persona anterior, y le aparecen en sus dispositivos.

## Lo medido (2026-09-16, rama `encargo/2026-09-16-settings-migrate-to-cloud-adopts-silently-instead-of-migrating`)

- «Empiezo de cero» **no cierra la sesión en la nube**. Los tres llamadores de `DataWipeService.wipeLocalGroupsDomain`
  (`ContentView.swift`, dos, y `ShellDataAlertsModifier.swift`) no llaman a `signOut`, y el código lo dice en dos sitios:
  `wipeLocalGroupsDomain` («el JWT de la sesión Nube vive en su propio Keychain ⇒ SOBREVIVE al relevo») y
  `GroupsAssociationRegistrar.syncFromLiveSessionIfNeeded`.
- Con el dominio sellado (`groupsDomainSealedForFreshStart`), la asociación no se lee ni se registra
  (`GroupsAccountAssociation`), así que `isAssociated(sub:)` devuelve `nil`.
- La tarjeta de migrar elige `.reuseLiveSession` con cualquier sesión viva (`StorageMigrationSignInLogic.decide`) y solo
  nombra el proveedor (`accountReuseNote`), no la cuenta.
- La comprobación de «Migrar a la nube» deja pasar una cuenta solo de grupos sin asociada (decisión D3 de Jürgen,
  2026-09-16), y el claim la promueve (`claim_account`, rama de la fila ligera → `created`).

**No es una regresión de ese ticket**: en `2.1`, sin comprobación, el claim ya promovía cualquier sesión solo de grupos.
Lo que cambió es que la celda de la tabla del 10-sep, que nunca llegó a cablearse, la habría bloqueado.

**Inferido, no medido en un dispositivo**: que el recorrido completo —relevo con sesión de grupos viva, onboarding
nuevo, migrar— se dé en campo.

## Opciones, sin decidir

- **Cerrar la sesión en la nube en «Empiezo de cero»**, que es la frontera de otro usuario. Hay que medir qué rompe el
  cursor de Grupos que hoy sobrevive a propósito (`.claude/rules/swiftdata-cloudkit.md`, «En una frontera de USUARIO el
  outbox de Grupos y su cursor tienen signos OPUESTOS»).
- **Que la comprobación distinga la sesión preexistente**: `nil → promover` solo si la sesión la abrió el intento,
  porque ahí la persona eligió la cuenta; con sesión de antes, pedir que elija o bloquear.
- **Nombrar la cuenta en la tarjeta** (el correo, no solo el proveedor).

## Criterios de aceptación

- [ ] Tras «Empiezo de cero», «Activar la nube» no puede promover la cuenta de grupos de la persona anterior sin que
      la persona nueva la elija.
- [ ] Quien migra con su propia cuenta de grupos asociada sigue pudiendo promoverla.

## Decisión Jürgen (noche 2026-09-16, vía Frank)

**No promover una sesión de grupos preexistente:** `nil → promover` solo si la sesión la abrió este intento (la persona eligió la cuenta). Si la sesión venía de antes (p. ej. tras «Empiezo de cero» sin cerrar nube), pedir que elija o bloquear — no subir finanzas nuevas a la cuenta de la persona anterior.

**Aplazado a medición:** cerrar la sesión nube en «Empiezo de cero» (riesgo cursor/outbox Grupos). **No basta solo** nombrar el correo en la tarjeta.
