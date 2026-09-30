---
esfuerzo: high
---
# Relanzar CI propio Yala fases 4–7 (guiado) tras crash Mini — con guardrails anti-OOM

## Contexto
- Fases 1–3 already merged (PR #307/#308). Plan: ~/Claude/casa/docs/ci-propio-yala.md (ADR-053).
- Prior session `ci-fases-4-7-guiado` crashed/killed all Claude on the Mac Mini (no full reboot — 8d uptime; likely RAM pressure + load from shadow CI / sim / xcodebuild on 16 GB). Jürgen ordered relaunch + fix so this cannot happen again.
- Prior work already exists and was pushed: branch `encargo/2026-09-30-ci-fases-4-7-guiado` (commits through `61115ab87`: ci-sombra.yml, installer, DerivedData under `/Users/ci/DerivedData`, LaunchAgent-not-daemon switch, sim cleanup). Uncommitted WIP for `qa/scripts/ci-runner/instalar.sh` (LaunchAgent + visible `ci` user) saved at `~/Claude/tmp-frank/2026-09-30-ci-fases-4-7-instalar.sh.wip.diff` — apply it (or cherry-pick/merge that branch) before inventing a second installer.
- Old worktree still on disk: `~/Claude/worktrees/Yala-2026-09-30-ci-fases-4-7-guiado`. Prefer cherry-pick/merge those commits onto THIS branch rather than rewriting from scratch. Do not delete that worktree unless you finish and migrate cleanly.
- Runner `mini-ci` is ALREADY registered and listening under user `ci` (`/Users/ci/actions-runner`, label/work under `/Users/ci/_work`). Last sombra job Succeeded ~13:12 Lima. Do not re-register blindly; measure first.
- macOS user `ci` EXISTS (uid 502). Jürgen still owns: runner registration token if re-register needed (NOT via chat), later GitHub Pro + private repo + billing for self-hosted minutes.
- Public repo → fase 4 shadow runner must use workflow_dispatch only (not on every push). Existing `ci-sombra.yml` is the path.
- Casa pending for later auto-merge: ~/Claude/casa/encargos/pendientes/2026-09-29-cierre-con-auto-merge.md (fase 6 only after that if needed).
- Cola A / product tickets PAUSED — this session is CI only.
- Disk at relaunch: Data volume ~94% / ~13 GB free (BELOW the 15 GB floor). ExtDev has ~147 GB free but TCC blocked LaunchDaemon on ExtDev earlier — do not fill boot volume; stop and AskUserQuestion before heavy builds.

## Que se pide
1. Resume from fase 4 (shadow self-hosted runner): pull prior branch work; document exact steps for Jürgen; configure LaunchAgent under user `ci` (not daemon — prior measurement: unit tests ~1000× slower without Aqua session); DerivedData isolation under `/Users/ci/DerivedData`; workflow_dispatch-only while public.
2. HARD MACHINE SAFETY (non-negotiable — prior run crashed Mini sessions / OOM pressure):
   - Never spawn more than one heavy xcodebuild/test at a time on this machine.
   - Never open/boot Simulator fleets; do not use Cola A or adaptive simulators; if a smoke build needs a sim, use ONE named sim and shut it down when done (boot by UDID only if required; never `shutdown all` / `erase all` / `killall Simulator`).
   - Cap DerivedData: use dedicated path under the `ci` home (`/Users/ci/DerivedData`) or worktree-local; do not fill the boot volume; stop and AskUserQuestion if free disk on / or /Users (Data) drops below ~15 GB.
   - Do not run parallel Claude sessions, parallel lanes, or background stress loops.
   - Prefer documenting + configuring over live full-suite runs on the Mini; if a validation build is required, run the smallest possible job and stop on memory/disk pressure.
   - Do not install unbounded caches; prune after validation.
   - If an action risks OOM/disk death, stop and AskUserQuestion instead of pushing through.
   - Do not restart CoreSimulatorService for other users; do not touch Jürgen’s sims.
3. Then phases 5–7 only as far as unblocked without Jürgen: Pro/private (5), auto-merge wiring (6) after casa encargo if present, remaining docs/state (7). Anything needing Jürgen's password/token/billing → AskUserQuestion / Necesita de ti — never put secrets in chat.
4. Write a short durable note (docs or memory per Yala conventions) on Mini crash cause if found + the permanent guardrails for self-hosted CI on this Mini.

## Que NO hay que tocar
- No Cola A / adaptive / product tickets / marketing.
- No production Supabase deploy.
- No secrets in transcript/chat.
- No simctl mass shutdown/erase; no killall Simulator.

## Como se sabe que esta bien
- Session progresses fase 4 without crashing Mini; guardrails written; clear Necesita de ti for Jürgen-only steps; PR if code/docs changed; /cerrar-total when done.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Se reintegra el trabajo previo o se rehace?** → Se reintegra. Los 5 commits del intento anterior ya están en `origin/2.1`; lo único pendiente era el WIP de `instalar.sh` (LaunchAgent + `ci` visible), que se aplica tal cual (idéntico al del worktree viejo).
Por qué: el runner ya corre así en la Mini; el instalador del repo tiene que describir lo que hay. Alternativa descartada: reescribir, que duplicaría un instalador.

**D2 · ¿Se valida con una corrida en sombra?** → No en esta sesión. Disco a 12 GB (bajo el suelo de 15) y la última corrida coincidió con la caída. Los candados nuevos se prueban con `guardia.sh` en local (solo lectura) y en seco con umbrales forzados; la primera corrida real la lanza Jürgen cuando la Mini esté libre.
Por qué: el encargo manda documentar y configurar antes que correr suites en la Mini. Alternativa descartada: corrida mínima, que igual compila la app entera.

**D3 · ¿Qué candado protege a la Mini del CI?** → Tres, dentro del propio workflow: (1) `antes` espera hasta 20 min a disco ≥ 15 GB, RAM libre ≥ 35 %, cero `xcodebuild` y cero simuladores arrancados de cualquier usuario, y si no, cede con error; (2) un vigía de fondo para los `xcodebuild` **de `ci`** si la RAM libre baja del 12 % o el disco de 10 GB; (3) poda al final (últimos 3 xcresult, DerivedData > 20 GB se borra).
Por qué: la regla «una carga pesada a la vez» tiene que cumplirse aunque nadie se acuerde; el CI es el que cede. Alternativa descartada: solo documentarlo.

**D4 · ¿El usuario `ci` sobra?** → Se queda. Medido: ~1–1,5 GB en reposo; la carga real es la suite, que pesa igual con cualquier usuario. Separarlo protege el llavero y `~/Secrets` de Jürgen de un workflow. Recortar su sesión (ítems de inicio, Spotlight) queda como paso para Jürgen.

**D5 · Causa del crash** → **CPU, no memoria.** Ni `JetsamEvent` ni eventos de memoria del kernel; sí Time Machine activo de 12:40 a 13:13 e informes de CPU de `backupd` y Spotlight, a la vez que la suite en el simulador de `ci`. Grok, que lo vio en vivo, da carga ~37 y confirma que los tmux no colgaban de Grok Bot (la primera hipótesis de esta sesión, descartada). Los candados suman carga de CPU, Time Machine y `renice` del vigía.

**D6 · Fases 5–7** → 5 necesita a Jürgen (Pro, facturación, visibilidad); 6 espera al encargo de casa `2026-09-29-cierre-con-auto-merge`, que sigue en `pendientes/`; 7 solo lo de este PR. No se toca nada de 5–6.

**D7 · ¿Sigue adelante el runner local?** → **Aparcado; Yala sigue público** (Jürgen, 2026-09-30, contestado en sesión). En público GitHub es gratis y tarda lo mismo (25–38 min contra 31 en la Mini). El runner solo compensa en privado, y ahí antes hay que recortar el volumen de CI (~30.500 min/mes ≈ 17 h/día), que la Mini no absorbe mientras Jürgen trabaja. El runner queda instalado y sin uso; los candados se mergean igual.
