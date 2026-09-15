---
id: groups-sync-reads-a-missing-attest-401-as-a-session-expiry
status: backlog
priority: medium
area: "groups, sesión, attest"
created: 2026-09-15
updated: 2026-09-15
source: "medición de `groups-push-reads-an-offline-token-refresh-as-a-session-expiry` (2026-09-15)"
---

# Un 401 por App Attest ausente también se lee como «Tu sesión caducó»

## El problema, en lenguaje de usuario

Mi sesión está bien, pero este teléfono no consiguió su token de App Attest. Los cambios de mis grupos dejan de subir
hasta que la app vuelve a primer plano, y si toco «Cerrar sesión» Yala me dice «Tu sesión caducó. Vuelve a iniciar
sesión…». Volver a entrar no lo arregla: lo que falta no es la sesión.

## Lo medido (leído en el código, sin ejecutar)

- En producción (`ENFORCE = "enforce"`, `gateway/wrangler.toml`), `requireUserAndAttest` responde **401** por tres
  salidas (`gateway/src/groups/routes.ts`): sin JWT (`yala_attest_required`), con el JWT inválido o caducado
  (`yala_attest_invalid`), y sin un token de attest que verifique, falte la cabecera o no valide
  (`yala_attest_required`). El mismo código cubre dos causas; la primera no la produce este cliente, que no manda
  nada sin token.
- `AttestSessionProvider.live` devuelve `nil` cuando no consigue el token (red caída, key que el gateway no reconoce,
  simulador sin el bypass de desarrollo), y el cliente manda la petición sin la cabecera.
- `GroupsSyncClient` lee todo 401 como sesión caducada. Su reintento fuerza el refresh del JWT, que sí llega; la
  re-emisión vuelve a dar 401 porque sigue sin attest, y el resultado es `.sessionExpired`: el loop para
  (`stopUntilSignIn`) y el cierre de sesión enseña `groups.errors.sessionExpired`.
- Sin medir: cuánta gente llega aquí, y si `GroupsMembershipClient` sufre lo mismo (su 401 también es
  `.sessionExpired`).

## Lo que hay que decidir (Jürgen)

1. Leer el `code` del envelope del 401 y tratar `yala_attest_required` como pasajero, con su rastro en los logs.
2. Dejarlo, sabiendo que exige que el attest falle mientras la red funciona.

## Relación con otros tickets

- `groups-push-reads-an-offline-token-refresh-as-a-session-expiry` — el otro caso en el que el canal llamaba caducada
  a una sesión que no lo estaba.
- `.claude/rules/gateway-attest.md` — la asimetría observe/enforce y la recuperación de la key.
