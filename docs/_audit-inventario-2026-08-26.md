# Auditoría de inventario — repo Yala (rama 2.1)

**Fecha de medición:** 2026-08-26  
**Árbol medido:** `origin/2.1` tip `f4cf3d2b` («Build 12 para TestFlight de 2.1»), inventario escrito en rama `cursor/audit-inventario-docs-9e87`.  
**Qué es esto:** mapa factual del árbol y de la documentación que *este* repo contiene, más el plan de absorción **después** de la decisión del owner. Cero borrados, cero refactors, cero cambios de producto. **Este documento no absorbe ni mueve nada.**  
**Qué no es:** no vi el vault Obsidian (`jur211296/YalaWiki`). Donde `CLAUDE.md` apunta a `$VAULT/planning/*`, solo puedo afirmar que **esos ficheros no están en este repo**. No invento su contenido ni si están al día.

## Decisión del owner (2026-08-26) — no reabrir

**SSOT único = este repo Yala** (`jur211296/Yala`, rama `2.1`). YalaWiki se archiva. Obsidian deja de ser SSOT (viewer opcional).

Árbol destino **fijado** (no reabrir):

- `docs/` → proceso vivo: `ESTADO.md` (NOW), `HANDOFF.md`, `DECISIONS.md`, `TICKETS.md`. `TICKETS.md` documenta **este** schema inglés (índice + contrato). Proceso corto extra solo si no vive ya en `CLAUDE.md` / `qa/`.
- `tickets/{backlog,in-progress,qa,done,blocked,discarded}/` → una carpeta = un estado. Frontmatter `status` = el nombre de la carpeta (mismas strings). `priority: high | medium | low`. Slugs/filenames: English kebab-case, **los asigna Frank** (no el user ni el CA).
- `marketing/` en la raíz (para Lola). Todo el marketing vive ahí. Mapeo en §4.4. **No reabrir.**
- `CLAUDE.md`, `.claude/rules/`, `qa/` se quedan en raíz (el CA los descubre).
- Skills de producto Yala viven en el repo, **una** carpeta canónica (ver §4.3).

Las §§0–3 son la medición. Las §§4–9 aplican ese árbol. **Nada de eso se ejecutó en este PR.**

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
| `Demo/` | 16K | 2026-01-28 `46170f2b` | `demo_transactions.csv`. Cero refs en código | **desconocido** (fixture huérfano; **no** está en el mapeo `marketing/`) |

Destino (fijado, **no ejecutado**): esas rutas de marketing → `marketing/` (§4.4, fase M). La tabla de arriba es el árbol **medido hoy**.

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

## 4. Árbol destino (fijado — no creado)

SSOT = este repo. Obsidian, si se usa, **solo lee** estos paths. No se escribe al vault.

El vault **no está en este clone**. «Absorber X» usa *nombres* que `CLAUDE.md` / `.claude/commands/` citan. No afirmé que el fichero exista ni su contenido.

```
jur211296/Yala   (rama 2.1)
├── CLAUDE.md                          # se queda (descubrimiento del CA)
├── .claude/rules/                     # se queda
├── qa/                                # se queda (coverage-index + runner + CI)
├── .claude/skills/                    # canónica de skills (ver §4.3)
├── docs/
│   ├── ESTADO.md                      # NOW: qué está en curso
│   ├── HANDOFF.md                     # qué dejarle a la siguiente sesión
│   ├── DECISIONS.md                   # registro de decisiones
│   ├── TICKETS.md                     # índice + formato estándar
│   ├── planning/BRAND-VOICE.md        # YA está; no es ticket
│   ├── modo-nube/                     # YA está; deja de ser «copia»
│   ├── flows/                         # YA está (atlas)
│   └── archive/                       # AUDIT/DESIGN/bitácoras (fase D)
├── tickets/
│   ├── backlog/
│   ├── in-progress/
│   ├── qa/
│   ├── done/
│   ├── blocked/
│   └── discarded/
└── marketing/                         # Lola; no es docs/ ni tickets/
    ├── app-store/                     # hoy App Store/
    ├── instagram/                     # hoy Instagram/
    ├── web/                           # hoy Web/; sitio Vercel
    ├── screenshots-appstore/          # hoy screenshots-appstore/
    ├── spark/                         # hoy los 4 Yala_Spark_Assets_*
    └── reference-assets/              # hoy ReferenceAssets/
```

