---
description: Controla el simulador iOS para QA visual — XcodeBuildMCP nativo + agent-device fallback
allowed-tools: Bash(agent-device:*), Bash(npx agent-device:*), Bash(./qa/runner.sh:*), Bash(bash qa/runner.sh:*), Bash(cp:*), Bash(date:*), Bash(open:*), Read, Write, Edit, Glob
---

QA visual del simulador iOS. **Prioriza XcodeBuildMCP** (nativo, estable, sin dependencias externas). Cae a `agent-device` solo para interacciones que MCP no cubre.

## CAPACIDADES (CUÁL USAR CUÁNDO)

| Acción | Herramienta preferida | Fallback |
|--------|----------------------|----------|
| Listar simuladores | `mcp__XcodeBuildMCP__list_sims` | `agent-device devices` |
| Bootear simulador | `mcp__XcodeBuildMCP__boot_sim` | — |
| Abrir Simulator.app | `mcp__XcodeBuildMCP__open_sim` | — |
| Build + run app | `mcp__XcodeBuildMCP__build_run_sim` | — |
| Install app .app | `mcp__XcodeBuildMCP__install_app_sim` | — |
| Launch app instalada | `mcp__XcodeBuildMCP__launch_app_sim` | — |
| Stop app | `mcp__XcodeBuildMCP__stop_app_sim` | — |
| Screenshot | `mcp__XcodeBuildMCP__screenshot` | `agent-device screenshot` |
| Jerarquía UI + coordenadas | `mcp__XcodeBuildMCP__snapshot_ui` | `agent-device snapshot -i` |
| Video grabación | `mcp__XcodeBuildMCP__record_sim_video` | — |
| Tap por elemento ref | **`agent-device press @eN`** (MCP no expone taps) | — |
| Long-press | **`agent-device long-press @eN`** | — |
| Fill TextField | **`agent-device fill @eN "texto"`** | — |
| Swipe / scroll | **`agent-device scroll up/down`** | — |
| Buscar por texto | **`agent-device find "Gastos" click`** | — |
| Home / back | **`agent-device home` / `back`** | — |
| Dark/light mode | **`agent-device settings appearance dark`** | — |
| Permisos sistema | **`agent-device settings permission grant ...`** | — |

**Regla:** todo lo de captura/info usa MCP. Todo lo de **interacción** sigue siendo agent-device porque XcodeBuildMCP no expone taps/fills/swipes en el modo simulador-only por defecto.

## PREREQUISITOS

- Simulador iPhone 17 Pro disponible (verificar con `mcp__XcodeBuildMCP__list_sims`)
- App Yala compilada e instalada en el simulador
- `agent-device` instalado globalmente para interacciones (`npm install -g agent-device`)

Antes de la primera build/run/test del flujo:

```
mcp__XcodeBuildMCP__session_show_defaults
```

para confirmar que project/scheme/simulator están configurados. Si faltan, configurar con `session_set_defaults` (scheme Yala / iPhone 17 Pro).

## FLUJO QA ESTÁNDAR

### 1. Preparar simulador

```
mcp__XcodeBuildMCP__list_sims                 # confirmar iPhone 17 Pro disponible
mcp__XcodeBuildMCP__boot_sim                  # si no está booteado
mcp__XcodeBuildMCP__open_sim                  # abrir Simulator.app visualmente
mcp__XcodeBuildMCP__build_run_sim             # build + install + launch en una sola llamada
```

Si la app ya está instalada y solo quieres relanzarla: `launch_app_sim`.

### 2. Snapshot inicial

```
mcp__XcodeBuildMCP__snapshot_ui               # jerarquía + coordenadas tappables
mcp__XcodeBuildMCP__screenshot                # captura visual a archivo
```

`snapshot_ui` es **más confiable** que `agent-device snapshot` porque devuelve coordenadas absolutas además del árbol de accesibilidad.

### 3. Interactuar — agent-device para taps/fills/swipes

```bash
# Identificar refs desde snapshot_ui o desde agent-device snapshot -i
agent-device snapshot -i                     # solo si necesitas refs @eN
agent-device press @e5
agent-device fill @e8 "1500"
agent-device long-press @e3
agent-device scroll down
```

**Regla:** después de cada interacción (press/fill/scroll) los refs `@eN` se invalidan. Re-snapshot antes del siguiente tap.

### 4. Verificar resultado

```
mcp__XcodeBuildMCP__snapshot_ui               # estado nuevo
mcp__XcodeBuildMCP__screenshot                # evidencia visual
```

Comparar con estado anterior (manualmente o vía `agent-device diff snapshot -i` si necesitas diff textual del árbol).

