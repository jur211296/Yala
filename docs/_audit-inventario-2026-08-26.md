# Auditoría de inventario — repo Yala (rama 2.1)

**Fecha de medición:** 2026-08-26  
**Árbol medido:** `origin/2.1` tip `f4cf3d2b` («Build 12 para TestFlight de 2.1»), inventario escrito en rama `cursor/audit-inventario-docs-9e87`.  
**Qué es esto:** mapa factual del árbol y de la documentación que *este* repo contiene, más el plan de absorción **después** de la decisión del owner. Cero borrados, cero refactors, cero cambios de producto. **Este documento no absorbe ni mueve nada.**  
**Qué no es:** no vi el vault Obsidian (`jur211296/YalaWiki`). Donde `CLAUDE.md` apunta a `$VAULT/planning/*`, solo puedo afirmar que **esos ficheros no están en este repo**. No invento su contenido ni si están al día.

## Decisión del owner (2026-08-26) — no reabrir

**SSOT único = este repo Yala.** Tickets, NOW y DECISIONS se absorben a `docs/`. YalaWiki se archiva. Obsidian deja de ser SSOT (viewer opcional).

Las §§0–3 son la medición del árbol *antes* de absorber. Las §§4–8 son la propuesta de destino y el plan por fases. Nada de eso se ejecutó en este PR.

**Versión de producto verificada en `Yala.xcodeproj/project.pbxproj`:** `MARKETING_VERSION = 2.1`, `CURRENT_PROJECT_VERSION = 12`. Coincide con el último commit de `2.1`.

**Método:** `ls` de 1er/2º nivel, `git log -1` por ítem raíz y por docs clave, `git ls-files '*.md'`, greps de `Neto` / `2.0.5` / SSOTs, `du -sh`, cruce con `project.pbxproj`. Las fechas son del **último commit que tocó esa ruta**, no de mtime del checkout (el snapshot pone `Jan 1 1970` en el filesystem).

Leyenda de estado:

| Etiqueta | Significado |
|----------|-------------|
| **vivo** | Se tocó en julio–agosto 2026 y/o es contrato que CI o `CLAUDE.md` siguen citando |
| **espejo** | El propio fichero se declara copia; la SSOT está fuera (vault) |
| **stale** | El texto describe un estado que el árbol actual contradice |
| **histórico** | Snapshot de una auditoría/release pasada; no se actualiza como contrato |
| **marketing** | Copy, PNG, generador o assets de tienda/redes |
| **duplicado** | Misma carga útil en más de un sitio |
| **producto** | Código/tests/schemas de la app |
| **desconocido** | Sin evidencia suficiente para clasificar |

---

## 0. Lo que el árbol **no** confirma (hipótesis descartadas)

Estas cosas se mencionaron como posibles y **no existen** en este checkout:

| Hipótesis | Hecho medido |
|-----------|----------------|
| Hay un directorio `.planning/` | **Ausente.** `.gitignore` línea 46 ignora `.planning/` («Planning docs live in Obsidian vault»). |
| Hay `AGENTS.md` / `README.md` en la raíz | **Ausentes.** El único `AGENTS.md` está en `screenshots-appstore/generator/` (plantilla Next.js). |
| Hay `CODEBASE-MAP.md`, `UI-PATTERNS.md`, `SWIFT-STYLE.md`, `QA-SCENARIOS.md`, `STATE.md`, `ROADMAP.md`, `PROJECT.md`, `DECISIONS.md`, `DEVICE-QA.md`, `L10N.md`, `WORKFLOW.md`, `TESTING-STRATEGY.md` en el repo | **Cero matches** de `find` en el árbol. `CLAUDE.md` los cita como `$VAULT/planning/…`. |
| `docs/planning/` es el planning completo | Solo contiene `BRAND-VOICE.md`. |

---

## 1. Árbol anotado (1er y 2º nivel)

Tamaños: `du -sh` del checkout. «Último commit» = `git log -1` sobre esa ruta.

### 1.1 Raíz — producto vivo

| Ruta | Tamaño | Último commit | Propósito aparente | Estado |
|------|--------|---------------|--------------------|--------|
| `Yala/` | 127M | 2026-08-22 `74ddaf01` | App iOS: `App/`, `Models/`, `Services/`, `Utils/`, `Shared/`, `Resources/`, `Seed/`, `Configuration.storekit` | **producto / vivo** |
| `Yala.xcodeproj/` | 68K | 2026-08-22 `f4cf3d2b` | Proyecto Xcode. `MARKETING_VERSION=2.1`, build 12 | **producto / vivo** |
| `YalaTests/` | 3.1M | 2026-08-22 `74ddaf01` | Suite unitaria Swift Testing | **producto / vivo** |
| `YalaUITests/` | 272K | 2026-08-18 `a3552815` | XCUITest (`Flows/`, `Support/`) | **producto / vivo** |
| `YalaWidgets/` | 364K | 2026-08-14 `f05cc26a` | Extensión WidgetKit. Incluye `SETUP.md` (ver §2) | **producto / vivo** + doc **stale** |
| `YalaShare/` | 24K | 2026-04-26 `746abf04` | Share extension | **producto** (sin commits recientes; no implica muerto) |
| `qa/` | 1.3M | 2026-08-22 `74ddaf01` | Índice de cobertura, runner agent-device, hooks, scripts cloud | **vivo** (ver §3.1) |
| `gateway/` | 552K | 2026-08-12 `bc0bb256` | Cloudflare Worker (OpenAI, tasas, App Attest, grupos) | **producto / vivo**; `README.md` **stale** |
| `Cloudkit Schemas/` | 52K | 2026-07-28 `ed38c1ea` | 8 `.ckdb` (yala/groups × dev/prod × development/production) | **producto**; aún referenciado por `.claude/rules/swiftdata-cloudkit.md` |
| `capability_manifest.json` | 28K | 2026-07-07 `8975e68e` | SSOT del capability-set Modo Nube (I5) | **vivo** (contrato de sync) |
| `group_capability_manifest.json` | 8K | 2026-07-15 `b86dbf1c` | Mismo rol para el canal de grupos | **vivo** |
| `golden_vectors.json` | 4K | 2026-07-08 `28b466b3` | Vectores de coherencia tx_split | **vivo** |
| `hlc_conformance_vectors.json` | 4K | 2026-07-07 `aeaa7e08` | Vectores HLC c1 | **vivo** |
| `merkle_fixtures.json` | 4K | 2026-07-08 `50918362` | Fixtures Merkle canal personal | **vivo** |
| `groups_merkle_fixtures.json` | 8K | 2026-07-15 `b101f2c8` | Fixtures Merkle grupos | **vivo** |
| `supabase-staging.ddl` | 14K | 2026-07-07 `e1b627ec` | Molde offline schema personal staging | **vivo** (contrato) |
| `supabase-groups-staging.ddl` | 48K | 2026-08-12 `a9547b36` | Molde offline schema grupos staging | **vivo** |
| `Secrets.xcconfig.template` | 4K | 2026-01-29 `053a416d` | Plantilla de secrets (el `.xcconfig` real está gitignored) | **vivo** (onboarding de clone) |
| `scripts/asc-preflight.sh` | 8K | 2026-07-24 `95d0db0e` | Preflight App Store Connect | **vivo** |
| `.github/workflows/qa.yml` | — | 2026-07-06 `d582b493` | CI: `coverage-index` + isolation (Linux) y tests advisory (macos-26) | **vivo** |
| `.gitignore` | — | 2026-07-16 `cdd2b849` | Incluye `.planning/`, `.agents/`, `.asc/`, `Secrets.xcconfig` | **vivo**; contradice ficheros ya trackeados (ver §3.5) |