No se usa `docs/backlog/`, `docs/bugs/`, `docs/ideas/`, `docs/planning/NOW.md`, ni las carpetas en español (`en-progreso`, `bloqueada`, `descartada`). El owner las reemplazó. Marketing **no** vive bajo `docs/`: es `marketing/` en la raíz.

### 4.1 `docs/` — proceso vivo

| Fichero | Rol | Hoy en el clone |
|---------|-----|-----------------|
| `docs/ESTADO.md` | NOW: en curso, HOLD, siguiente paso | **Ausente.** `STATE.md` tampoco está. `/idea` escribe un Parking Lot en `STATE.md` (roto). |
| `docs/HANDOFF.md` | Contexto para la sesión siguiente | **Ausente.** Hay un handoff puntual: `docs/modo-nube/MODO-NUBE-HANDOFF-2026-07-28.md` (épica, no el de repo). |
| `docs/DECISIONS.md` | Decisiones durables | **Ausente.** `CLAUDE.md` lo cita en el vault. |
| `docs/TICKETS.md` | Índice de `tickets/` + contrato de formato | **Ausente.** |

`docs/TICKETS.md` documenta **este** schema (inglés). Contrato propuesto:

```yaml
---
id: english-kebab-slug          # = filename sin .md; lo asigna Frank
title: …
status: backlog | in-progress | qa | done | blocked | discarded
priority: high | medium | low
type: feature | bug | idea
---
```

Reglas:

- `status` **= nombre de la carpeta** (mismas strings).
- Filename = `id` + `.md`, English kebab-case. **No** conservar nombres en español, ni `qa_`, ni espacios, ni underscores de Obsidian.
- Frank asigna el slug. El CA / el user **no** lo inventan en absorción real; la tabla §4.2 es solo el *shape* propuesto para el plan.
- Mover el fichero y editar `status` es el mismo acto.
- `TICKETS.md` es el índice (`id`, `status`, `priority`, path). El cuerpo vive en `tickets/<status>/<id>.md`.

Proceso corto **extra** — solo si no está ya en `CLAUDE.md` / `qa/`:

| Tema | ¿Ya vive? | Acción |
|------|-----------|--------|
| Cómo testear / gate / ratchet | **Sí:** `CLAUDE.md` (`/verify-ios`, `/gate`, `qa/coverage-index.json`); `.claude/rules/testing.md`; `qa/README.md` | **No** crear otro HOWTO. |
| HOLD / kill switches / remote flags | **No** como proceso en `CLAUDE.md` ni `qa/README.md`. Fragmentos en `qa/cloud/README.md` y rules. | Un apartado corto en `ESTADO.md` (o al pie de `DECISIONS.md`) cuando se sepa la lista real. **No** inventar flags aquí. |
| CODEBASE-MAP, UI-PATTERNS, SWIFT-STYLE, DEVICE-QA, QA-SCENARIOS, … | Citados en vault; **no** están en el git | No reabrir un `docs/planning/` de 12 files. Si al absorber hacen falta, aterrizan como ficheros sueltos en `docs/` **solo** si el owner los pide. Hasta entonces: rules + `qa/` + código. |

`docs/planning/BRAND-VOICE.md`, `docs/modo-nube/`, `docs/flows/` **ya existen**. Se quedan. `modo-nube/README.md` deja de decir «NO son la SSOT» (fase B). `fase3-medicion/` y `MODO-NUBE-ESTRATEGIA-RELEASE.md` → `docs/archive/` en fase D.

### 4.2 `tickets/` — una carpeta = un estado

| Carpeta | `status` | Quién aterriza (clase de origen; vault no medido) |
|---------|----------|---------------------------------------------------|
| `tickets/backlog/` | `backlog` | `$VAULT/Backlog/` / Ideas sin empezar |
| `tickets/in-progress/` | `in-progress` | Lo que STATE/NOW marque en curso |
| `tickets/qa/` | `qa` | Lo que hoy es prefijo `qa_*` o `needs-testing` (`/cerrar`) |
| `tickets/done/` | `done` | Cerrados |
| `tickets/blocked/` | `blocked` | Bloqueados |
| `tickets/discarded/` | `discarded` | Descartados |

