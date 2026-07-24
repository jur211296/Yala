---
description: Triage de bugs — investiga los bugs abiertos, arregla los evidentes y deja preguntas concretas en los ambiguos. Corre manual o programado.
allowed-tools: Bash(git:*), Bash(xcodebuild:*), Bash(curl:*), Bash(bash qa/validate-coverage.sh:*), Read, Write, Edit, Glob, Grep
---

Agente de triage de bugs de Yala. **Esta es la única definición**: la tarea programada `~/.claude/scheduled-tasks/bug-triage/` apunta aquí. No la dupliques.

## Guardia de arranque — antes de tocar nada

```bash
git status --porcelain
```

**Si el árbol de trabajo ya tiene cambios sin commitear, NO commitees nada en toda la corrida.** Investiga, documenta y deja los fixes sin commitear con una nota clara. Motivo: esto puede correr desatendido mientras hay trabajo a medias del usuario, y un `git add` arrastraría su WIP dentro de un commit ajeno. Es irrecuperable sin que él se entere.

Rutas:
- Bugs: `$VAULT/Bugs/*.md` donde `VAULT="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/YalaWiki"`
- Reglas del proyecto: `CLAUDE.md` y `.claude/rules/` — léelas antes de cambiar código

## 1 · Recopilar

Bugs con `status: open` (triage completo) o `status: answered` (el usuario respondió preguntas; re-procesar con sus respuestas). Ignora cualquier otro estado y el README.

Si no hay ninguno, avisa por webhook y termina:
```bash
curl -X POST https://jur211296.app.n8n.cloud/webhook/8b4b5d11-e702-431b-b309-26ba0e89bbed \
  -H "Content-Type: application/json" -d '{"message":"Sin bugs pendientes hoy."}'
```

## 2 · Investigar y clasificar

Para cada bug: leer el archivo, buscar el código implicado, determinar causa raíz. Luego:

| Clase | Criterio |
|---|---|
| `simple-fix` | Causa raíz clara, solución evidente, cero decisiones de diseño |
| `needs-input` | Ambigüedad real, varias opciones válidas, decisión de UX, o no reproducible sin más contexto |
| `batch` | Varios bugs comparten causa raíz |

Ante la duda, `needs-input`. Un fix equivocado aplicado de madrugada cuesta más que una pregunta.

## 3 · Actuar

**`simple-fix` y `batch`** — implementar siguiendo `CLAUDE.md` y las reglas de área, y verificar con el gate:

```
/gate
```

- Gate verde **y** árbol limpio al arrancar → commit atómico `fix: <descripción>`. **No pushees**: el hook `Stop` ya lo hace.
- Gate verde pero árbol sucio al arrancar → deja el cambio sin commitear y dilo en el informe.
- Gate rojo → **no commitees**. Documenta el fallo en el bug y reclasifica a `needs-input`.

**`needs-input`** — en el `.md` del bug: sección `## Analisis` (qué investigaste, qué encontraste, dónde está en el código con archivo:línea) y `## Preguntas` numeradas y concretas, con opciones cuando las haya. Añade la nota `> Responde debajo de cada pregunta y cambia el status a "answered".` y pon `status: waiting-input`.

**En todos los casos** actualiza el `.md`: qué se encontró, qué se cambió y por qué, en lenguaje de usuario — «se corrigió el cálculo del saldo», no «se refactorizó el FetchDescriptor». Si se commiteó, incluye el hash.

## 4 · Notificar

Resumen corto por webhook (siempre):
```bash
curl -X POST https://jur211296.app.n8n.cloud/webhook/8b4b5d11-e702-431b-b309-26ba0e89bbed \
  -H "Content-Type: application/json" \
  -d '{"message":"Triage: N resueltos, N esperando input, N en batch."}'
```

Detalle por Slack **solo si el conector está disponible y autorizado en esta sesión**: localiza la herramienta con ToolSearch (`slack send message`) en vez de asumir un nombre — el identificador del servidor cambia entre sesiones. Canal `#yala` (`C0AP031507K`). Si no está autorizado, no es un fallo: mete el detalle en el mensaje del webhook y sigue.

## Reglas

- Un commit por bug (o uno por batch). Nunca mezclar bugs sin relación.
- No crear archivos nuevos salvo que el fix lo exija.
- No silenciar errores: si algo falla, se documenta y se notifica.
- Documentar SIEMPRE, aunque el bug quede sin tocar: el usuario tiene que entender qué pasó sin leer el código.
