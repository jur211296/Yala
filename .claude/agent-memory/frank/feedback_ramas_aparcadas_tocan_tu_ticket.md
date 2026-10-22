---
name: ramas-aparcadas-tocan-tu-ticket
description: Antes de implementar un ticket, busca en TODAS las ramas commits que toquen su fichero — una sesión aparcada sin PR puede haberle escrito requisitos que no están en 2.1
metadata:
  type: feedback
---

**Al arrancar un ticket, `git log --all --oneline -- 'tickets/*/<id>.md'` antes de diseñar.** Lo que
hay en `2.1` no es todo lo que se sabe del ticket.

**Why:** el 2026-09-11, implementando el paso 9 (`session-exits-one-verb-per-session`), di con la rama
`encargo/2026-09-10-groups-entry-on-a-mirrored-store-still-blocks-the-owner` **por casualidad**, al
limpiar DerivedData de worktrees muertos. Estaba subida y sin PR, y su sesión había añadido a MI ticket
una sección entera —«Un segundo consumidor»— con tres conclusiones medidas que eran requisitos del paso
9 (no reusar el boot-wipe para lo que no cierra sesión, los insumos rotos de la espera del export, el arm
sin desarme). Además tocaba 23 de mis ficheros y había movido a `blocked/` un ticket que el encargo me
pedía anotar. Si no la veo, mi PR habría ignorado lo que ya se había medido y su rebase habría chocado
sin aviso.

**How to apply:**
- Al abrir un ticket: `git log --all --oneline -- 'tickets/*/<id>.md'` y, si sale una rama que no está
  en `2.1`, `git diff origin/2.1...<rama> -- 'tickets/*/<id>.md'` para leer lo que dejó.
- Si esa rama dejó texto en tu ticket, **tráelo a tu PR con su respuesta punto por punto** (su rebase lo
  soltará como ya incorporado) y di en el PR qué ficheros chocarán.
- `git worktree list` también sirve de pista: un worktree vivo con nombre de encargo es trabajo sin mergear.

Relacionado: [[ticket-nuevo-busca-el-duplicado-primero]] — la misma familia, en la otra dirección: allí el
ticket ya existía; aquí lo que ya existía era el conocimiento sobre el tuyo.
