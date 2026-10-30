---
id: import-name-matching-is-exact
status: backlog
priority: low
area: "import, categories, tags"
created: 2026-10-29
updated: 2026-10-29
source: "auditoría del import 2.2 (sesión S27j), H16 de docs/import/AUDITORIA-IMPORT-2-2.md"
---

# Categorías, subcategorías y etiquetas casan solo por nombre exacto

**Versión propuesta: 2.4.** Baja, sin pérdida: 2.4. La decide Jürgen. Card: `tbws`.

## Qué ve el usuario

«comida» no es «Comida»: con «Crear categorías que falten» apagado (lo está por defecto) la fila se rechaza; encendido, se crea una categoría duplicada. Una etiqueta archivada con el mismo nombre crea otra.

## Evidencia

`CategoryImportHelper.swift:115-122` (`name ==`), `TransactionCSVImportService.swift:610-616` (`tag.name == name && tag.isActive`), interruptor apagado en `ImportIntroSheet.swift:103`.

Detalle y contexto: `docs/import/AUDITORIA-IMPORT-2-2.md`, H16.

## Propuesta

Comparar sin mayúsculas, tildes ni espacios de más; reutilizar (y reactivar) la etiqueta archivada; llevar el interruptor a la vista previa con la lista de lo que crearía.

## Criterio de hecho

- [ ] Tests: «comida», «Comida » y «COMIDA» resuelven a la misma categoría; una etiqueta archivada se reutiliza.
