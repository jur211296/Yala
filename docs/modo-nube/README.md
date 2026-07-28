# Copias de trabajo para sesiones en otra máquina — NO son la SSOT

La SSOT de estos documentos es el vault de Obsidian (`$VAULT/Backlog/modo-nube/`, iCloud), que **NO
sincroniza a otras máquinas vía git**. Estas copias existen para que una sesión que corre en otra Mac
pueda LEER el diseño y las decisiones sin acceso al vault.

**Orden de lectura, en cualquier máquina** (corrección del owner 2026-07-28: la Mac mini **sí** tiene el
vault, así que la guía anterior de «lee las copias, no el vault» estaba mal):

1. **Opción A — el vault.** `$VAULT/Backlog/modo-nube/<X>.md`, con
   `$VAULT = ~/Library/Mobile Documents/iCloud~md~obsidian/Documents/YalaWiki/`. Es la SSOT: si el fichero
   existe allí y su `updated:` es igual o posterior al de la copia, **gana el vault**.
2. **Fallback — este espejo.** `docs/modo-nube/<X>.md`. Úsalo cuando el vault no esté montado (sesión
   headless, cron, worktree limpio, iCloud que aún no ha sincronizado) o cuando el fichero no aparezca allí.

No des por supuesta ninguna de las dos rutas: comprueba cuál existe antes de leer. Y si el vault está
disponible, **escribe en el vault** — el espejo se refresca desde él, nunca al revés.

## Refrescado 2026-07-27 — auditoría de escenarios y sus decisiones

Añadidos para las sesiones de corrección de los "bugs del encendido" (chips C-1…C-10), que corren en
la Mac mini:

| Copia | Para qué |
|---|---|
| `MODO-NUBE-DECISIONES-ESCENARIOS.md` | **SSOT de las 7 decisiones del owner** (2026-07-27). Su §9 es la tabla de los 10 bugs del encendido con el reparto en chips. Todos los chips la referencian |
| `MODO-NUBE-AUDITORIA-ESCENARIOS.md` | La auditoría completa (§4 estados huérfanos, §7 registro de brechas priorizado con evidencia `path:línea`) |
| `MODO-NUBE-DIFERIDOS.md` | Registro de vigilancia; #38 es la re-revisión pendiente de D-A6 |
| `MODO-NUBE-ESTRATEGIA-RELEASE.md` | Reglas de dark shipping y **no-regresión de 2.x** (la rama `.icloud` debe quedar byte-idéntica) — la necesita C-1 |
| `MODO-NUBE-GRUPOS-V1-DECISION.md` | §1a documenta el enrutado de quiescencia del bridge — la necesita C-2 |
| `../planning/BRAND-VOICE.md` | Tono y estilo para todo copy nuevo — la necesitan C-9 y C-10 |

Ya estaban de la sesión nocturna G1→G3 (2026-07-15): `MODO-NUBE-GRUPOS-BACKEND-V1-DISENO.md`
(diseño, solo-lectura), `MODO-NUBE-G0-GUION-DEVICE.md`, `groups-backend-v1.md` (log de
implementación). Ojo: el frente 4 de `groups-backend-v1.md` quedó **actualizado el 2026-07-27** por
las decisiones D-A4/D-A5/D-A6 — "migra cualquier miembro", no "owner migra".

## Protocolo

1. **Leer** aquí; **no editar** los documentos de diseño en estas copias sin replicar al vault.
2. Lo que la sesión remota escriba (logs de implementación, hallazgos) va en el fichero de log que le
   corresponda, y al volver a la máquina principal se sincroniza **de vuelta** al vault.
3. Si tocas un documento aquí, dilo en el commit para que la reconciliación no pierda el delta.
4. Estas copias pueden quedar stale: si una fecha `updated:` del vault es posterior, gana el vault.