### 5. Cerrar

```
mcp__XcodeBuildMCP__stop_app_sim              # o agent-device close
```

## SIMULACIÓN DE SISTEMA (agent-device)

XcodeBuildMCP no expone settings del simulador. Se sigue usando agent-device:

```bash
agent-device settings appearance dark
agent-device settings appearance light
agent-device settings permission grant notifications
agent-device settings permission grant camera
```

## BATCH QA AUTOMATION (runner.sh)

Tu flujo de QA automatizado existente sigue funcional, basado en agent-device + `qa/runner.sh`:

```bash
bash qa/runner.sh                                       # todas las suites
bash qa/runner.sh --suite 05                            # una suite
bash qa/runner.sh --suite 01 --scenario s1.1            # un escenario
bash qa/runner.sh --from 06                             # desde una suite
bash qa/runner.sh --dry-run                             # preview
agent-device batch --steps-file qa/suites/01-onboarding/s1.1-full-flow-part1.json --json
```

Resultados en `/tmp/qa/{timestamp}/`. Ver `qa/manifest.json` para cobertura.

## DOCUMENTAR EN OBSIDIAN (OBLIGATORIO)

Al terminar el QA, guardar evidencia y actualizar el documento Obsidian.

`VAULT="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/YalaWiki"`

### 1. Copiar screenshots al vault

Las screenshots de `mcp__XcodeBuildMCP__screenshot` quedan en un path temporal — copiar al vault con nombre estable:

```bash
FEATURE_NAME="nombre-feature-o-bug"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
cp /tmp/yala-qa-*.png "$VAULT/Attachments/qa-${FEATURE_NAME}-${TIMESTAMP}.png"
```

### 2. Buscar documento Obsidian correspondiente

- Features: `$VAULT/Backlog/[prefijo_][nombre].md` (glob si no se encuentra exacto)
- Bugs: `$VAULT/Bugs/[prefijo_][nombre].md`

### 3. Actualizar prefijo y status según resultado

**Si QA PASA:**
- Renombrar: `qa_feature.md` → `ok_feature.md`
- Frontmatter: `status: done` (Backlog) o `status: fixed` (Bugs)
- Frontmatter: `qa-status: passed`
- Frontmatter: `qa-date: DD/MM/YY`

**Si QA FALLA:**
- Renombrar: `qa_feature.md` → `feature.md` (sin prefijo)
- Frontmatter: `status: reopened`
- Frontmatter: `qa-status: failed`
- Frontmatter: `qa-date: DD/MM/YY`
- Frontmatter: `qa-notes:` descripción del fallo (sin comillas, sin acentos, sin caracteres especiales)

**Tabla de prefijos:**

Backlog:
| Status | Prefijo |
|--------|---------|
| open / reopened | (ninguno) |
| backlog | `next_` |
| in-progress | `now_` |
| needs-testing | `qa_` |
| done | `ok_` |
| discarded | `out_` |

Bugs:
| Status | Prefijo |
|--------|---------|
| open / reopened | (ninguno) |
| needs-testing | `qa_` |
| fixed | `ok_` |
| discarded | `out_` |

Ejecutar rename:
```bash
mv "$VAULT/Backlog/[old_name].md" "$VAULT/Backlog/[new_prefix_name].md"
```

### 4. Añadir sección `## QA Visual` (o actualizar)

```markdown
## QA Visual
### YYYY-MM-DD
**Resultado:** PASS | FAIL

**Pantalla principal:**
![[qa-feature-name-20260326-143000.png]]
Navegacion: Tab Gastos > Lista de transacciones > verificar [aspecto]

**Pasos reproducidos:**
1. ...
2. ...

**Hallazgos:**
- (si FAIL) descripción del problema con screenshot adjunto
```

## REGLAS

- **MCP-first**: para captura y info, siempre XcodeBuildMCP. Estable, sin dependencias.
- **agent-device solo para interacción**: taps, fills, swipes, settings de sistema.
- Re-snapshot **después de cada interacción** — los refs `@eN` se invalidan.
- Usar `snapshot_ui` (MCP) o `snapshot -i` (agent-device) para reducir output. Limitar profundidad con `-d 3` si el árbol es grande.
- Usar `agent-device find "texto"` cuando no conoces el ref exacto y MCP no devuelve coincidencia clara.
- **NO ejecutar en dispositivo físico** salvo que el usuario lo pida explícitamente.
- Screenshots como evidencia siempre al vault Obsidian.
- Si `mcp__XcodeBuildMCP__session_show_defaults` reporta proyecto/scheme/sim faltante, configurar antes de cualquier build/run/test.