Bugs y features **comparten** estas seis carpetas (`type:` en el frontmatter). No hay `tickets/bugs/` aparte.

Attachments de `/qa`: no hay `docs/attachments/` en el árbol fijado. Destino al copiar: junto al ticket o `tickets/qa/` (peso del vault **desconocido**).

`.planning/` (gitignored, ausente): no se usa.

#### Slugs propuestos (English kebab-case)

El vault **no está aquí**: no hay filenames reales que conservar. En absorción, **Frank asigna** el `id`. Abajo hay slugs de *ejemplo* para el mapeo — shape inglés, **cero nombres en español**. No son tickets creados.

| Clase de origen (citada en este repo) | No usar | Slug propuesto | Carpeta | `priority` |
|---------------------------------------|---------|----------------|---------|------------|
| Feature Backlog (genérico) | `feature-foo.md`, nombres ES | `feature-<topic>.md` | `backlog` | medium (default hasta que Frank ponga otra) |
| Idea (`/idea`, Parking Lot) | `idea-….md` en español | `idea-<topic>.md` | `backlog` | low |
| Bug (`$VAULT/Bugs/`, `/bug-triage`) | `bug-….md` en español | `bug-<topic>.md` | según estado | high si es bloqueante de release |
| Lote QA (`qa_*`, `/cerrar`) | `qa_inbox-….md`, `qa_*.md` | `qa-<topic>.md` | `qa` | medium |
| Cover del aviso de bandeja (citado en `MODO-NUBE-HANDOFF-2026-07-28.md` / TestFlight 2.0.5) | cualquier slug ES | `bug-inbox-alert-cover-stuck.md` | `done` si el handoff lo da por cerrado; si no, `qa` | high |
| Decisión release 2.1 ON (doc vivo en `docs/modo-nube/`) | `MODO-NUBE-…` como ticket | `cloud-mode-release-2-1.md` | `done` (decisión ya tomada) o no es ticket — vive en `DECISIONS.md` | — |
| Épica grupos backend (docs `groups-backend-v1`) | `grupos-backend-….md` | `groups-backend-v1.md` | `in-progress` o `done` según ESTADO | high |

Regla de absorción (fase C): si el fichero del vault se llama en español o `qa_…`, **rename** al slug inglés de Frank (o, en el PR de absorción, al slug de esta tabla si Frank no lo cambió). Nunca `git mv` conservando el nombre ES.

### 4.3 Skills — inventario y carpeta canónica

Medido 2026-08-26:

| Árbol | Qué hay | Naturaleza |
|-------|---------|------------|
| `.claude/skills/bugfix/` | **Único skill de producto Yala** (ciclo de bug). Apunta a `$VAULT/Bugs/`. | Directorio real, trackeado. |
| `.claude/skills/{ui-ux-pro-max,mermaid-visualizer,excalidraw-diagram-obsidian,obsidian-canvas-creator}/` | Vendor / diagramas | Directorios reales. |
| `.claude/skills/excalidraw-diagram/` | Vacío (0 files) | Basura. |
| `.claude/skills/{swift-concurrency,swiftdata,swift-testing,swiftui,swiftui-expert}-pro/` | Vendor Swift | **Symlinks** → `../../.agents/skills/…` |
| `skills/` (raíz) | 4 de esos 5 Swift (falta `swiftui-expert-skill`) | **Symlinks** → `../.agents/skills/…` |
| `.agents/skills/` | Los 5 Swift vendor (64+ files) | Copia real. `.gitignore` línea 49 ignora `.agents/`; git **sigue trackeándolos**. |
| `skills-lock.json` | Lock de `swiftui-expert-skill` (GitHub) | Raíz. |
| `.claude/commands/` | `/gate` `/spec` `/idea`… | **No** son skills; se quedan. |
| `.agent/workflows/ui-patterns.md` | Neto, 2026-01-13 | No es skill. |

Hashes de `SKILL.md` de los 4 Swift solapados: **idénticos** en los tres árboles (es la misma carga vía symlink).

Este CA / Claude Code **descubren** `.claude/skills/` (lista de `agent_skills` de la sesión). `skills/` de raíz es un alias incompleto.

**Canónica propuesta: `.claude/skills/`**

