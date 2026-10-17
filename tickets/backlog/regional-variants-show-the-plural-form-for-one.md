---
id: regional-variants-show-the-plural-form-for-one
status: backlog
priority: low
area: "l10n"
created: 2026-10-17
updated: 2026-10-17
source: "implementación del lote 8 de la auditoría UX 2.2 (2026-10-17), hallazgo fuera de alcance"
---

# En es-ES, es-AR, en-GB y pt-PT los recuentos de uno salen en plural

## El problema, en lenguaje de usuario

Con el iPhone en español de España, español de Argentina, inglés británico o portugués de Portugal, los textos que
cuentan cosas dicen el plural también para una: «1 seleccionados», «1 posibles duplicados», «Editar 1 registros».

## Qué se sabe

- Los plurales viven en los `.stringsdict` de los 12 idiomas base. Las cuatro variantes **no tienen `.stringsdict`**:
  llevan la forma `other` como línea plana en su `.strings` (molde de `records.selectedCount`, PR #499), porque sin
  ella la clave salía cruda (`.claude/rules/l10n.md`: iOS no hace fallback por clave con idioma de sistema).
- Inferido, no medido: con la variante como idioma del sistema, iOS resuelve la variante y lee esa línea plana, que es
  la forma plural. Con el idioma elegido dentro de Yala, `ls()` cae al padre y el plural sale bien.
- El lote 8 añadió diez plurales más con el mismo molde (`records.l8b.*`).

## Qué hacer

1. Medir en el simulador con `-AppleLanguages "(es-ES)"`: modo selección con un registro elegido.
2. Si se confirma, dar a las cuatro variantes su `.stringsdict` (copia del padre, con las formas propias de pt-PT) y
   que `LocalizationParityTests` exija la paridad de plurales también en ellas.
