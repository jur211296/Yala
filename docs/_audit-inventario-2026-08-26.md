# Auditoría de inventario — repo Yala (rama 2.1)

**Fecha de medición:** 2026-08-26  
**Árbol medido:** `origin/2.1` tip `f4cf3d2b` («Build 12 para TestFlight de 2.1»), inventario escrito en rama `cursor/audit-inventario-docs-9e87`.  
**Qué es esto:** mapa factual del árbol y de la documentación que *este* repo contiene. Cero borrados, cero refactors, cero cambios de producto.  
**Qué no es:** no vi el vault Obsidian (`jur211296/YalaWiki`). Donde `CLAUDE.md` apunta a `$VAULT/planning/*`, solo puedo afirmar que **esos ficheros no están en este repo**. No invento su contenido ni si están al día.

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

## 4. Propuesta (no aplicada) — set mínimo en **este** repo

Objetivo declarado: un agente o humano abre el clone y tiene contexto para trabajar (arquitectura, cómo testear, cómo no romper, dónde están las reglas) **sin el vault**.

Hoy, sin vault, el clone da: `CLAUDE.md` + `.claude/rules/` + `qa/coverage-index.json` + código. **No da** mapa de arquitectura, patrones UI, estilo Swift, escenarios QA narrativos, STATE/ROADMAP, ni BRAND-VOICE «oficial» (hay una copia en `docs/planning/` de fecha 2026-01-26).

### 4.1 Lo que DEBERÍA vivir en el git (propuesta)

Un set corto. Todo lo demás o es código, o es vault, o es archive.

| # | Pieza | Ya está? | Nota |
|---|--------|----------|------|
| 1 | `README.md` de raíz | **No** | Una página: qué es Yala, schemes, iOS 26, cómo clonar+`Secrets.xcconfig`, «empieza por `CLAUDE.md`», pointer al vault y a `.claude/rules/`. Hoy no hay puerta de entrada humana. |
| 2 | `CLAUDE.md` | Sí | Mantenerlo como contrato del agente. Recortar la tabla vault a «si el vault está montado». |
| 3 | `.claude/rules/*.md` (5) | Sí | Esta es la SSOT de «cómo no romper». Encaja con la regla de dos superficies. |
| 4 | `.claude/commands/` vivos | Sí, con limpieza | `gate`, `verify-ios`, `qa`, `qa-sync`, `cerrar`, `commit-one`, `review-plan`, `l10n-check`, `swift-audit`, `bug-triage`. `spec`/`backlog`/`idea` solo sirven con vault — o se reescriben para fallar claro. |
| 5 | `qa/coverage-index.json` + `validate-coverage.*` + `qa/README.md` | Sí | SSOT de cobertura. El README debería dejar de depender de `QA-SCENARIOS.md` o copiar un índice mínimo. |
| 6 | Mapa de arquitectura **en el repo** | **No** (solo vault) | Un `docs/CODEBASE-MAP.md` (o el nombre que elijan) con tables de Services / VMs / tests. Sin esto, sesión desde cero = grep. `CLAUDE.md` ya pide actualizarlo al tocar modelos. |
| 7 | Cómo testear en device/sim | Parcial | `.claude/rules/testing.md` + `qa/README.md` cubren unit/XCUITest/runner. `DEVICE-QA.md` no está. Un extracto de launch args (`-uitest`, scheme Yala Dev, iPhone 17 Pro) cabe en el README o en `testing.md`. |
| 8 | Contratos de sync/backend | Sí | `capability_manifest.json`, `group_capability_manifest.json`, `*.ddl`, `gateway/README.md` **reescribiendo la cabecera scaffold**. |
| 9 | `Secrets.xcconfig.template` | Sí | Onboarding de clone. |
| 10 | Brand voice si se escribe copy en el repo | Copia 2026-01-26 | O se declara `docs/planning/BRAND-VOICE.md` SSOT del git, o se deja solo en vault y se borra la copia para no divergir. |

**No** meter en el git (propuesta): tickets, STATE/ROADMAP bitácora, briefs de fase, mediciones de un HEAD concreto, AUDIT snapshots, PNG de campañas. Eso es vault o `archive/`.

### 4.2 Qué podría ir a YalaWiki (ya es la intención de `CLAUDE.md`)

Si el vault es la SSOT de producto, encaja ahí (y **no** hace falta espejarlo salvo que una sesión headless lo necesite, que es el argumento de `docs/modo-nube/`):