1. El runtime que ya usa el CA apunta ahí.
2. El único skill de producto (`bugfix`) ya vive ahí y **debe quedarse en el git**.
3. Una carpeta, no tres.

Plan de no-duplicar (fase A, no este PR):

1. Materializar los 5 Swift **dentro** de `.claude/skills/` (copiar, romper los symlinks a `.agents/`).
2. Quitar `skills/` de raíz **o** dejar **un** symlink `skills` → `.claude/skills` si alguna herramienta solo mira la raíz. No cuatro symlinks sueltos.
3. Dejar de trackear `.agents/` (el ignore ya lo pide).
4. Borrar `.claude/skills/excalidraw-diagram/` vacío.
5. `bugfix` se queda; en fase C se le cambia `$VAULT/Bugs/` → `tickets/`.

No mover skills vendor a `docs/`. No crear `skills/` paralelo con las mismas copias.

### 4.4 `marketing/` — para Lola (fijado 2026-08-26)

Una carpeta en la **raíz** de Yala. No es `docs/`, no es `tickets/`, no es `docs/archive/`. El owner lo fijó; no reabrir.

| Hoy (medido) | Destino |
|--------------|---------|
| `App Store/` | `marketing/app-store/` |
| `Instagram/` | `marketing/instagram/` |
| `Web/` | `marketing/web/` |
| `screenshots-appstore/` | `marketing/screenshots-appstore/` |
| `Yala_Spark_Assets_{DARK,LIGHT,NEON,ORIGINAL}-2/` | `marketing/spark/` (los 4 packs **dentro**, sin aplanar nombres) |
| `ReferenceAssets/` | `marketing/reference-assets/` |

`Demo/` y `.qa-test-data/` **no** están en este mapeo. Siguen en §5.4.

**Vercel (medido, no inferido a ciegas).** Proyecto `yala-app` (`prj_4L3v3cHPzJx8wXr7VQ9MixyZoJ3i`) ligado a `jur211296/Yala`, framework `astro`. Deploy de `2.1` @ `f4cf3d2` (`dpl_7htTQZb8…`):

- «Found `.vercelignore`» en la **raíz del clone**; «Removed 131 ignored files» (incluye `/ReferenceAssets/…`).
- `npm run build` → `web@0.0.1` → `astro build` → `directory: /vercel/path0/Web/dist/`.

Consecuencia: el sitio se construye desde `Web/`. Mover `Web/` sin cambiar el Root Directory del dashboard (`Web` → `marketing/web`) deja el próximo deploy sin `package.json`. El `.vercelignore` de raíz **sigue aplicándose** aunque el build corra dentro de `Web/`.

**Pie que rompe el deploy:** una línea `marketing/` en `.vercelignore`. Tras el `git mv`, eso ignora también `marketing/web/` y Vercel sube el sitio vacío. Reescribir ignores **por hijo**, nunca el padre:

```
marketing/app-store/
marketing/instagram/
marketing/spark/
marketing/reference-assets/
marketing/screenshots-appstore/
```

`marketing/web/` **no** se ignora. `screenshots-appstore/` hoy **no** está en el ignore de raíz (52M se suben); al moverlo, sí hay que listarlo.

`Web/.vercelignore` (viaja a `marketing/web/.vercelignore`) tiene paths con forma de raíz (`Web/Screenshots/`, `ReferenceAssets/`). En el mismo PR que el mv: `Screenshots/` (el comentario de case-insensitive ya está) y quitar `ReferenceAssets/` (ya no es hermano).

Otros pointers del **mismo** PR de mv (cero código de producto): `.claude/launch.json` (`Web`, `screenshots-appstore/generator`); `qa/coverage-index.json` área `welcome-universal-link-icloud` (`Web/src/pages/invite.astro`, `Web/src/i18n/translations.ts`).

**Dónde va en el plan — recomendación:** fase **M**, propia. Después de A (el esqueleto `docs/` + `tickets/` ya existe para anotar el move). **No** dentro de D (D es `docs/archive/`, otro destino). **No** dentro de E (E borra basura; esto es reubicar para Lola). B/C no la bloquean (M no necesita el vault). D **después** de M para que las refs a `Web/` se reescriban al path nuevo.