### 1.2 Raíz — contrato de agentes (mixto)

| Ruta | Tamaño | Último commit | Propósito aparente | Estado |
|------|--------|---------------|--------------------|--------|
| `CLAUDE.md` | 8K | 2026-08-06 `6c74db82` | Contrato del agente: stack, vault, reglas inviolables, workflow, QA SSOT | **vivo** |
| `.claude/` | 824K | 2026-08-18 `e6592d53` | `rules/`, `commands/`, `agents/`, `skills/`, `workflows/`, `settings.json`, `launch.json` | **vivo** (rules/commands recientes); skills vendor **duplicado** |
| `EXECUTION-RULES.md` | 4K | 2026-01-16 `aa67541e` | Qué comandos puede correr Claude solo. Cita `/gsd:*`, `/session-start`, `PROJECT.md`… | **stale** (ver §3.3) |
| `skills/` | 20K | 2026-07-28 `90ebabea` | **4 symlinks** a `.agents/skills/{swift-concurrency,swiftdata,swift-testing,swiftui}-pro` | **duplicado** |
| `.agents/` | 432K | 2026-04-21 `9ecd7574` | Copia vendor de 5 skills. `.gitignore` línea 49 dice ignorar `.agents/` | **duplicado**; trackeado pese al ignore |
| `.agent/` | 24K | 2026-01-13 `aebf43a6` | Solo `workflows/ui-patterns.md` titulado «Neto UI Patterns» | **stale / Neto** |
| `skills-lock.json` | 4K | 2026-04-06 `a354a2ae` | Lock de `swiftui-expert-skill` (fuente GitHub) | **desconocido** si el install path actual lo usa |
| `agent-device.json` | 4K | 2026-03-21 `6ecdd302` | Config `{platform:ios, session:yala-qa}` para el runner QA | **vivo** (lo usa `qa/`) |
| `.qa-test-data/` | 40K | 2026-01-22 `cbfe3556` | CSVs de import. README dice «Neto iOS» | **stale** (título Neto); uso actual **desconocido** (cero refs en código/docs de producto) |
| `.asc/` | 8K | 2026-04-21 `9ecd7574` | `ExportOptions.plist` trackeado. `.gitignore` ignora `.asc/` | **vivo?** (export ASC); ignore vs tracked |
| `.vscode/settings.json` | 8K | 2025-12-03 `1845af51` | `{}` | **stale** (vacío) |
| `.vercelignore` | 4K | 2026-05-06 `6308a624` | Excluye Xcode, Spark, Instagram, App Store, qa, .claude del deploy web | **vivo** para el sitio |

### 1.3 Raíz — documentación histórica / diseño

| Ruta | Tamaño | Último commit | Propósito aparente | Estado |
|------|--------|---------------|--------------------|--------|
| `docs/` | 8.4M | 2026-08-12 `49ad02d5` | `planning/` (1 file), `modo-nube/` (espejo vault), `flows/` (atlas HTML 7.7M) | mixto: **espejo** + **vivo-anclado-a-2.0.5** |
| `AUDIT-UI-patterns.md` | 36K | 2026-06-04 `ec15d222` | Barrido UI 2026-06-03 (303 vistas, 122 agentes) | **histórico** (era 2.0) |
| `AUDIT-release-readiness.md` | 32K | 2026-06-10 `6165aed0` | Release readiness **Yala 2.0 build 19**, branch `2.0` | **histórico** |
| `AUDIT-security.md` | 8K | 2026-06-15 `4c8b4e3a` | Security review 2.0 (API key en IPA, CKShare) | **histórico**; el crítico de keys motivó `gateway/` |
| `AUDIT-appstore-guidelines.md` | 8K | 2026-06-15 `4c8b4e3a` | Guidelines 2.0; copy «exclusively on your device» | **histórico**; el hallazgo #1 **sigue en** `App Store/metadata/description-en.md:25` |
| `DESIGN-secure-proxy-gateway.md` | 20K | 2026-06-15 `60fa5607` | Diseño del gateway. Dice «No implementar hasta aprobar» | **stale** (el código existe y se tocó el 2026-08-12) |
| `DESIGN-telemetry-2.0.md` | 12K | 2026-06-16 `a4b8fba5` | Propuesta TelemetryDeck 2.0. «nada implementado» | **stale / superseded**: `Yala/Services/Metrics/MetricsService.swift` (2026-07-17+) dice que **sustituye TelemetryDeck** |
| `Yala - Guia Release App Store Connect.docx` | 24K | 2026-04-09 `7b1ebf4f` | Guía ASC (binario). No leído por dentro | **histórico** (v1.2 era); contenido **desconocido** sin unzip |
| `build_output.txt` | 16K | 2026-01-13 `aebf43a6` | Log de `xcodebuild -scheme Neto` desde `/Users/jur/Desktop/Neto` | **histórico / Neto**; no es doc de proceso |

### 1.4 Raíz — marketing y web

| Ruta | Tamaño | Último commit | Propósito aparente | Estado |
|------|--------|---------------|--------------------|--------|
| `Web/` | 67M | 2026-06-19 `5e8a302a` (dir); `src/` 2026-06-14 | Sitio Astro. 59M son `Web/Screenshots/`. `README.md` es el starter de Astro | **marketing / 2.0**; README **stale** |
| `screenshots-appstore/` | 52M | 2026-08-03 `995d52a0` | Generador Next.js + `daily-post/` (36 PNG en `out/`) + `captions.md` | **marketing / vivo** |
| `App Store/` | 32M | 2026-07-28 `90ebabea` (tocó `build-25/ExportOptions.plist`); metadata 2026-03-17; whats-new 2026-06-15 | metadata 7 locales, whats-new hasta **v2.0**, PNG iPhone/iPad, archives build 25/26, script extra-locales 2.0 | **marketing**; copy de ficha **stale vs 2.1** (ver §3.4) |
| `Instagram/` | 24M | 2026-03-17 `5db085b2` | 8 carpetas `POSTS-*` (40 PNG, campañas 1.x/1.2) | **marketing / stale** frente al generador de agosto |
| `Yala_Spark_Assets_{DARK,LIGHT,NEON,ORIGINAL}-2/` | 0.3–2.7M | 2026-01-28 `46170f2b` | Packs Spark (Headers/iOS/iPad/Mac/Store/Web). **Cero refs** en `project.pbxproj` | **marketing**; uso en la app **no evidenciado** |
| `ReferenceAssets/` | 19M | 2026-01-24 `aa7adc70` («rebrand Neto to Yala») | `Neto_Logo_Header_ForDarkBG (1).png`, `…ForLightBG.png`, `Screenshots/Espanol/` | **marketing / Neto leftover** |
| `Demo/` | 16K | 2026-01-28 `46170f2b` | `demo_transactions.csv`. Cero refs en código | **desconocido** (fixture huérfano) |

### 1.5 Segundo nivel de carpetas que importan para docs

**`docs/`**

