---
description: Controla el simulador iOS para QA visual — snapshots, taps, verificación de UI
allowed-tools: Bash(agent-device:*), Bash(npx agent-device:*), Bash(./qa/runner.sh:*), Bash(bash qa/runner.sh:*), Read
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

REGLAS:
- SIEMPRE re-snapshot después de cualquier interacción (press, fill, scroll) — los refs se invalidan
- Usar `snapshot -i` (modo iterativo/compacto) para reducir output
- Limitar profundidad con `-d 3` si el árbol es muy grande
- Usar `find "texto"` cuando no conoces el ref exacto
- NO ejecutar en dispositivo físico salvo que el usuario lo pida explícitamente
- Reportar hallazgos con screenshots como evidencia