Si se parte para no tocar Vercel en el primer commit: **M1** = packs ya ignorados (`App Store/`, `Instagram/`, Spark, `ReferenceAssets/`) + reescribir esas líneas del `.vercelignore`. **M2** = `Web/` + `screenshots-appstore/` + Root Directory del dashboard + ignore de `screenshots-appstore` + `launch.json` + coverage-index. M2 es el commit que puede tumbar yala-app.pe.

Este PR **no ejecuta** esos `git mv`.

---

## 5. Raíz: se queda / archive / borrar / marketing (PR posterior)

Nada ejecutado. Marketing **sí** entra en el plan (fase M, §4.4); no es «otro ticket».

### 5.1 Se quedan

| Ruta | Por qué |
|------|---------|
| `CLAUDE.md` | Descubrimiento del CA. Fase A: pointers `$VAULT` → `docs/` + `tickets/`. |
| `.claude/rules/` | Cómo no romper. |
| `qa/` + `qa/README.md` | SSOT ejecutable + CI. |
| `.claude/commands/` | Runtime. Fase C: paths a `tickets/` y `docs/ESTADO.md`. |
| `.claude/skills/` | Canónica (§4.3). |
| `docs/modo-nube/`, `docs/flows/`, `docs/planning/BRAND-VOICE.md` | Ya en `docs/`; no son tickets. |
| Manifests, `*.ddl`, fixtures, `Secrets.xcconfig.template`, `gateway/` | Contratos / código. |
| `README.md` (raíz) | **No existe.** Se crea en fase A (schemes, iOS 26, «empieza por `CLAUDE.md`»). |

### 5.2 A `docs/archive/` (PR posterior)

| Ruta actual | Destino | Evidencia |
|-------------|---------|-----------|
| `AUDIT-*.md` (4) | `docs/archive/AUDIT-*.md` | Snapshots 2.0. El de App Store sigue citando un hallazgo vivo en metadata EN. |
| `DESIGN-secure-proxy-gateway.md` | `docs/archive/` | Worker ya existe. |
| `DESIGN-telemetry-2.0.md` | `docs/archive/` | Superseded por `MetricsService`. |
| `EXECUTION-RULES.md` | `docs/archive/` | GSD 2026-01-16. |
| `Yala - Guia Release App Store Connect.docx` | `docs/archive/Yala-Guia-Release-ASC.docx` | Era 1.2. |
| `docs/modo-nube/MODO-NUBE-ESTRATEGIA-RELEASE.md` | `docs/archive/modo-nube/` | Superseded por DECISION-RELEASE-2.1. |
| `docs/modo-nube/fase3-medicion/` | `docs/archive/modo-nube/fase3-medicion/` | Bitácora `2.0.5`. |
| `YalaWidgets/SETUP.md` | `docs/archive/YalaWidgets-SETUP.md` | Target ya existe. |
| `.agent/workflows/ui-patterns.md` | `docs/archive/neto-ui-patterns.md` | Neto. |

### 5.3 Borrar en PR posterior — evidencia fuerte

| Ruta | Evidencia |
|------|-----------|
| `build_output.txt` | Log scheme `Neto` 2026-01-13. |
| `Web/test.txt` | `It Works`. Tras M: `marketing/web/test.txt`. |
| `Web/build_out.txt` | Log `astro build`. Tras M: `marketing/web/build_out.txt`. |
| `.claude/skills/excalidraw-diagram/` | Directorio vacío. |

`App Store/ARCHIVE-build-25.md` + `26` **viajan con** `App Store/` → `marketing/app-store/` (fase M). No se pelan a `docs/archive/`.

### 5.4 Fuera de este plan (dueño confirma después)

Ya **no** están aquí Instagram / Spark / ReferenceAssets / App Store PNG / Web: van a `marketing/` (fase M).

Siguen pendientes de confirmación: `Demo/`, `.qa-test-data/`, reescribir el README del sitio (tras M: `marketing/web/README.md`), `qa/manifest.json` (confirmar que `runner.sh` no lo lee). Dedup de `.agents/` + `skills/` = fase A.

### 5.5 No se tocan

Producto (`Yala/`, tests, xcodeproj, widgets, share), `Cloudkit Schemas/`, `gateway/src`, CI. El generador Next de screenshots se **mueve entero** a `marketing/screenshots-appstore/`; no se edita su código en esta absorción.