- `planning/BRAND-VOICE.md` — único planning en repo. Último commit 2026-07-27 (viaje en el commit de espejo modo-nube). Frontmatter interno: «Documentado: 2026-01-26». `CLAUDE.md` dice que BRAND-VOICE vive en el vault.
- `modo-nube/` — 17 md + `fase3-medicion/` (9 md). El `README.md` (2026-07-28) se declara **copia, no SSOT**.
- `flows/modo-nube/` — atlas HTML+JS (ELK), anclado a HEAD `5bbb5690` **branch 2.0.5** el 2026-08-12.

**`.claude/`**

- `rules/` (5): `testing.md`, `swiftui-ds.md`, `swiftdata-cloudkit.md`, `l10n.md`, `gateway-attest.md` — todos tocados 2026-07-24 … 2026-08-14. **Vivo.**
- `commands/` (13): `gate`, `verify-ios`, `qa`, `qa-sync`, `cerrar`, `commit-one`, `spec`, `review-plan`, `idea`, `backlog`, `bug-triage`, `l10n-check`, `swift-audit`. Los de workflow actual (`gate` 2026-08-02, `cerrar` 2026-08-18) están vivos. `idea.md` es del **2026-01-16** y escribe en `STATE.md` (ausente).
- `agents/` (3): `branch-auditor`, `swift-reviewer`, `test-generator` — último toque feb–mar 2026.
- `skills/`: vendor (swift-*) + `bugfix`, `ui-ux-pro-max`, `swiftui-expert-skill`, `mermaid-visualizer`, `excalidraw-*`, `obsidian-canvas-creator`.
- `workflows/`: `ui-audit.js`, `full-review.js`.
- `settings.json`: hooks que hardcodean `cd /Users/jur/Yala` (SessionStart disk-report, Stop push). Ruta de máquina del owner, no portable.
- `launch.json`: `yala-web` (Astro :4321) y `yala-screenshots` (bun :3000).

**`qa/`**

- `coverage-index.json` (594K, 134 áreas) — **SSOT declarado**.
- `manifest.json` — **se auto-declara DEPRECATED**.
- `_deprecated/` — fixtures JSON rotos (decisión D4, 2026-06-01).
- `suites/` 01–15: 70 JSON agent-device.
- `fixtures/`: 3 JSON vivos.
- `scripts/`: `precommit-gate.sh`, `worktree-stamp.sh`, `disk-report.sh`, `session-cleanup.sh`, `add-l10n-key.sh`.
- `hooks/`: `install.sh`, `pre-push`.
- `cloud/`: SQL + shells de contrato staging (README largo, vivo como runbook).
- `prompts/`: 4 prompts de traducción + README.
- `audits/`: 2 txt `M0.5_*`.
- `runner.sh`, `validate-coverage.sh/.py`, `qa-sync.py`, `check-test-isolation.sh`.

**`App Store/`**

- `metadata/` 7 descriptions (de/en/es/fr/it/pt-br/pt-pt) — último commit **2026-03-17**.
- `metadata-2.0-extra-locales.md` — 2026-06-18 (nl/pl/ja/zh-Hans).
- `whats-new/` v1.0.1 … **v2.0** — no hay `v2.1.md`.
- `PNG-iphone-ESPAÑOL` (20), `PNG-iphone-INGLES` (10), `PNG-ipad-*` (8+8).
- `ARCHIVE-build-25.md`, `ARCHIVE-build-26.md` — runbooks de archive 2.0 en «Mac estable» (junio 2026).
- `build-25/ExportOptions.plist`, `asc-extra-locales-2.0.py`.

**`Web/`**

- `src/`, `public/`, `Screenshots/` (59M), `CAMBIOS-LEGALES-2.0-DRAFT.md`, `REDISENO-WEB-2.0.md`, `README.md` (starter Astro), `test.txt` («It Works»), `build_out.txt` (log de `astro build`).

---

## 2. Inventario de documentación (md / docx / json de proceso)

Excluyo JSON de asset catalogs (`Contents.json`) y `package.json`. Incluyo JSON que un agente usaría como contrato o índice.

### 2.1 Contrato de sesión (raíz + `.claude/`)

| Fichero | Último commit | Rol declarado / observado |
|---------|---------------|---------------------------|
| `CLAUDE.md` | 2026-08-06 | Entrada del agente. Dos superficies: ticket vault + `.claude/rules/`. QA SSOT = `qa/coverage-index.json`. |
| `EXECUTION-RULES.md` | 2026-01-16 | Era GSD: `/verify-quick`, `/test-ios`, `/test-smart`, `/uitest-ios`, `/commit-checkpoint`, `/session-start`, `/gsd:next`. **Ninguno de esos command files existe.** |
| `.claude/rules/testing.md` | 2026-08-06 | Invariantes de tests; apunta a `$VAULT/planning/TESTING-STRATEGY.md` (no en repo). |
| `.claude/rules/swiftui-ds.md` | 2026-08-08 | DS / presentaciones; apunta a `UI-PATTERNS.md` y `SWIFT-STYLE.md` (no en repo). |
| `.claude/rules/swiftdata-cloudkit.md` | 2026-08-14 | SwiftData / CloudKit / grupos. |
| `.claude/rules/l10n.md` | 2026-07-24 | 16 locales. |
| `.claude/rules/gateway-attest.md` | 2026-08-12 | Asimetría observe/enforce de App Attest. |
| `.claude/commands/gate.md` | 2026-08-02 | Gate único pre-commit. |
| `.claude/commands/verify-ios.md` | 2026-07-24 | Build rápido. |
| `.claude/commands/qa.md` | 2026-07-24 | QA visual por lotes `qa_`. |
| `.claude/commands/qa-sync.md` | 2026-06-01 | Auditoría del coverage-index. |
| `.claude/commands/cerrar.md` | 2026-08-18 | Cierre de sesión + disco. |
| `.claude/commands/commit-one.md` | 2026-07-24 | Commit atómico. |
| `.claude/commands/spec.md` | 2026-05-25 | Spec **en el vault** (`YalaWiki/Backlog/`). |
| `.claude/commands/review-plan.md` | 2026-05-25 | Review de Plan Mode. |
| `.claude/commands/idea.md` | 2026-01-16 | Escribe Parking Lot en **`STATE.md`** (fichero ausente). `CLAUDE.md` describe `/idea` como captura a vault. |
| `.claude/commands/backlog.md` | 2026-05-25 | Lee vault `Backlog/`; también dice «revisa STATE.md». |
| `.claude/commands/bug-triage.md` | 2026-07-24 | Triage de bugs. |
| `.claude/commands/l10n-check.md` | 2026-07-24 | Paridad l10n. |
| `.claude/commands/swift-audit.md` | 2026-05-25 | Audit de calidad en diffs. |
| `.claude/agents/*.md` | 2026-02-01 / 2026-03-12 | Subagentes reviewer / test-generator / branch-auditor. |
| `.claude/settings.json` | (dentro de `.claude` 2026-08-18) | Hooks + path absoluto `/Users/jur/Yala`. |
| `.claude/launch.json` | — | Launchers web + screenshots. |
| `.agent/workflows/ui-patterns.md` | 2026-01-13 | Patrones UI **Neto** (`NetoToolbarButton`, `NetoFormatter`). |

### 2.2 QA

