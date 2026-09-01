# Cerrar el encargo de casa: webhook 404 de bug-triage y destino de los plists

## Contexto
Encargo de casa, sigue abierto, Vuelta vacía:
~/Claude/casa/encargos/pendientes/2026-08-31-de-casa-para-frank-webhook-muerto-y-launchd-de-yala.md

Jürgen dio OK para proceder. Cree que ya está resuelto; falta el cierre.

Ya hecho en esta rama (`chore/higiene-triage-y-credenciales`, sin remoto):
- Retirado el comando `/bug-triage` (commit 2a9506f4).
- Borrados los dos plists de LaunchAgents. Copia en `~/YalaAgent/retention/`. Jobs no cargados.

Queda parcial:
- La línea principal (2.1 / origin) todavía tiene `.claude/commands/bug-triage.md` con curls al webhook de n8n (404 desde hace un mes: workspace inexistente).
- Vuelta del encargo de casa vacía; estado sigue abierto.
- Destino de los plists no escrito (con la Vuelta basta).

parte Yala ahora: esa rama, 15 commits, 0 PRs, 0 encargos pendientes, 1 fichero sin commitear (no inspeccionado). Este repo no lleva CHANGELOG.

Si algo del diagnóstico de casa no cuadra, dilo en la Vuelta. No asumas que es correcto.

## Qué se pide
1. Dejar la línea principal (2.1 / origin) sin `bug-triage.md` y sin curls a n8n.
2. Rellenar la Vuelta del encargo de casa y actualizar el estado.
3. Dejar escrito el destino de los dos plists (Vuelta basta): se borraron, copia en `~/YalaAgent/retention/`, jobs no cargados. No recargarlos.

## Qué NO hay que tocar
- No reactivar triage.
- No recargar esos launchd.
- No tocar `marketing/` (Lola).
- Nada sobre las 21 sesiones guardian archivadas.
- El fichero sin commitear: no lo mezcles en este cierre si no es de este encargo.

## Como se sabe que está bien
- En 2.1 / origin no queda `bug-triage.md` ni curl a n8n.
- La Vuelta del encargo de casa está rellena, con estado actualizado y el destino de los plists escrito ahí.
- Triage no reactivado. launchd no recargados. `marketing/` intacto.