- Tickets Backlog / Ideas / Bugs (ya viven ahí, no los vi).
- `PROJECT`, `ROADMAP`, `STATE`, `DECISIONS`, `WORKFLOW`.
- Narrativa QA: `QA-SCENARIOS`, `DEVICE-QA`, `TESTING-STRATEGY` (la regla durable se queda en `.claude/rules/testing.md`).
- `UI-PATTERNS`, `SWIFT-STYLE`, `L10N` (gotchas durables → rules; catálogo largo → wiki).
- Todo `docs/modo-nube/*` **si** el vault está al día; el README del espejo ya describe el protocolo. Las mediciones `fase3-medicion/` y briefs de fase son bitácora, no contrato.
- `docs/flows/modo-nube/` (atlas): wiki o pages internas; 7.7M de HTML/JS en el repo de la app es opcional.
- AUDIT-* y DESIGN-* una vez archivados.
- Copy de App Store / legales web en revisión.

### 4.3 Qué podría ir a `archive/` (o salir del clone de trabajo)

Sin borrar en esta PR. Candidatos con evidencia en §5.

---

## 5. Candidatos a borrar o archivar (con evidencia)

Nada de esto se tocó. «Candidato» ≠ «bórralo ya».

### 5.1 Evidencia fuerte (huérfanos o contradichos por el código)

| Candidato | Evidencia | Riesgo si se borra |
|-----------|-----------|-------------------|
| `build_output.txt` | Log de build **Neto** 2026-01-13. No es documentación. | Nulo para producto. |
| `Web/test.txt` | Contenido: `It Works`. | Nulo. |
| `Web/build_out.txt` | Log `astro build --verbose`. | Nulo. |
| `Web/README.md` | Starter Astro («Delete this file»). | Nulo si se escribe un README real del sitio. |
| `EXECUTION-RULES.md` | 2026-01-16; comandos GSD inexistentes. Solapado por `CLAUDE.md`. | Bajo: alguien podría tener el hábito de abrirlo. |
| `.agent/workflows/ui-patterns.md` | Neto, 2026-01-13. El DS vivo está en `.claude/rules/swiftui-ds.md` (+ vault UI-PATTERNS). | Bajo. |
| `DESIGN-telemetry-2.0.md` | Propuesta de un stack que `MetricsService.swift` dice haber sustituido. | Bajo (historia de por qué se cambió). |
| `qa/manifest.json` | Self-deprecated 2026-06-01. | Bajo. Confirmar que ningún script lo lee (no lo busqué línea a línea en `runner.sh`; **hipótesis**: solo referencia humana). |
| `YalaWidgets/SETUP.md` | Guía para crear un target que ya está en el xcodeproj; iOS 18 vs 26. | Bajo. |

### 5.2 Evidencia media (marketing / era 2.0 / rebrand)

| Candidato | Evidencia | Riesgo |
|-----------|-----------|--------|
| `Instagram/` (24M, 40 PNG, 2026-03-17) | Último commit = merge 1.1.1→1.2. El pipeline vivo de posts es `screenshots-appstore/` (2026-08-03, 36 PNG en `daily-post/out`). | Medio: el owner puede querer los PNG originales de esas 8 campañas. No están en el xcodeproj. |
| `Yala_Spark_Assets_*-2/` (~3.6M) | Último commit 2026-01-28. **No** aparecen en `project.pbxproj`. Solo en `.vercelignore`. | Medio: assets de marca/Spark; pueden servir para web/tienda fuera de git. |
| `ReferenceAssets/Neto_Logo_*.png` | Nombre Neto; commit de rebrand 2026-01-24. | Bajo para producto; histórico de marca. |
| `Demo/demo_transactions.csv` | 2026-01-28; **cero** refs en `.swift`/`.md`/`.json` de proceso. | Bajo. **Hipótesis**: seed manual de demos. |
| `AUDIT-*.md` (4) | Snapshots junio 2026, branch/era 2.0. Hallazgos parcialmente superados (gateway) o **aún abiertos** (copy App Store EN). | Medio: no borrar el de App Store hasta decidir el copy 2.1. Archivar el resto. |
| `DESIGN-secure-proxy-gateway.md` | Diseño inicial; el living doc debería ser `gateway/README.md` (hoy stale). | Bajo si el README se actualiza primero. |
| `App Store/ARCHIVE-build-25.md` + `ARCHIVE-build-26.md` + `build-25/` | Runbooks de 2.0 builds 25–26. El tip es 2.1 build **12** (numeración reiniciada). | Bajo. |
| `App Store/PNG-*` (32M) | Screenshots de ficha; no hay evidencia de que sean los de 2.1. | Alto si son los que hay en ASC hoy — **desconocido** sin mirar App Store Connect. |
| `docs/modo-nube/MODO-NUBE-ESTRATEGIA-RELEASE.md` | El doc 2.1 lo supersede por completo. | Bajo si se deja un stub «ver DECISION-RELEASE-2.1». |
| `docs/modo-nube/fase3-medicion/` | Mediciones de un HEAD de `2.0.5`. | Bajo (bitácora). |
| `.qa-test-data/` | README Neto; último commit 2026-01-22; cero refs. | Medio: pueden usarse a mano en import QA. **Hipótesis** de desuso. |
| `Yala - Guia Release App Store Connect.docx` | 2026-04-09, era 1.2. | Bajo/medio: única guía ASC en prosa; contenido no auditado (docx). |