| Fichero | Último commit | Rol |
|---------|---------------|-----|
| `qa/coverage-index.json` | 2026-08-22 | **SSOT de cobertura** (schema `_schema.description`, `CLAUDE.md`, CI `qa.yml`, `qa/README.md`). 134 áreas. Validado en esta sesión: `python3 qa/validate-coverage.py` → OK (warnings de scenarioIDs vacíos, no bloquean). |
| `qa/manifest.json` | 2026-06-01 | Texto propio: «DEPRECATED — superseded by qa/coverage-index.json». |
| `qa/README.md` | (dir qa 2026-08-22) | Runner agent-device. Línea 50: los scripts «map to `QA-SCENARIOS.md`» (no está en el repo). Línea 81: confirma SSOT = coverage-index. |
| `qa/_deprecated/README.md` | 2026-06-01 | Fixtures JSON rotos; no se reparan (D4). |
| `qa/cloud/README.md` | — | Runbook staging RLS / goldens / migraciones g*. Largo y operativo. |
| `qa/prompts/README.md` + `translate-{ja,nl,pl,zh-Hans}.md` | — | Prompts de traducción. |
| `qa/audits/M0.5_*.txt` | — | Dumps de Info.plist / keys legacy. |
| `.qa-test-data/README.md` | 2026-01-22 | «CSV de Prueba para QA - Neto iOS». |

### 2.3 `docs/`

| Fichero | Último commit | Rol |
|---------|---------------|-----|
| `docs/planning/BRAND-VOICE.md` | 2026-07-27 | Tono de marca. Fecha interna 2026-01-26. `CLAUDE.md` lo lista como vault. |
| `docs/modo-nube/README.md` | 2026-07-28 | **«NO son la SSOT»** — espejo de `$VAULT/Backlog/modo-nube/`. |
| `docs/modo-nube/MODO-NUBE-DECISION-RELEASE-2.1.md` | 2026-08-06 | Decisión owner: 2.1 ON, sin dark shipping. **Supersede** de `MODO-NUBE-ESTRATEGIA-RELEASE.md`. |
| `docs/modo-nube/MODO-NUBE-ESTRATEGIA-RELEASE.md` | 2026-07-27 | Dark shipping / 2.0.5. El doc de decisión 2.1 lo declara reemplazado. |
| `docs/modo-nube/MODO-NUBE-DIFERIDOS.md` | 2026-08-11 | Registro de diferidos. |
| `docs/modo-nube/MODO-NUBE-ROLLBACK.md` | 2026-08-06 | Rollback; habla de rama `2.0.5` y build 9. |
| `docs/modo-nube/MODO-NUBE-AUDITORIA-ESCENARIOS.md` | 2026-07-28 | Auditoría sobre `/Users/jur/Yala` **branch 2.0.5**. |
| `docs/modo-nube/MODO-NUBE-DECISIONES-ESCENARIOS.md` | 2026-07-28 | 7 decisiones owner (2026-07-27, 2.0.5). |
| `docs/modo-nube/MODO-NUBE-PLAN-SIMPLIFICACION-GRUPOS.md` | 2026-08-05 | Plan; header dice branch `2.0.5`. |
| `docs/modo-nube/MODO-NUBE-HANDOFF-2026-07-28.md` | 2026-07-30 | Handoff de sesión; cita bug TestFlight 2.0.5. |
| `docs/modo-nube/MODO-NUBE-FASE{1,2,3}-BRIEF.md` | 2026-07-28 / 07-29 / 08-04 | Briefs de fase; Fase 1 dice «Repo `/Users/jur/Yala`, branch `2.0.5`». |
| `docs/modo-nube/MODO-NUBE-REVISION-TANDA1-ALCANCE.md` | 2026-07-28 | Veredicto tanda, branch 2.0.5. |
| `docs/modo-nube/MODO-NUBE-G0-GUION-DEVICE.md` | 2026-07-15 | Guion device. |
| `docs/modo-nube/MODO-NUBE-GRUPOS-V1-DECISION.md` | 2026-07-27 | Decisión grupos v1 (evidencia 2026-07-13, 2.0.5). |
| `docs/modo-nube/MODO-NUBE-GRUPOS-BACKEND-V1-DISENO.md` | 2026-07-16 | Diseño backend grupos. |
| `docs/modo-nube/groups-backend-v1.md` | 2026-07-16 | Log de implementación. |
| `docs/modo-nube/fase3-medicion/*.md` (9) | 2026-08-04 | Mediciones contra HEAD `ca06cfd5` / `dbb0bab3` **branch 2.0.5**. |
| `docs/flows/modo-nube/README.md` | 2026-08-12 | Atlas de 11 recorridos. Anclaje: HEAD `5bbb5690` **2.0.5**. |

### 2.4 AUDIT / DESIGN / release

| Fichero | Fecha interna / commit | Rol |
|---------|------------------------|-----|
| `AUDIT-UI-patterns.md` | 2026-06-03 / 06-04 | Snapshot UI 2.0. |
| `AUDIT-release-readiness.md` | 2026-06-10 | «LISTO PARA RELEASE» **2.0 build 19**. Cita `$VAULT/planning/RELEASE-QA-2.0.md`. |
| `AUDIT-security.md` | 2026-06-14 | Crítico: API key en IPA. |
| `AUDIT-appstore-guidelines.md` | 2026-06-14 | Copy de privacidad vs OpenAI. |
| `DESIGN-secure-proxy-gateway.md` | 2026-06-15 | Diseño; «no implementar». El worker ya está. |
| `DESIGN-telemetry-2.0.md` | 2026-06-16 | Propuesta TelemetryDeck. **Superseded** por `MetricsService`. |
| `Yala - Guia Release App Store Connect.docx` | 2026-04-09 | Guía ASC binaria. |
| `App Store/ARCHIVE-build-25.md` | — | Runbook archive build 25 (2.0). |
| `App Store/ARCHIVE-build-26.md` | 2026-06-19 | Runbook archive build 26 (2.0). |

### 2.5 Marketing / web / widgets

