# Subir a TestFlight un build de Yala desde origin/2.1 usando ASC CLI

## Contexto
Jürgen pidió (2026-09-23 ~14:28 Lima) una sesión medium para subir a TestFlight con ASC CLI. Ya conoces el proceso y tienes las credenciales en la Mini (Keychain / Secrets.xcconfig / lo que usaste en el upload del build 13 y docs del gate).

Motivo de producto: el barrido QA (PR #224) dejó 21 tickets de device-QA con guion en `qa/guion-tanda.md`. Ese QA debe hacerse con **Yala Dev compilada desde `2.1` actual**. El TestFlight 13 es del 9-sep y casi no lleva esta lista; hace falta un build nuevo encima del 13 (sin borrar builds viejos).

Base: `origin/2.1` al día. Worktree propio.

## Que se pide
1. Orientarte con el runbook / memoria / docs del repo sobre cómo se sube un build a TestFlight con **ASC CLI** (no reinventar; no App Store Connect UI salvo que ASC falle de forma que solo el navegador salve, y entonces avisa).
2. Compilar el esquema/target de distribución interno que ya usáis para TestFlight (el mismo pipeline que el build 13 / PR #116), firmado y versionado correctamente (bump de build number según la convención del repo).
3. Subir el `.ipa` / archive a TestFlight vía ASC CLI con las credenciales ya disponibles.
4. Esperar hasta poder confirmar estado útil (al menos upload OK + processing/VALID si el CLI o ASC lo permiten sin bloquear horas; si queda en processing, reporta el build number y el enlace/estado y cierra).
5. Dejar en el aviso de cierre: número de build, versión, commit SHA de `2.1`, y si los testers internos ya lo ven o aún processing.
6. Si el upload crea/actualiza un ticket o docs mínimos del proceso, hazlo en el mismo PR; no abras cola de código.

MODO AUTÓNOMO HASTA TERMINAR: gate, commit, docs/board del repo, actualizar `docs/TICKETS.md` si tocaste tickets, merge a `2.1` y `/cerrar-total` sin preguntar si corre el gate o el commit. La regla del repo «espera aprobación si >3 ficheros» / «¿Sigo?» tras el plan queda **suspendida** en este encargo: implementa y cierra. Solo parar ante decisión/acceso real de Jürgen.

Diurno (ahora ~14:28–21:00 Lima): puedes AskUserQuestion a Jürgen si falta un secreto/acceso ASC o hay ambigüedad de cuenta/app (Yala vs Yala Dev). Si no, elige la opción robusta / la del último upload exitoso.

## Que NO hay que tocar
- No marketing/, no Web/, no App Store listing/capturas (eso es Lola).
- No relanzar cola A de código ni tickets de restore/migración salvo un bug bloqueante que descubras al firmar/subir (entonces ticket propio y avisa).
- No borrar builds previos de TestFlight.
- No cambiar versioning scheme ni bundle id.
- No pedir a Jürgen que pegue API keys en chat; usa lo que ya está en la Mini.

## Como se sabe que esta bien
- Hay un build nuevo en TestFlight (número > 13) subido desde el HEAD de `2.1` de hoy, vía ASC CLI.
- Aviso de cierre con build number + SHA + estado (VALID / processing).
- PR mergeado a `2.1` si hubo commits de docs/bump; `/cerrar-total` hecho; board al día.

## Paso 0

Decisiones resueltas antes de tocar nada (auto-contestadas, MODO AUTÓNOMO):

- **Qué app/scheme.** `Yala` (bundle `com.jurgenschmidt.yala`, app ASC 6758253109), el mismo pipeline que el build 13 (PR #116). Yala Dev no tiene ficha en App Store Connect: no se puede subir a TestFlight. El guion de QA que pide «Yala Dev desde 2.1» sigue valiendo para el bloque que lo necesite; este build cubre lo que se prueba sobre la app de producción y el paso 4 de `previous-person-cloud-session-survives-fresh-start-and-reinstall` (TestFlight encima del 13).
- **Versión.** `MARKETING_VERSION` se queda en **2.1**: medido con `asc versions list`, la última publicada es 2.0.4 y el tren 2.1 sigue abierto. Sin bump de versión.
- **Build number.** 13 → **14** en los 20 targets (convención: global creciente). Medido con `asc builds list`: el último es el 13.
- **Máquina y Xcode.** Mini (`Mini-de-Jurgen`), Xcode 27.0 **GA** (27A266a, no beta). Asumido: ASC acepta el SDK 27.0 GA; si lo rechazara, se para y se avisa.
- **Aislamiento.** Archive desde este worktree, en el commit del bump, con `-derivedDataPath` dentro del worktree (se borra al retirarlo).
- **Export.** `.asc/ExportOptions.plist` trae `destination=upload`; se usa una copia en el scratchpad con `destination=export` para sacar el `.ipa` y subirlo con `asc builds upload`, como pide el encargo.
- **Disco.** 7,8 GB libres al arrancar; se borraron dos DerivedData huérfanos (8,3 GB) de worktrees ya retirados.
- **Grupos de testers.** No se tocan (como en #116): llega al grupo interno; el externo necesitaría beta review, que es decisión de Jürgen.