---

## 6. Plan de absorción por fases (no ejecutado)

Orden: **paths y esqueleto** → **proceso en `docs/`** → **tickets por estado** → **`marketing/`** → **archive** → **basura**. Skills canónicos no necesitan vault: van con A. Marketing tampoco: va en M (después de A; no espera B/C).

### Fase A — Esqueleto, pointers, skills (primero)

Cualquier clone. Sin copiar el vault.

1. Crear `docs/ESTADO.md`, `docs/HANDOFF.md`, `docs/DECISIONS.md`, `docs/TICKETS.md` (el stub de `TICKETS.md` documenta el schema inglés) y `tickets/{backlog,in-progress,qa,done,blocked,discarded}/` (cada una con un `.gitkeep` o README de una línea).
2. `README.md` de raíz: schemes, iOS 26, «empieza por `CLAUDE.md` + `docs/ESTADO.md`».
3. Reescribir `CLAUDE.md`: quitar `$VAULT = ~/Library/…`; tabla → `docs/ESTADO.md`, `docs/DECISIONS.md`, `docs/TICKETS.md`, `tickets/`; «dos superficies» = **rules + `docs/` + `tickets/`**.
4. `.gitignore`: quitar el comentario «Planning docs live in Obsidian vault» / `.planning/` si ya no aplica.
5. Skills (§4.3): materializar Swift en `.claude/skills/`; un solo árbol; dejar de trackear `.agents/`; quitar o colapsar `skills/` de raíz.

**Por qué primero:** `/spec` y `/idea` dejan de tener path oficial al vault. Si se copian tickets antes, la siguiente sesión sigue escribiendo en iCloud.

### Fase B — Proceso (`docs/`) (segundo)

Máquina con vault o export del owner. Este CA no tiene el vault.

1. Vault `DECISIONS.md` → `docs/DECISIONS.md`.
2. Vault `STATE.md` / NOW → `docs/ESTADO.md` (rename anotado si solo existe STATE).
3. Handoff vivo (si hay uno de producto, no el de julio de modo-nube) → `docs/HANDOFF.md`.
4. Rellenar `docs/TICKETS.md` con el contrato de formato + índice vacío o el listado que venga del vault.
5. `docs/modo-nube/README.md`: ya no es espejo.

No volcar CODEBASE-MAP / UI-PATTERNS / … a `docs/planning/` salvo pedido explícito. Gotchas siguen en `.claude/rules/`. Cómo testear sigue en `CLAUDE.md` + `qa/`.

### Fase C — Tickets (tercero)

1. Cada item de `$VAULT/Backlog/`, `Bugs/`, `Ideas/` → `tickets/<status>/` con `status` ∈ {backlog, in-progress, qa, done, blocked, discarded} (default `backlog`). Frontmatter `status` = carpeta. `priority: high|medium|low`.
2. Lo que hoy es `qa_*` / `needs-testing` → `tickets/qa/<english-slug>.md` (no conservar `qa_`).
3. Filename = slug inglés kebab-case (**Frank asigna**; si no hay asignación, usar el shape de §4.2 — nunca el nombre ES del vault).
4. Actualizar `docs/TICKETS.md` (índice + schema).
5. Paths:

| Fichero | Hoy (medido) | Nuevo |
|---------|--------------|-------|
| `.claude/commands/spec.md` | `YalaWiki/Backlog/` | `tickets/` (buscar en las 6 carpetas o leer `TICKETS.md`) |
| `.claude/commands/backlog.md` | idem + `STATE.md` | `tickets/backlog/` + `docs/ESTADO.md` |
| `.claude/commands/idea.md` | `STATE.md` | `tickets/backlog/` o `tickets/` + línea en `ESTADO.md` |
| `.claude/commands/bug-triage.md` | `$VAULT/Bugs/` | `tickets/` filtrando `type: bug` |
| `.claude/commands/qa.md` | `$VAULT/Bugs/qa_*`, `Backlog/qa_*` | `tickets/qa/*.md` (slugs EN, no `qa_`) |
| `.claude/commands/commit-one.md` / `cerrar.md` | ticket Obsidian | ticket en `tickets/` |
| `.claude/skills/bugfix/SKILL.md` | `$VAULT/Bugs/` | `tickets/` |

