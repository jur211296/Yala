---
description: Automatiza navegador web — scraping, formularios, verificación de sitios
allowed-tools: Bash(agent-browser:*), Bash(npx agent-browser:*), Read
---

Automatiza un navegador web via agent-browser para tareas como verificar App Store Connect, scraping, o testing de endpoints web.

PREREQUISITOS:
- agent-browser instalado globalmente (`npm install -g agent-browser`)
- Chrome for Testing instalado (`agent-browser install`)

COMANDOS PRINCIPALES:

```bash
# Abrir URL
agent-browser open https://example.com

# Snapshot del DOM (árbol accesibilidad con refs @eN)
agent-browser snapshot -i

# Interactuar con elementos
agent-browser click @e5
agent-browser fill @e3 "texto"
agent-browser type "texto libre"
agent-browser select @e7 "opción"

# Navegación
agent-browser back
agent-browser forward

# Captura visual
agent-browser screenshot /tmp/page.png
agent-browser screenshot --full-page /tmp/full.png

# Esperar condiciones
agent-browser wait @e5
agent-browser wait --url "**/dashboard"
agent-browser wait --network-idle

# Evaluar JavaScript
agent-browser eval "document.title"

# Gestión de tabs
agent-browser tabs
agent-browser tab 2

# Cerrar
agent-browser close
```

FLUJO ESTÁNDAR:

1. ABRIR PÁGINA:
```bash
agent-browser open https://example.com
```

2. SNAPSHOT — ver estructura de la página:
```bash
agent-browser snapshot -i
```

3. INTERACTUAR — usar refs `@eN` del snapshot:
```bash
agent-browser click @e5
agent-browser fill @e3 "búsqueda"
```

4. RE-SNAPSHOT — refs se invalidan tras navegación:
```bash
agent-browser snapshot -i
```

5. SCREENSHOT — evidencia visual:
```bash
agent-browser screenshot /tmp/resultado.png
```

6. CERRAR:
```bash
agent-browser close
```

AUTENTICACIÓN:
```bash
# Conectar al Chrome del usuario (usa sesiones activas)
agent-browser open https://appstoreconnect.apple.com --connect

# Perfil persistente (guarda cookies entre sesiones)
agent-browser open https://example.com --profile mi-perfil
```

REGLAS:
- SIEMPRE re-snapshot después de clicks o navegación — los refs se invalidan
- Usar `snapshot -i` para output compacto
- Usar `--connect` para sitios que requieren auth del usuario
- Usar `wait` antes de interactuar si la página carga contenido dinámico
- NO navegar a URLs sensibles sin confirmación del usuario
- Reportar hallazgos con screenshots como evidencia
