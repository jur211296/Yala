---
id: 2026-11-16-web-grupos-nota-lista-dice-usa-tu-iphone
status: backlog
priority: low
area: web
created: 2026-11-16
updated: 2026-11-16
source: hallazgo del lote 5 de «Yala web como la app»
---
# Yala web: la nota de la lista de Grupos dice que para escribir uses el iPhone

Al pie de la lista de Grupos, `grp.nota` dice «Por ahora, para añadir un gasto, saldar o invitar, usa tu iPhone», pero
la web ya escribe en Grupos (staging y producción, `WEB_GROUPS_WRITER = "on"`). El detalle ya usa `grp.notaEscribe`.
Decidir el texto de la lista (¿el mismo `notaEscribe`?) y cambiarlo en los 14 idiomas.
