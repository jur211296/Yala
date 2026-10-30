---
id: import-has-no-duplicate-detection
status: backlog
priority: medium
area: "import"
created: 2026-10-29
updated: 2026-10-29
source: "auditoría del import 2.2 (sesión S27j), H11 de docs/import/AUDITORIA-IMPORT-2-2.md"
---

# Reimportar el mismo archivo lo duplica todo

**Versión propuesta: 2.4.** Media (falta de protección, no un fallo): tema del import, 2.4. Va bien junto a `import-cannot-be-undone`. La decide Jürgen. Card: `kfma`.

## Qué ve el usuario

Si importa dos veces el mismo extracto, todo sale al doble, sin aviso.

## Evidencia

Ninguna de las cuatro rutas de `TransactionCSVImportService` compara con lo que ya existe; `TransactionItem` no guarda de qué import vino.

Detalle y contexto: `docs/import/AUDITORIA-IMPORT-2-2.md`, H11.

## Propuesta

Huella por fila (fecha, importe, moneda, cuenta, nota) contra lo existente y dentro del archivo. La vista previa dice «N parecen ya importados» y por defecto los salta, con opción de importarlos igual.

## Criterio de hecho

- [ ] Importar dos veces el mismo archivo: la segunda vez la vista previa propone saltar todas las filas.
- [ ] Dos filas iguales legítimas en el mismo archivo (dos cafés el mismo día) se pueden importar.
