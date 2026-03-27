---
description: Controla el simulador iOS para QA visual — snapshots, taps, verificación de UI
allowed-tools: Bash(agent-device:*), Bash(npx agent-device:*), Bash(./qa/runner.sh:*), Bash(bash qa/runner.sh:*), Bash(cp:*), Bash(date:*), Read, Write, Edit, Glob
---

Controla el simulador iOS via agent-device para inspeccionar y verificar la UI de Yala.

PREREQUISITOS:
- agent-device instalado globalmente (`npm install -g agent-device`)
- Simulador iPhone 17 Pro disponible
- App Yala compilada e instalada en el simulador

COMANDOS PRINCIPALES:

```bash
# Listar dispositivos disponibles
agent-device devices

# Abrir la app
agent-device open Yala --platform ios

# Capturar árbol de accesibilidad (vista actual)
agent-device snapshot -i

# Interactuar con elementos (usar refs del snapshot)
agent-device press @e5
agent-device fill @e8 "1500"
agent-device long-press @e3

# Navegación
agent-device back
agent-device home
agent-device scroll down
agent-device scroll up

# Captura visual
agent-device screenshot /tmp/yala-screenshot.png

# Comparar estados UI
agent-device diff snapshot -i

# Buscar elemento por texto
agent-device find "Gastos" click

# Cerrar app
agent-device close
```

FLUJO QA ESTÁNDAR:

1. ABRIR APP:
```bash
agent-device open Yala --platform ios
```

2. SNAPSHOT INICIAL — ver qué hay en pantalla:
```bash
agent-device snapshot -i
```

3. INTERACTUAR — usar refs `@eN` del snapshot:
```bash
agent-device press @e5
```

4. RE-SNAPSHOT — los refs se invalidan tras cada interacción:
```bash
agent-device snapshot -i
```

5. VERIFICAR — comparar con estado anterior:
```bash
agent-device diff snapshot -i
```

6. SCREENSHOT — capturar evidencia:
```bash
agent-device screenshot /tmp/yala-qa.png
```

7. CERRAR:
```bash
agent-device close
```

SIMULACIÓN DE SISTEMA:
```bash
# Dark mode
agent-device settings appearance dark
agent-device settings appearance light

# Permisos
agent-device settings permission grant notifications
agent-device settings permission grant camera
```

BATCH QA AUTOMATION:

```bash
# Ejecutar todas las suites QA
bash qa/runner.sh

# Solo una suite
bash qa/runner.sh --suite 05

# Solo un escenario
bash qa/runner.sh --suite 01 --scenario s1.1

# Desde una suite en adelante
bash qa/runner.sh --from 06

# Preview sin ejecutar
bash qa/runner.sh --dry-run

# Ejecutar un batch individual
agent-device batch --steps-file qa/suites/01-onboarding/s1.1-full-flow-part1.json --json
```

Resultados en `/tmp/qa/{timestamp}/` con screenshots y reportes JSON.
Ver `qa/manifest.json` para cobertura y clasificación.

DOCUMENTAR EN OBSIDIAN (OBLIGATORIO):

Al finalizar el QA, guardar evidencia y actualizar estado del documento Obsidian correspondiente.

VAULT="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/YalaWiki"

1. COPIAR SCREENSHOTS al vault:
```bash
FEATURE_NAME="nombre-feature-o-bug"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
cp /tmp/yala-qa-*.png "$VAULT/Attachments/qa-${FEATURE_NAME}-${TIMESTAMP}.png"
```

2. BUSCAR DOCUMENTO correspondiente:
   - Features: `$VAULT/Backlog/[prefijo_][nombre].md` (buscar con glob si no se encuentra)
   - Bugs: `$VAULT/Bugs/[prefijo_][nombre].md`

3. ACTUALIZAR PREFIJO Y STATUS según resultado del QA:

   **Si QA PASA (todo correcto):**
   - Renombrar archivo: `qa_feature.md` → `ok_feature.md`
   - Frontmatter: `status: done` (Backlog) o `status: fixed` (Bugs)
   - Frontmatter: `qa-status: passed`
   - Frontmatter: `qa-date: DD/MM/YY`

   **Si QA FALLA (hay problemas):**
   - Renombrar archivo: `qa_feature.md` → `feature.md` (quitar prefijo)
   - Frontmatter: `status: reopened`
   - Frontmatter: `qa-status: failed`
   - Frontmatter: `qa-date: DD/MM/YY`
   - Frontmatter: `qa-notes:` descripcion del fallo sin comillas ni acentos

   **Tabla completa de prefijos:**

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

4. AÑADIR SECCIÓN `## QA Visual` (o actualizar si ya existe) con:
   - Fecha del QA
   - Screenshots embebidos con formato Obsidian: `![[qa-feature-name-timestamp.png]]`
   - Descripción de qué muestra cada screenshot
   - Resultado: PASS / FAIL + detalle si falla
   - Pasos reproducidos para llegar a cada pantalla

   Formato ejemplo:
   ```markdown
   ## QA Visual
   ### YYYY-MM-DD
   **Resultado:** PASS

   **Pantalla principal:**
   ![[qa-feature-name-20260326-143000.png]]
   Navegacion: Tab Gastos > Lista de transacciones > verificar [aspecto]
   ```

5. Si hay FALLOS, documentar con screenshots del problema y descripción clara del bug.

REGLAS:
- SIEMPRE re-snapshot después de cualquier interacción (press, fill, scroll) — los refs se invalidan
- Usar `snapshot -i` (modo iterativo/compacto) para reducir output
- Limitar profundidad con `-d 3` si el árbol es muy grande
- Usar `find "texto"` cuando no conoces el ref exacto
- NO ejecutar en dispositivo físico salvo que el usuario lo pida explícitamente
- Reportar hallazgos con screenshots como evidencia
- SIEMPRE copiar screenshots a $VAULT/Attachments/ y documentar en el documento Obsidian correspondiente