| Fichero | Último commit | Rol |
|---------|---------------|-----|
| `App Store/metadata/description-*.md` (7) | 2026-03-17 | Ficha de tienda. EN aún afirma almacenamiento exclusivo en device + «store nothing on servers». |
| `App Store/metadata-2.0-extra-locales.md` | 2026-06-18 | Extra locales 2.0. |
| `App Store/whats-new/v1.0.1.md` … `v2.0.md` | 2026-06-15 (whats-new) | No hay what's new 2.1. `WhatsNewConfig.swift` solo tiene cases `1.1`, `1.2`, `2.0`. |
| `Web/README.md` | 2026-01-13 | Plantilla «Astro Starter Kit: Minimal». |
| `Web/CAMBIOS-LEGALES-2.0-DRAFT.md` | 2026-06-14 | Draft legal 2.0 (IA + Grupos iCloud). |
| `Web/REDISENO-WEB-2.0.md` | 2026-06-14 | Rediseño web 2.0; Grupos «vía iCloud», badge Beta. |
| `Web/src/pages/privacy_content.md` | — | Referencia ES no renderizada. |
| `Web/test.txt` | — | «It Works». |
| `Web/build_out.txt` | — | Log de build Astro. |
| `screenshots-appstore/captions.md` | — | Captions Instagram (brand voice). |
| `screenshots-appstore/{generator,daily-post}/README.md` | 2026-08-03 (dir) | Generador vivo + posts diarios. |
| `screenshots-appstore/generator/{AGENTS,CLAUDE}.md` | — | Convenciones del subproyecto Next. |
| `YalaWidgets/SETUP.md` | 2026-02-02 | Cómo **crear** el target Widget (iOS 18+). El target ya existe; `CLAUDE.md` dice iOS 26+. |
| `gateway/README.md` | 2026-07-31 | Cabecera: «Estado: **scaffold** (task #1)». El código del worker se tocó el 2026-08-12 (grupos, attest, enc). |
| `Instagram/` | 2026-03-17 | PNG de 8 campañas. Sin markdown propio. |

### 2.6 JSON de proceso / contrato (no asset catalogs)

| Fichero | Rol |
|---------|-----|
| `qa/coverage-index.json` | SSOT QA |
| `qa/manifest.json` | Índice viejo, self-deprecated |
| `capability_manifest.json` / `group_capability_manifest.json` | Contrato de sync |
| `golden_vectors.json` / `hlc_conformance_vectors.json` / `merkle_fixtures.json` / `groups_merkle_fixtures.json` | Oráculos de codec/Merkle |
| `skills-lock.json` | Lock de un skill GitHub |
| `agent-device.json` | Config runner QA |
| `.claude/settings.json` / `.claude/launch.json` | Runtime Claude |
| `screenshots-appstore/daily-post/{content,state}.json` | Estado del generador diario |

### 2.7 Skills vendor (tres árboles)

Hashes de `SKILL.md` de los 4 skills solapados: **idénticos** en `skills/` (vía symlink), `.claude/skills/` y `.agents/skills/`.

| Árbol | Contenido |
|-------|-----------|
| `skills/` | 4 **symlinks** → `.agents/skills/…` |
| `.agents/skills/` | `swift-concurrency-pro`, `swiftdata-pro`, `swift-testing-pro`, `swiftui-pro`, `swiftui-expert-skill` (68 files trackeados) |
| `.claude/skills/` | Esos 5 + `bugfix` (Yala), `ui-ux-pro-max`, `mermaid-visualizer`, `excalidraw-diagram`, `excalidraw-diagram-obsidian`, `obsidian-canvas-creator` |

`.gitignore` línea 48–49: «Agent skills (third-party, reinstall via: npx skills add)» + `.agents/`. Los 68 files de `.agents/` **siguen trackeados** (`git ls-files -v` marca `H` assume-unchanged en al menos un SKILL.md).

---

## 3. Contradicciones y duplicados (con evidencia)

### 3.1 Dos (en realidad tres) superficies de QA

| Superficie | Qué dice de sí misma | Evidencia |
|------------|----------------------|-----------|
| `qa/coverage-index.json` | «SSOT de QA de Yala» | `_schema.description`; `CLAUDE.md` §Regla QA; `qa/README.md` §Coverage; CI job `coverage-index` en `.github/workflows/qa.yml` |
| `qa/manifest.json` | «DEPRECATED — superseded by qa/coverage-index.json» | Línea 3 del JSON; último commit 2026-06-01 |
| `QA-SCENARIOS.md` | Narrativa humana de escenarios | Citado por coverage-index y `qa/README.md`. **No está en este repo.** `CLAUDE.md` lo pone en el vault. |

No hay dos SSOTs *ejecutables* en el repo: el índice viejo se declara muerto. El hueco es que la narrativa de escenarios y DEVICE-QA **no viajan con el git**.

`qa/README.md` todavía enseña `./qa/runner.sh` como quick start y mapea scripts a números de `QA-SCENARIOS.md`. Eso convive con la regla de `CLAUDE.md`: deterministic → XCUITest, agentic → `/qa`. No es contradicción de SSOT; es doc del runner que no se reescribió cuando el índice cambió de eje (secciones 1–15 → áreas).

### 3.2 Vault vs repo (la brecha de sesión desde cero)

`CLAUDE.md` (2026-08-06) define **dos superficies**: ticket vault + `.claude/rules/`. La tabla «Docs (leer cuando sea relevante)» apunta **toda** la arquitectura/estilo/QA narrativa al vault:

`CODEBASE-MAP`, `UI-PATTERNS`, `SWIFT-STYLE`, `L10N`, `DEVICE-QA`, `BRAND-VOICE`, `WORKFLOW`, `PROJECT`, `ROADMAP`, `STATE`, `DECISIONS`, `QA-SCENARIOS`.

En este repo, de esa lista, **solo aparece** `docs/planning/BRAND-VOICE.md` (y `docs/modo-nube/README.md` lo cita como `../planning/BRAND-VOICE.md`).

Consecuencia medida: un agente en un clone limpio (esta sesión) **no puede** leer el mapa de Services/ViewModels, ni UI-PATTERNS, ni TESTING-STRATEGY, ni STATE. Puede leer `CLAUDE.md` + `.claude/rules/` + `qa/coverage-index.json`. Eso es el set real de arranque hoy, no el que el propio `CLAUDE.md` enumera.

`docs/modo-nube/README.md` es explícito: las copias existen porque el vault **no sincroniza por git**. El planning general no recibió el mismo tratamiento (salvo BRAND-VOICE).

### 3.3 `EXECUTION-RULES.md` vs workflow actual

| `EXECUTION-RULES.md` (2026-01-16) | Árbol 2026-08-26 |
|-----------------------------------|------------------|
| Comandos `/verify-quick`, `/test-ios`, `/test-smart`, `/uitest-ios`, `/commit-checkpoint`, `/session-start`, `/session-end`, `/checkpoint`, `/gsd:next`, `/gsd:resume`, `/review-parking-lot` | **No hay** esos ficheros en `.claude/commands/` |
| Leer `PROJECT.md`, `ROADMAP.md`, `STATE.md`, `UI-PATTERNS.md` | **No están** en el repo |
| «Implementar y detener»; no correr `/verify-ios` solo | `CLAUDE.md` coincide en espíritu; el comando vivo de verificación es `/gate` (2026-08-02) |

`CLAUDE.md` §Control de Ejecución (git una vez, no encadenar tests) **solapa** la mitad útil de EXECUTION-RULES. El resto es era GSD.

### 3.4 2.0 / 2.0.5 / 2.1

Producto en pbxproj y tip de `2.1`: **2.1 (12)**.

| Sitio | Qué afirma |
|-------|------------|
| `docs/modo-nube/MODO-NUBE-DECISION-RELEASE-2.1.md` | «todo lo de 2.0.5 sale como 2.1 ON». `updated: 2026-08-04` en frontmatter; último commit 2026-08-06. |
| `docs/modo-nube/MODO-NUBE-ESTRATEGIA-RELEASE.md` | Dark shipping, publicar 2.0.5/2.1 dormido. **Superseded** por el doc de arriba; el fichero sigue en el árbol. |
| Casi todo `docs/modo-nube/*.md` y `fase3-medicion/` | Headers «branch `2.0.5`», HEAD `ca06cfd5` / `dbb0bab3`. |
| `docs/flows/modo-nube/README.md` | Medido contra HEAD `5bbb5690` **2.0.5** el 2026-08-12 (mismo día que el último commit de `docs/`). |
| `App Store/whats-new/` | Último = `v2.0.md`. |
| `Yala/App/Views/WhatsNew/WhatsNewConfig.swift` | `switch` sin case `"2.1"` → `default: return nil`. |
| `AUDIT-release-readiness.md` | Branch `2.0`, build 19, 2766 tests. |
| `Web/REDISENO-WEB-2.0.md` | Grupos «vía iCloud», badge Beta. |
| `App Store/metadata/description-en.md:25` | «stored exclusively on your device» / «store nothing on servers» — **sigue ahí** (AUDIT-appstore 2026-06-14 lo marcó). Incompatible con modo nube 2.1 si esa ficha se reusa sin editar. |

### 3.5 Neto vs Yala

Rebrand medido: commit `aa7adc70` 2026-01-24 («rebrand Neto to Yala»). Lo que **sigue diciendo Neto** (nombre de producto, no la palabra contable «neto»):

| Sitio | Evidencia |
|-------|-----------|
| `build_output.txt` | Log entero de scheme `Neto` / `Neto.xcodeproj` / `/Users/jur/Desktop/Neto`. |
| `.agent/workflows/ui-patterns.md` | Título y componentes `NetoToolbarButton`, `NetoSaveButton`, `NetoFormatter`. |
| `.qa-test-data/README.md` | «CSV de Prueba para QA - Neto iOS»; «categorías seed de Neto 1.0». |
| `ReferenceAssets/Neto_Logo_Header_For*.png` | Logos con el nombre viejo. |

Los hits de `Neto` en Swift (`GroupsViewModel`, tests de debt) son la **palabra financiera** (balance neto), no el brand. No son leftover de rebrand.

### 3.6 Skills triplicados + ignore que no ignora

Mismo `SKILL.md` (md5 idéntico) en tres sitios para 4 paquetes. `skills/` no es una tercera copia en disco: son **symlinks** a `.agents/skills/`. `.claude/skills/` sí es copia real. `.gitignore` pide no versionar `.agents/`; git todavía los tiene.

### 3.7 DISEÑOs que el código ya dejó atrás

| Doc | Afirma | Código hoy |
|-----|--------|------------|
| `DESIGN-secure-proxy-gateway.md` | Borrador; no implementar | `gateway/` existe; último commit 2026-08-12 |
| `gateway/README.md` | «scaffold (task #1)» | Mismo README se tocó 2026-07-31 (secrets G7/G8) pero la cabecera no se actualizó |
| `DESIGN-telemetry-2.0.md` | Propuesta TelemetryDeck; App ID hardcodeado | `MetricsService.swift`: «Telemetría propia mínima (2026-07-17, sustituye TelemetryDeck)» |
| `YalaWidgets/SETUP.md` | Crear target, iOS 18+ | Target existe; `CLAUDE.md` target iOS 26+ |
| `Web/README.md` | «Astro Starter Kit: Minimal. Delete this file.» | El sitio tiene src/i18n, legales 2.0, 67M de assets |

### 3.8 Comandos que escriben a ficheros que no existen

- `.claude/commands/idea.md` → `STATE.md` sección Parking Lot.
- `.claude/commands/backlog.md` → «revisa STATE.md».
- `CLAUDE.md` describe `/idea` como captura a vault y `/spec` como plan en el ticket del vault.

Tres instrucciones distintas para «dónde vive una idea» (STATE.md / vault Ideas / vault Backlog). STATE.md no está en el git.

### 3.9 Settings no portables

`.claude/settings.json` SessionStart/Stop: `cd /Users/jur/Yala && …`. En esta VM ese path no existe. El disk-report del SessionStart no corre aquí. No es un bug de producto; sí es un contrato de agente atado a una máquina.

---

## 4. Árbol destino en `docs/` (propuesta — no creado)

SSOT = este repo. Obsidian, si se usa, **solo lee** estos paths (viewer). No se escribe al vault.

Hoy `docs/` tiene `planning/BRAND-VOICE.md`, `modo-nube/` y `flows/`. Faltan las carpetas de tickets y el planning vivo. El vault **no está en este clone**: las filas «absorber» asumen que esos *nombres* existen allí porque `CLAUDE.md` y `.claude/commands/` los citan. **No afirmé que el fichero esté, ni su contenido.**

```
docs/
├── README.md                 # índice: qué leer en una sesión desde cero
├── backlog/                  # tickets de producto (antes $VAULT/Backlog/)
├── bugs/                     # tickets de bug (antes $VAULT/Bugs/)
├── ideas/                    # captura /idea (antes $VAULT/Ideas/)
├── attachments/              # PNG de /qa (antes $VAULT/Attachments/)
├── planning/
│   ├── NOW.md                # qué está en curso (rol de STATE.md / Parking Lot)
│   ├── DECISIONS.md          # registro de decisiones
│   ├── CODEBASE-MAP.md       # si existe en el vault; CLAUDE.md ya pide actualizarlo
│   ├── UI-PATTERNS.md
│   ├── SWIFT-STYLE.md
│   ├── L10N.md
│   ├── DEVICE-QA.md
│   ├── TESTING-STRATEGY.md
│   ├── QA-SCENARIOS.md
│   ├── BRAND-VOICE.md        # YA está aquí (2026-01-26). Pasa de espejo a SSOT.
│   ├── WORKFLOW.md
│   ├── PROJECT.md
│   └── ROADMAP.md
├── modo-nube/                # YA está. Deja de ser «copia». Es SSOT de esa épica.
│   └── fase3-medicion/       # bitácora → fase D a archive/
├── flows/                    # YA está (atlas HTML). Se queda.
└── archive/                  # docs raíz stale + bitácoras (fase D)
    ├── AUDIT-*.md
    ├── DESIGN-*.md
    ├── EXECUTION-RULES.md
    ├── release-guia-asc.docx
    └── modo-nube/
```

Reglas de colocación:

| Cosa | Destino | No va a |
|------|---------|---------|
| Ticket vivo (feature / spec) | `docs/backlog/*.md` | `.planning/`, vault, raíz |
| Bug / `qa_*` | `docs/bugs/*.md` | |
| Idea sin spec | `docs/ideas/*.md` + línea en `planning/NOW.md` si hace falta | `STATE.md` en raíz (no existe; no se crea) |
| Decisión durable | `docs/planning/DECISIONS.md` | AUDIT/DESIGN en raíz |
| Gotcha que un agente no debe romper | se **queda** en `.claude/rules/` | `docs/` |
| Índice de cobertura ejecutable | se **queda** en `qa/coverage-index.json` | `docs/` |
| Snapshot de auditoría / diseño ya implementado | `docs/archive/` | raíz |

`NOW.md` vs `STATE.md`: el owner pidió `planning/NOW`. El comando `idea.md` hoy escribe un «Parking Lot» en `STATE.md` (ausente). En la absorción ese rol pasa a `docs/planning/NOW.md`. Si el vault solo tiene `STATE.md`, aterriza con ese rename y se anota.

`.planning/` (gitignored, ausente): no se usa. La SSOT es `docs/`.

`docs/modo-nube/briefs/` está en `.gitignore`. Si al absorber hay briefs que deban versionarse, hay que **dejar de ignorarlos** (fase A). Si son basura de sesión, se quedan ignorados o van a `docs/archive/`.

Tickets de modo-nube que vivan en `$VAULT/Backlog/modo-nube/`: aterrizan en `docs/backlog/` **o** se dejan en `docs/modo-nube/` (ya trackeado). No duplicar. Decisión en fase C según qué haya en el vault (no medido aquí).

---

## 5. Raíz: se queda / se mueve a `docs/archive/` / se borra (PR posterior)

Nada de esto se ejecutó. Clasificación de **docs y contratos en la raíz** (más `.claude/` y `qa/`, que el owner nombró). Marketing (`App Store/`, `Web/`, `Instagram/`, Spark) no es absorción de wiki: queda fuera de este plan salvo nota.

### 5.1 Se quedan donde están

| Ruta | Por qué |
|------|---------|
| `CLAUDE.md` | Contrato del agente. En fase A se **reescriben** los pointers `$VAULT/…` → `docs/…`. No se mueve. |
| `.claude/rules/` (5 md) | Reglas durables. El owner las dejó fuera de `docs/`. |
| `.claude/commands/` | Runtime. Fase C: paths vault → `docs/backlog\|bugs\|ideas\|planning`. No se archivan. |
| `.claude/agents/`, `workflows/`, `settings.json`, `launch.json` | Runtime. `settings.json` tiene `/Users/jur/Yala` — portable es otro PR. |
| `.claude/skills/bugfix/` | Skill de producto; apunta a `$VAULT/Bugs/`. Path-fix en fase C. Skills vendor: no es este plan. |
| `qa/` entero | SSOT **ejecutable** de cobertura + CI. No se mezcla con prosa. |
| `qa/README.md` | Se queda; fase A apunta escenarios a `docs/planning/QA-SCENARIOS.md` cuando exista. |
| `docs/` (planning / modo-nube / flows) | Casa de la SSOT. `modo-nube/README.md` deja de decir «NO son la SSOT» (fase B). |
| `Secrets.xcconfig.template` | Onboarding de clone. |
| Manifests, `*.ddl`, fixtures Merkle/HLC | Contratos de sync, no prosa. |
| `gateway/` | Código. `gateway/README.md` se reescribe **in situ** (fase E). |
| `README.md` (raíz) | **No existe.** Se crea en fase A. |

### 5.2 Se mueven a `docs/archive/` (PR posterior, no este)

| Ruta actual | Destino propuesto | Evidencia |
|-------------|-------------------|-----------|
| `AUDIT-UI-patterns.md` | `docs/archive/AUDIT-UI-patterns.md` | Snapshot 2026-06-03, era 2.0. |
| `AUDIT-release-readiness.md` | `docs/archive/AUDIT-release-readiness.md` | 2.0 build 19, branch `2.0`. |
| `AUDIT-security.md` | `docs/archive/AUDIT-security.md` | 2026-06-14; el gateway ya existe. |
| `AUDIT-appstore-guidelines.md` | `docs/archive/AUDIT-appstore-guidelines.md` | 2.0; el hallazgo #1 **sigue vivo** en metadata EN — al mover, no perder el pointer. |
| `DESIGN-secure-proxy-gateway.md` | `docs/archive/DESIGN-secure-proxy-gateway.md` | «No implementar»; living doc = `gateway/README.md`. |
| `DESIGN-telemetry-2.0.md` | `docs/archive/DESIGN-telemetry-2.0.md` | Superseded por `MetricsService`. |
| `EXECUTION-RULES.md` | `docs/archive/EXECUTION-RULES.md` | GSD 2026-01-16; comandos inexistentes. |
| `Yala - Guia Release App Store Connect.docx` | `docs/archive/Yala-Guia-Release-ASC.docx` | 2026-04-09, era 1.2. Renombrar para evitar espacios. |
| `App Store/ARCHIVE-build-25.md` | `docs/archive/app-store/ARCHIVE-build-25.md` | Runbook 2.0. |
| `App Store/ARCHIVE-build-26.md` | `docs/archive/app-store/ARCHIVE-build-26.md` | Runbook 2.0. |
| `docs/modo-nube/MODO-NUBE-ESTRATEGIA-RELEASE.md` | `docs/archive/modo-nube/MODO-NUBE-ESTRATEGIA-RELEASE.md` | Superseded por DECISION-RELEASE-2.1. Dejar nota en el doc vivo. |
| `docs/modo-nube/fase3-medicion/` | `docs/archive/modo-nube/fase3-medicion/` | Bitácora contra HEAD de `2.0.5`. |
| `YalaWidgets/SETUP.md` | `docs/archive/YalaWidgets-SETUP.md` | Guía de crear un target que ya existe. |
| `.agent/workflows/ui-patterns.md` | `docs/archive/neto-ui-patterns.md` | Neto, 2026-01-13. |

### 5.3 Se borran en un PR posterior (no este) — evidencia fuerte

| Ruta | Evidencia | Antes de borrar |
|------|-----------|-----------------|
| `build_output.txt` | Log `xcodebuild -scheme Neto` 2026-01-13. No es doc. | Nada. |
| `Web/test.txt` | Texto `It Works`. | Nada. |
| `Web/build_out.txt` | Log `astro build`. | Nada. |

### 5.4 Borrar o archivar — evidencia media / hipótesis (otro PR, dueño confirma)

No son la absorción wiki. Siguen en el árbol hasta decisión explícita.

| Ruta | Evidencia | Nota |
|------|-----------|------|
| `Web/README.md` | Starter Astro. | Reescribir, no borrar a ciegas. |
| `qa/manifest.json` | Self-deprecated. | Confirmar que `runner.sh` no lo lee. |
| `Instagram/` (24M) | Último commit 2026-03-17; pipeline vivo = `screenshots-appstore/`. | Marketing. |
| `Yala_Spark_Assets_*-2/` | No están en el pbxproj. | Marketing. |
| `ReferenceAssets/Neto_Logo_*.png` | Nombre Neto. | Histórico de marca. |
| `Demo/demo_transactions.csv` | Cero refs. | **Hipótesis** de desuso. |
| `.qa-test-data/` | README Neto; cero refs. | **Hipótesis** de desuso. |
| `App Store/PNG-*` | 32M; no hay evidencia de que sean 2.1. | **Desconocido** sin ASC. |
| `.agents/` + `skills/` (symlinks) | Copia de `.claude/skills/`. | Runtime; **desconocido** qué loader usa cada herramienta. |
| `docs/flows/modo-nube/` (7.7M) | Atlas anclado a 2.0.5. | Se **queda** por defecto. Archive solo si el owner lo declara muerto. |

### 5.5 No se tocan en la absorción

Producto (`Yala/`, tests, xcodeproj, widgets, share), `Cloudkit Schemas/`, manifests, `screenshots-appstore/`, `gateway/src`, CI.

---

## 6. Plan de absorción por fases (no ejecutado)

Orden: **primero el contrato de paths**, después el planning que desbloquea sesiones, después los tickets, después el archive, al final la basura. Así un agente no escribe al vault a mitad de mudanza.

### Fase A — Esqueleto y pointers (primero)

**Qué:** crear el árbol vacío (o con README de carpeta) y dejar de apuntar al vault. **Sin** copiar tickets todavía.

1. Crear `docs/backlog/`, `docs/bugs/`, `docs/ideas/`, `docs/attachments/`, `docs/archive/`, y en `docs/planning/` los stubs `NOW.md` y `DECISIONS.md` si aún no existen (este clone: no existen).
2. Añadir `docs/README.md` (índice) y `README.md` de raíz (schemes, iOS 26, «empieza por `CLAUDE.md` y `docs/README.md`»).
3. Reescribir `CLAUDE.md`: tabla de docs → `docs/planning/…`; borrar `$VAULT = ~/Library/Mobile Documents/…`; «dos superficies» pasa a **rules + `docs/`**.
4. `.gitignore`: quitar o comentar «Planning docs live in Obsidian vault» / `.planning/`. Revisar `docs/modo-nube/briefs/` si se van a versionar briefs.
5. `qa/README.md`: el mapa de escenarios apunta a `docs/planning/QA-SCENARIOS.md` cuando aterrice.

**Por qué primero:** a partir de aquí `/spec` y `/idea` no tienen un path oficial al vault. Si se absorbe contenido antes de cambiar pointers, la siguiente sesión sigue escribiendo en iCloud.

**Quién puede hacerlo:** cualquier clone. No necesita el vault.

### Fase B — Planning (segundo)

**Qué:** absorber `$VAULT/planning/*` → `docs/planning/`. Este CA **no tiene el vault**; lo hace una máquina donde iCloud esté montado, o un export del owner.

Orden de copia sugerido (nombres según `CLAUDE.md`, no inventados):

1. `DECISIONS.md`, `NOW.md` (o el STATE/NOW real — si el vault solo tiene `STATE.md`, aterriza como `docs/planning/NOW.md` y se anota el rename).
2. `CODEBASE-MAP.md` (desbloquea sesión desde cero).
3. `TESTING-STRATEGY.md`, `DEVICE-QA.md`, `QA-SCENARIOS.md`.
4. `UI-PATTERNS.md`, `SWIFT-STYLE.md`, `L10N.md`, `BRAND-VOICE.md` (el de `docs/planning/` ya existe: **diff contra vault** y gana el más reciente; no dejar dos).
5. `WORKFLOW.md`, `PROJECT.md`, `ROADMAP.md`.

Después: `docs/modo-nube/README.md` deja de decir «NO son la SSOT / escribí en el vault». Esos md **ya están** en el repo; no se vuelven a copiar salvo que el vault tenga `updated:` posterior (el propio README pide comprobar fechas).

**No** mover `.claude/rules/` a `docs/planning/`. Las rules se quedan; `testing.md` puede citar `docs/planning/TESTING-STRATEGY.md` en vez de `$VAULT/planning/TESTING-STRATEGY.md`.

### Fase C — Tickets (tercero)

**Qué:** `$VAULT/Backlog/` → `docs/backlog/`, `$VAULT/Bugs/` → `docs/bugs/`, `$VAULT/Ideas/` → `docs/ideas/`, `$VAULT/Attachments/` → `docs/attachments/` (peso de binarios: **hipótesis**, no medí el vault).

Luego reescribir paths en:

| Fichero | Path actual (medido) | Path nuevo |
|---------|----------------------|------------|
| `.claude/commands/spec.md` | `…/YalaWiki/Backlog/` | `docs/backlog/` |
| `.claude/commands/backlog.md` | idem + `STATE.md` | `docs/backlog/` + `docs/planning/NOW.md` |
| `.claude/commands/idea.md` | `STATE.md` Parking Lot | `docs/ideas/` + línea en `NOW.md` |
| `.claude/commands/bug-triage.md` | `$VAULT/Bugs/` | `docs/bugs/` |
| `.claude/commands/qa.md` | `$VAULT/Bugs/qa_*.md`, `Backlog/qa_*.md`, copy a `Attachments/` | `docs/bugs/`, `docs/backlog/`, `docs/attachments/` |
| `.claude/commands/commit-one.md` | ticket en Obsidian | ticket en `docs/backlog/` o `docs/bugs/` |
| `.claude/commands/cerrar.md` | `$VAULT/Backlog/` / `Bugs/` | mismos dirs en `docs/` |
| `.claude/skills/bugfix/SKILL.md` | `$VAULT/Bugs/` | `docs/bugs/` |
| `.claude/rules/testing.md` | `$VAULT/planning/TESTING-STRATEGY.md` | `docs/planning/TESTING-STRATEGY.md` |

Hasta que C cierre, un agente con el `CLAUDE.md` de A ya no debe crear tickets en el vault. Si el vault aún no se copió, **para** y no inventa tickets.

### Fase D — Archive de raíz (cuarto)

Mover la lista §5.2 a `docs/archive/`. Un commit, solo `git mv` + stubs si hace falta (p. ej. nota en DECISION-RELEASE-2.1: «ESTRATEGIA archivada»). Actualizar greps que citen `AUDIT-appstore-guidelines.md` en raíz (`Web/CAMBIOS-LEGALES-2.0-DRAFT.md` lo hace).

### Fase E — Limpieza y higiene (último)

1. Borrar §5.3 (`build_output.txt`, `Web/test.txt`, `Web/build_out.txt`).
2. Reescribir `gateway/README.md` (quitar «scaffold»).
3. Reescribir `Web/README.md` si se toca el sitio.
4. YalaWiki: archivar el repo espejo (fuera de este git). No borrar iCloud desde aquí.
5. Obsidian: si se conserva, apuntar a `docs/` de este clone, modo viewer.
6. Marketing Neto / Instagram / Spark / PNG ASC: **fuera de este plan**. Otro ticket.

### Qué no hacer en ninguna fase

- No borrar `qa/coverage-index.json` ni mezclarlo con prosa.
- No mover `.claude/rules/` a `docs/`.
- No reabrir «el vault es SSOT».
- No absorber en este PR (el de inventario).
- No `--no-verify` / force.

---

## 7. Hueco de «sesión desde cero» (sigue, hasta que B+C cierren)

Hoy un clone de `2.1` tiene:

1. Reglas inviolables → `CLAUDE.md` + `.claude/rules/`.
2. Cobertura ejecutable → `qa/coverage-index.json`.
3. Código y tests.
4. Épica nube (espejo, textos 2.0.5) → `docs/modo-nube/`.
5. Brand voice (copia 2026-01-26) → `docs/planning/BRAND-VOICE.md`.

Sigue faltando (aterriza en fase B, nombres según `CLAUDE.md`): mapa de arquitectura, UI-PATTERNS, TESTING-STRATEGY, DEVICE-QA, QA-SCENARIOS, NOW, DECISIONS, tickets. What's New / metadata 2.1 y el README del gateway son otro trabajo (fase E / marketing).

---

## 8. Checks de esta revisión

- Solo se editó `docs/_audit-inventario-2026-08-26.md`.
- `qa/scripts/precommit-gate.sh` no aplica (no hay `.swift` en staging).
- No se crearon carpetas destino. No se movió nada.

Validación de la medición original (sigue vigente):

- `python3 qa/validate-coverage.py` → **OK** (warnings de `scenarioIDs` / `lastVerified` vacíos; no fallan el ratchet).
- `bash qa/check-test-isolation.sh` → **OK** (48 archivos).

---

## 9. Cómo usar este fichero

La decisión de SSOT **ya está tomada** (cabecera). Este archivo es el mapa + el plan. El siguiente PR es la **fase A** (esqueleto + pointers), no un delete masivo ni la copia del vault.
