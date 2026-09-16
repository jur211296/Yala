---
id: cloud-tab-does-not-say-this-phone-cannot-sync-personal-data
status: backlog
priority: low
area: "nube, attest, copy"
created: 2026-09-15
source: "hallazgo de `groups-tab-does-not-say-this-phone-cannot-sync-groups` (2026-09-15): Grupos ya tiene su aviso fijo, lo personal no"
---

# Con la cuenta en la nube, un teléfono sin App Attest no se entera de que sus movimientos no suben

## El problema, en lenguaje de usuario

Mis datos viven en la nube. Apunto gastos desde este teléfono y no llegan a mis otros dispositivos. La app no me dice
nada: solo me entero si intento cerrar sesión.

## Lo medido (2026-09-15)

- Desde `groups-tab-does-not-say-this-phone-cannot-sync-groups`, la pestaña **Grupos** sí enseña un aviso fijo mientras
  el veredicto de App Attest es terminal, y el store avisa cuando la racha cambia
  (`GroupsAttestStreakStore.didChangeNotification`). La mitad personal no tiene nada equivalente.
- El veredicto terminal del canal personal solo emite el canario `cloudSyncBlockedByAttestUnavailable`
  (`CloudSyncRuntime.performCycle`) y para el runtime, sin nada visible. `SyncStatusBanner` es el de iCloud, no el de
  la nube.
- Lo único que hoy se lo dice a esa persona es el cierre de sesión en Ajustes
  (`cloud-phone-without-app-attest-cannot-sign-out-with-personal-changes`, #175), que además le ofrece exportar. Igual
  que en Grupos antes de este ticket: el aviso llega cuando la persona intenta un gesto que puede perder algo.
- **La racha es la misma para los dos canales** y la escribe también el motor personal, así que el dato para decidirlo
  ya está: no hay que medir nada nuevo.

## Lo que hay que decidir (Jürgen)

1. **Un aviso fijo, espejo del de Grupos**, en la superficie que corresponda a lo personal (¿el Panel? ¿Ajustes?), con
   el copy del cierre: «Este teléfono no puede sincronizar tus datos» (`settings.signOutAttestTitle`, ya existe) más
   qué puede hacer. En Grupos el «qué hacer» es usar otro teléfono; aquí hay uno más: **exportar**, que el #175 ya tiene
   construido.
2. **Dónde.** Grupos tenía una pestaña propia. Lo personal no: un aviso fijo en el Panel es mucho más visible y mucho
   más intrusivo.
3. **Dejarlo**: el cierre de sesión ya lo dice, y el canario dirá cuánta gente está así.

## Relación con otros tickets

- `groups-tab-does-not-say-this-phone-cannot-sync-groups` — el hermano de Grupos, hecho. Su
  `GroupsAttestTabNoticeLogic` y el aviso del store son el molde.
- `cloud-phone-without-app-attest-cannot-sign-out-with-personal-changes` — el cierre honesto y la exportación.
- `groups-phone-that-never-attests-is-told-to-retry-forever` — de donde sale el veredicto terminal.
