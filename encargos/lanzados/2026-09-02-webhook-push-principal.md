# Action: avisar a Grok cuando hay push a 2.1

## Contexto
Jürgen quiere cubrir el push directo a principal (sin PR). El listener GitHub de Grok ya cubre merge y CI en `2.1`. El hueco es el push a principal.

Verificado en el repo: `origin/HEAD` es `2.1`. No hay rama `main`. No disparar en ramas de encargo.

Routine de Grok ya armada (webhook «Yala push a principal»). URL y sender key las copia Jürgen del panel de la routine a GitHub Secrets del repo. El bot no las ve. El yaml solo referencia secrets; nada de URL ni clave en el repo.

Hay un worktree `encargo/2026-09-02-sesion-diseno-panel` con trabajo sin commitear. No mezclar. Worktree nuevo, rama + PR.

Workflow existente: solo `.github/workflows/qa.yml`.

## Qué se pide
1. Un workflow `on: push` **solo** a `2.1`.
2. POST al webhook de Grok. URL y clave salen de GitHub Secrets (nombres claros, documentados para Jürgen). Averigua el header que espera el sender key de Grok Bot; no inventes el valor.
3. No dispares en otras ramas.

## Qué NO hay que tocar
- `marketing/` (Lola).
- Código de producto.
- Instalar GitHub MCP.
- Rama `main` (no existe).
- El worktree de diseño de panel.

## Como se sabe que está bien
Action en el repo por PR/worktree. Solo `2.1`. Secrets fuera del yaml. Un push de prueba a `2.1` no es obligatorio en esta sesión salvo que Jürgen lo pida.
