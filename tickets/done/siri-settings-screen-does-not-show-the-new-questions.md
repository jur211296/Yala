---
id: siri-settings-screen-does-not-show-the-new-questions
status: done
priority: low
area: siri
created: 2026-10-21
updated: 2026-10-28
source: auditoría UX 2.2 · lote 15 · L15-4 (implementado tal cual la variante 1, captura L15-4-A.png)
---

# «Siri y Atajos» no enseña las dos preguntas nuevas («Cuánto gasté», «Mi saldo»)

L15-4 se implementó tal como la variante 1 elegida (captura `L15-4-A.png`): las cuatro acciones de entonces con el nombre
de Atajos y el botón «Abrir mis atajos de Yala». Esa captura es anterior a #552, que añadió dos acciones a Atajos
(«Cuánto gasté», «Mi saldo», con frase de Siri en los 16 idiomas desde L15-5). La pantalla no las enseña; el botón del
pie lleva a la página de Yala en Atajos, donde sí están.

## Qué hay que decidir

- **A · Añadirlas** como dos filas más de «Otros atajos», con el mismo molde (nombre de Atajos, descripción y frase).
- **B · Dejarlo así**: el botón ya lleva a todas.

Recomendación: A. La pantalla dice qué se le puede decir a Siri, y esas dos son de las que más se dicen.

## Resuelto (2026-10-28, encargo S20)

Jürgen eligió **A** (2026-10-21). «Cuánto gasté» y «Mi saldo» son las dos últimas filas de «Otros atajos», con el mismo
molde: nombre de Atajos, una línea de qué hacen («sin abrir la app») y la frase entre comillas, en los 16 idiomas. Sin
insignia Pro: son gratis. Visto en el simulador (`capturas/antes.png` → `capturas/despues.png` del PR) y fijado por
`SiriShortcutsScreenUITests` y los dos tests de paridad de frases.
