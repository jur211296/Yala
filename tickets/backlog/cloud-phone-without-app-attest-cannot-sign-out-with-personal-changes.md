---
id: cloud-phone-without-app-attest-cannot-sign-out-with-personal-changes
status: backlog
priority: medium
area: "modo-nube, attest, sesión"
created: 2026-09-15
updated: 2026-09-15
source: "alcance de `groups-phone-that-never-attests-is-told-to-retry-forever` (2026-09-15): la excepción de Jürgen es para los cambios de grupos"
---

# En la nube, un teléfono sin App Attest con cambios personales sin subir no puede cerrar sesión nunca

## El problema, en lenguaje de usuario

Tengo mi cuenta en la nube y este teléfono no consigue App Attest. Mis gastos nuevos no suben. Cuando quiero cerrar
sesión, Yala me dice «Hay cambios sin subir a la nube… Revisa tu conexión». Mi conexión va bien; lo intento durante días
y nada cambia.

## Lo medido (leído en el código, sin ejecutar)

- `CloudSyncRuntime.performCycle` pide el attest antes de subir (paso 2, `resolveAttest`). Sin él devuelve `.transient`
  ante cualquier error que no sea `AppAttestError.unavailable` —un `DCError` cae en el `catch` genérico—, y
  `.accountUnavailable` tras tres `.unavailable` seguidos (`AttestSyncGate.classify`). En los dos casos no sube nada del
  outbox personal.
- El cierre en la nube sube primero lo personal (`CloudSessionSignOut.performCloudSecureSignOut`, paso 1,
  `CloudMigrationController.pushAllPendingForSignOut`), que cicla ese mismo runtime. Con filas pendientes bloquea, tira el
  motivo y escribe `.permanent`: el aviso genérico que manda a revisar la conexión
  (`cloud-signout-collapses-the-personal-push-all-reason-into-permanent`).
- La salida con pérdida confirmada de `groups-phone-that-never-attests-is-told-to-retry-forever` solo alcanza a los
  cambios de GRUPOS, por decisión de Jürgen: con cambios personales pendientes, el paso 1 bloquea antes y no se ofrece.
- Perder aquí serían datos PERSONALES que no están en ninguna otra parte: en `.cloud` la copia es el servidor, y no
  llegaron.
- Sin medir: cuántos teléfonos `.cloud` están así. `cloudSyncBlockedByAttestUnavailable` solo cuenta los `.unavailable`.

## Lo que hay que decidir (Jürgen)

1. Ofrecer exportar los datos y, después, una salida con pérdida confirmada también para lo personal.
2. Solo el aviso honesto («este teléfono no puede sincronizar»), sin salida: la persona sigue sin poder cerrar sesión,
   pero sabe por qué.
3. Dejarlo hasta medir la población.

## Decisión Jürgen (2026-09-15)

**Opción 1:** ofrecer exportar los datos y, después, una salida con pérdida confirmada también para lo personal (misma idea que en grupos: texto honesto + confirmación explícita).

## Relación con otros tickets

- `groups-phone-that-never-attests-is-told-to-retry-forever` — de donde sale.
- `cloud-signout-collapses-the-personal-push-all-reason-into-permanent` — el motivo que el paso 1 tira.
- `personal-sync-reads-an-offline-token-refresh-as-a-session-expiry` — el mismo 401 en el canal personal.