### 5.3 Hipótesis — carpetas que *parecen* innecesarias en el clone de trabajo

Marcadas como hipótesis. Verificado lo verificable; el resto es desconocido.

| Hipótesis | Qué verifiqué | Qué no sé |
|-----------|---------------|-----------|
| `Instagram/` es redundante con `screenshots-appstore/` | Fechas (mar vs ago), tamaños, que el generador tiene `captions.md` + `daily-post/`. No comparé PNG pixel a pixel. | Si Frank publica todavía desde esas 8 carpetas. |
| Los 4 `Yala_Spark_Assets_*` no los usa la app | No están en el pbxproj; no hay grep de `Yala_Spark` en Swift/md. | Si un flujo de diseño/Spark los abre por path. |
| `ReferenceAssets/` sobra post-rebrand | Logos Neto; `Screenshots/Espanol` no lo inventarié archivo a archivo (19M). | Si alguna ficha o la web apunta a esas rutas. |
| `.agents/` + `skills/` (symlinks) sobran si `.claude/skills/` es el loader | md5 idénticos; `.gitignore` ya quiere ignorar `.agents/`. | Qué runtime (Cursor vs Claude Code vs `npx skills`) resuelve qué path. **Desconocido.** |
| `docs/flows/modo-nube/` (7.7M) no hace falta en el repo de la app | Es una tool HTML offline de revisión de flujos, anclada a 2.0.5. | Si el owner la abre en sesiones 2.1 como SSOT visual. |
| `Web/Screenshots/` (59M) se puede servir desde CDN / no-git | El sitio se tocó por última vez en junio 2026. | Si el deploy de Vercel depende de esos PNG en el repo (`.vercelignore` **no** los excluye; sí excluye `App Store/` e `Instagram/`). **Hipótesis:** sí se despliegan. No borrar sin comprobar el sitio. |

### 5.4 No son candidatos a borrar (aunque sean grandes o «docs»)

| Ruta | Por qué se queda |
|------|------------------|
| `Yala/`, tests, xcodeproj, widgets, share | Producto. |
| `qa/coverage-index.json` + validators + `YalaUITests/` | Contrato anti-drift; CI lo corre. |
| `.claude/rules/` + `CLAUDE.md` | Sesión desde cero. |
| `gateway/` + manifests + `*.ddl` + fixtures Merkle/HLC | Contrato de nube. |
| `Cloudkit Schemas/` | Aún hay path iCloud; la regla de área los lista. |
| `screenshots-appstore/` | Último toque 2026-08-03; pipeline de marketing **vivo**. |
| `Secrets.xcconfig.template` | Clone usable. |

---

## 6. Hueco de «sesión desde cero» (síntesis)

Lo que un agente **sí** encuentra al clonar `2.1` hoy:

1. Qué es la app y las reglas inviolables → `CLAUDE.md`.
2. Cómo no romper SwiftData / UI / l10n / tests / attest → `.claude/rules/`.
3. Qué hay que cubrir al tocar `Yala/` → `qa/coverage-index.json`.
4. Cómo corre CI → `.github/workflows/qa.yml`.
5. Código y tests.

Lo que **no** encuentra (y `CLAUDE.md` da por sentado):

1. Mapa de arquitectura (CODEBASE-MAP).
2. Patrones UI canónicos (UI-PATTERNS) — solo gotchas en `swiftui-ds.md`.
3. Escenarios QA narrativos (QA-SCENARIOS / DEVICE-QA).
4. Estado de producto / decisiones (STATE, DECISIONS, ROADMAP).
5. Un README humano.
6. What's New y metadata de tienda para **2.1** (el árbol para en 2.0 / marzo 2026).
7. Un README de `gateway/` que describa el worker real, no el scaffold de junio.

`docs/modo-nube/` mitiga eso **solo** para la épica de nube, y se declara stale respecto al vault. Varios de esos md siguen titulados `2.0.5` después de que `2.1` sea el trunk.

---

## 7. Checks corridos en esta sesión

- `python3 qa/validate-coverage.py` → **OK** (warnings de `scenarioIDs` / `lastVerified` vacíos; no fallan el ratchet).
- `bash qa/check-test-isolation.sh` → **OK** (48 archivos).
- `qa/scripts/precommit-gate.sh` no aplica: este cambio no stagea `.swift`.

No se compiló la app (fuera de alcance; cero cambios de producto).

---

## 8. Cómo usar este fichero

Es un mapa para que Frank/Jurgen decidan SSOT y qué tirar. No es un plan de limpieza ni un PR de delete. Si hay un siguiente paso, es **una decisión** (qué vive en git vs wiki vs archive), no más inventario.
