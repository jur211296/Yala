---
name: project-ci-propio-fases-4-a-7
description: Encargo CI propio + auto-merge (ADR-053): fase 4 con runner vivo y candados (2026-09-30, r2); qué espera cada fase 4-7 y a quién
metadata:
  type: project
---

Las fases 1-3 están mergeadas desde el 2026-09-30 (#307). La fase 4 quedó montada ese mismo día en la
segunda sesión (r2): el runner `mini-ci` está online como LaunchAgent en la sesión gráfica de `ci`, y
`ci-sombra.yml` lleva los candados de `guardia.sh`.

**APARCADO por decisión de Jürgen (2026-09-30): Yala sigue público.** En público GitHub es gratis e igual
de rápido; el runner solo compensa en privado, y antes hay que recortar el volumen de CI (~30.500 min/mes
≈ 17 h/día), que la Mini no absorbe. No retomes la fase 5 sin que él decida pasar a privado.

**Por qué sigue parado lo que sigue parado (si se retoma):**
- **4, validar los candados:** no se lanzó ninguna corrida en sombra en r2, porque el disco estaba
  en 12 GB, por debajo del suelo de 15. La primera corrida con candados la lanza Jürgen con la Mini
  libre. Tras un reinicio, el runner no vuelve hasta que alguien entra como `ci` una vez.
- **5 (privado):** Jürgen contrata GitHub Pro, confirma cuánto se cobra el minuto de runner propio
  y cambia la visibilidad.
- **6-7 (auto-merge):** esperan al encargo de casa `2026-09-29-cierre-con-auto-merge`, que el
  2026-09-30 seguía en `pendientes/`.

**Lo que se intentó y no funcionó:** el LaunchDaemon sin sesión. Compilaba, pero los tests iban
~1.000× más lentos. Tampoco funcionó el DerivedData en ExtDev, porque TCC bloquea el volumen
externo.

**La caída del 2026-09-30 a las 13:09 fue CPU, no memoria:** la suite en el simulador de `ci`,
Time Machine y Spotlight a la vez (carga ~37, según Grok). Mi primera hipótesis, que tmux colgaba
de Grok Bot, era falsa: el reinicio de Grok Bot fue un síntoma. Si vuelve a pasar, mira primero la
CPU (`backupd`, `spotlightknowledged` en DiagnosticReports) y no solo los Jetsam.

**How to apply:** antes de retomar, mide `gh api repos/jur211296/Yala --jq .private`, el estado
del runner (`gh api repos/jur211296/Yala/actions/runners`) y `bash qa/scripts/ci-runner/guardia.sh foto`.
Ver [[feedback_la_premisa_del_encargo_tambien_se_mide]].
