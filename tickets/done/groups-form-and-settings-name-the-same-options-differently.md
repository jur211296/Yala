---
id: groups-form-and-settings-name-the-same-options-differently
status: done
area: groups
priority: low
created: 2026-10-21
updated: 2026-10-27
source: lote decidido 2.2 · 13 (L12-9) frente al lote 12 (L19-7)
---

# El formulario de crear y los Ajustes del grupo nombran las mismas opciones con palabras distintas

## Qué pasa

Dos decisiones de Jürgen del 18-oct, implementadas por separado:

| Opción | Formulario «Nuevo grupo» (L12-9 B) | Ajustes del grupo (L19-7 C) |
|---|---|---|
| Simplificar deudas | «Menos pagos entre ustedes» · «Yala junta las deudas…» | «Menos pagos entre ustedes» · «Si Ana te debe…» |
| Moneda única | «Todo en una moneda» | «Ver las deudas en una sola moneda» |
| División | «Cómo se reparte casi siempre» | «Cómo se reparte un gasto nuevo» |

Las dos siguen su decisión al pie de la letra; juntas, la misma opción se llama distinto según la pantalla.

## Qué haría falta decidir

Si se igualan (y con qué texto) o se dejan así. Claves: `groups.d13.form.*` y `groups.l19.options.*`.

## Cierre (2026-10-27, PR #654)

Decisión de Jürgen (2026-10-26): igualar a Ajustes. El formulario de crear lee ahora las claves de Ajustes del grupo
(«Ver las deudas en una sola moneda», «Cómo se reparte un gasto nuevo»); las claves d13 se retiraron de los 16 idiomas.
La ayuda de «Menos pagos entre ustedes» no contradice el ejemplo de Ajustes y se deja. Red:
`GroupsCrearDecididoUITests#test_newGroupForm_optionsAreFoldedUnderMoreOptions` (rojo sobre la base).
