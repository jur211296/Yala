# Cerrar el encargo de casa: bug-triage fuera de 2.1, plists documentados, Vuelta escrita

## Contexto
Casa te dejó el 2026-08-31 el encargo
`~/Claude/casa/encargos/pendientes/2026-08-31-de-casa-para-frank-webhook-muerto-y-launchd-de-yala.md`
(webhook de bug-triage en 404 + dos launchd de Yala en la máquina equivocada).

En sesión ya hiciste lo operativo, con OK explícito de Jürgen:
- Commit `2a9506f4` — retiraste `.claude/commands/bug-triage.md` (y los curl a n8n).
- Borraste `com.yala.agent.api` y `com.yala.agent.retention` de `~/Library/LaunchAgents/`
  (copia en `~/YalaAgent/retention/`). No hay jobs yala cargados.

Lo que Dan validó después: eso **no cierra** el encargo.
- La rama `chore/higiene-triage-y-credenciales` no tiene remoto; **`2.1` todavía tiene**
  `bug-triage.md` con el webhook 404.
- La Vuelta del fichero de casa está vacía; el frontmatter sigue `estado: abierto`.
- El destino de los plists está hecho en disco, no escrito donde Jürgen lo lea.

Arrancas en contexto limpio: no ves el chat de Dan. El fichero de casa es la fuente del pedido original.

## Qué se pide
1. Dejar `2.1` (o la rama que Jürgen use como línea principal de la app) **sin**
   `bug-triage.md` ni curls a ese webhook de n8n. Empuja/mergea lo que haga falta;
   no dejes el arreglo solo en una rama local sin remoto.
2. Rellenar la **Vuelta** del encargo en casa: qué hiciste, commits/ramas, qué quedó
   de los plists (desinstalados + path de la copia), qué no tocaste.
3. Actualizar el frontmatter del encargo (`estado` coherente con la entrega).
4. Dejar escrito el destino de los dos plists donde Jürgen pueda leerlo sin abrir la sesión
   (Vuelta basta; ADR solo si el repo lo pide para este tipo de decisión).

## Qué NO hay que tocar
- Las 21 sesiones guardian archivadas (fuera de alcance).
- marketing/ (es de Lola).
- No reactivar triage ni inventar un webhook nuevo: la decisión fue retirar el comando.
- No recargar esos launchd en esta máquina.

## Como se sabe que está bien
- En la rama principal acordada (`2.1` u origin de esa línea) no existe
  `.claude/commands/bug-triage.md`, o un `git show`/`ls` lo demuestra.
- El encargo de casa tiene Vuelta rellena y estado actualizado.
- `launchctl list` sin jobs yala; plists ausentes de LaunchAgents; Vuelta nombra la copia en YalaAgent/retention.
