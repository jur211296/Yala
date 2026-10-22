---
id: pending-reverse-complete-runs-with-whatever-session-is-live
status: backlog
priority: low
area: "modo-nube, migración"
created: 2026-09-27
updated: 2026-10-08
source: "review adversarial de `migration-activation-drops-pending-effects-it-never-restores` (lentes de runner y de consumidores, 2026-09-27)"
---

# El cierre pendiente de una vuelta a iCloud se manda con la sesión que haya, sea de la cuenta que sea

## El problema, en lenguaje de usuario

Vuelvo a iCloud sin conexión con la cuenta A, y el aviso al servidor de que la vuelta terminó se queda pendiente. Más
tarde entro en la nube con otra cuenta, B. Ese aviso pendiente se manda con la sesión de B, y el servidor podría marcar
como devuelta a iCloud una cuenta que no es la que volvió.

## Lo medido (2026-09-27) y lo inferido

- Medido: `.completeReverseServer` es un efecto del journal sin cuenta asociada. `MigrationWorkExecutor` lo ejecuta con el
  token de la sesión viva en el momento de drenarlo (`resume` del arranque, re-kick, o el `handle` que lo repone).
- Medido: desde `migration-activation-drops-pending-effects-it-never-restores`, «Activar la nube» lo guarda y lo repone al
  salir antes del claim, y el `handle` lo drena en el acto: si la persona firmó con B en ese intento, sale con la sesión de B
  (en `continueToClaim` la sesión del intento se cierra DESPUÉS del `submit`). Antes del ticket pasaba lo mismo por otro
  camino: el pendiente seguía en `icloudActive` y el siguiente `resume` lo drenaba con la sesión que hubiera.
- Inferido, sin medir: qué hace `reverse_complete` (`migration_progress`) con una cuenta B en la que este dispositivo es
  líder de una reserva nueva. El cuerpo del RPC no está en el repo. Si solo mira el líder, escribiría `reverted_at` y
  `kind = 'groups_only'` en B.

## Qué se espera

Atar el efecto a la cuenta que lo emitió (el hash de la cuenta, journaleado con el cierre de la vuelta) y no mandarlo con
otra sesión: esperar a esa cuenta o dejar rastro y retirarlo. Antes, medir en staging qué contesta `reverse_complete` en
ese caso.

## Criterios de aceptación

- [ ] Con `.completeReverseServer` pendiente de la cuenta A y la sesión de B viva, el efecto no llama al servidor.
- [ ] Con la sesión de A, se ejecuta como hoy.

## Medido en 2.1 (triage 2026-10-08)

- `MigrationWorkExecutor.swift`, `case .completeReverseServer`: `await session.accessToken()` y `migrationProgress(action: "reverse_complete")` sin ninguna comparación con la cuenta que cerró la vuelta. El efecto (`MigrationStateMachine.swift`, `case completeReverseServer`) sigue sin payload de cuenta.
- Ningún commit desde el 2026-09-27 toca ese efecto (`git log -S completeReverseServer`).

Triage 2026-10-08: abierto · low → low · sigue sin atar a la cuenta, pero exige vuelta sin red y entrar después con otra cuenta antes del drenaje, y el efecto del RPC en B está sin medir.