Si el vault aún no se copió: **parar**. No inventar tickets.

### Fase M — `marketing/` (después de A; no D, no E)

`git mv` del mapeo §4.4. Cero código de producto. **No se ejecuta en este PR.**

1. Crear `marketing/` y mover según la tabla. Spark: los 4 packs **dentro** de `marketing/spark/`, sin renombrar cada pack.
2. Reescribir `.vercelignore` de raíz: quitar las rutas viejas (`App Store/`, `Instagram/`, `ReferenceAssets/`, los 4 Spark); **añadir los hijos** de §4.4, **nunca** una línea `marketing/`.
3. Ajustar `marketing/web/.vercelignore` (ex-`Web/.vercelignore`).
4. En el **mismo** commit que mueve `Web/`: Root Directory del proyecto Vercel `yala-app` de `Web` → `marketing/web`. Si se parte: M1 (ya ignorados) / M2 (`Web/` + dashboard) — ver §4.4.
5. `.claude/launch.json` y `qa/coverage-index.json` (`welcome-universal-link-icloud`).
6. Una línea en `docs/DECISIONS.md` / `ESTADO.md` (A ya los creó).

**Por qué no D:** D archiva AUDIT/DESIGN a `docs/archive/`. Destino distinto, riesgo distinto (deploy). Mezclar ~190M de PNG con bits de auditoría es cómo se rompe yala-app.pe.
**Por qué no E:** E borra basura. Esto es la casa de Lola.
**Por qué después de A:** A es barato y no toca Vercel. M es el PR sensible al deploy.

### Fase D — Archive (después de M)

`git mv` de §5.2 a `docs/archive/`. Actualizar refs (`marketing/web/CAMBIOS-LEGALES-2.0-DRAFT.md` cita `AUDIT-appstore-guidelines.md` en raíz; hoy el path es `Web/…` si M aún no corrió).

Los runbooks `ARCHIVE-build-25/26` **no** vienen aquí: ya están en `marketing/app-store/`.

### Fase E — Limpieza (último)

1. Borrar §5.3 (paths post-M: `marketing/web/test.txt`, `marketing/web/build_out.txt`).
2. Reescribir `gateway/README.md` (quitar «scaffold»).
3. Archivar el repo YalaWiki (fuera de este git).
4. Obsidian viewer → `docs/` + `tickets/` de este clone.

### Qué no hacer

- No borrar `qa/coverage-index.json`.
- No mover `.claude/rules/` a `docs/`.
- No reabrir `docs/backlog|bugs|ideas`, `docs/planning/NOW`, ni carpetas ES (`en-progreso`, `bloqueada`, `descartada`).
- No conservar filenames en español al absorber tickets.
- No duplicar skills.
- No absorber ni `git mv` de marketing en este PR.
- No poner `marketing/` (el padre) en `.vercelignore`.
- No `--no-verify` / force.

---

## 7. Hueco de sesión desde cero (hasta que A–C cierren)

Hoy el clone tiene: `CLAUDE.md` + `.claude/rules/` + `qa/coverage-index.json` + código + `docs/modo-nube/` (espejo) + `BRAND-VOICE.md` (2026-01-26).

Falta: `docs/ESTADO.md`, `HANDOFF.md`, `DECISIONS.md`, `TICKETS.md`, el árbol `tickets/`, el árbol `marketing/`, y el skill `bugfix` sigue apuntando al vault. What's New 2.1 y el README del gateway son otro trabajo.

---

## 8. Checks de esta revisión

- Solo se editó `docs/_audit-inventario-2026-08-26.md`.
- No se crearon `docs/ESTADO.md`, `tickets/` ni `marketing/`. No se ejecutó ningún `git mv`.
- `qa/scripts/precommit-gate.sh` no aplica (no hay `.swift` en staging).

Validación original (sigue vigente): `validate-coverage.py` OK; `check-test-isolation.sh` OK.

---

## 9. Cómo usar este fichero

El árbol destino **está fijado**. Este archivo es el mapa + el plan. Siguiente PR: **fase A** (esqueleto `docs/` + `tickets/` + pointers + skills canónicos). Después: B/C (vault) y **M** (`marketing/`, PR sensible a Vercel). No un delete masivo ni los `git mv` de marketing en este PR.
