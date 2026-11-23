---
id: import-cannot-be-undone
status: done
priority: medium
area: "import"
created: 2026-10-29
updated: 2026-11-22
source: "auditoría del import 2.2 (sesión S27j), H12 de docs/import/AUDITORIA-IMPORT-2-2.md"
---

# Un import no se puede deshacer

**Versión propuesta: 2.4.** Media, mejora: 2.4. La decide Jürgen. Card: `xs1e`.

## Qué ve el usuario

Para quitar 3.000 movimientos mal importados hay que borrarlos a mano.

## Evidencia

Tras guardar solo queda el aviso del resultado (`ProfileView.swift:905-937`); ningún movimiento sabe de qué import vino.

Detalle y contexto: `docs/import/AUDITORIA-IMPORT-2-2.md`, H12.

## Propuesta

Barata: guardar en el dispositivo los identificadores del último import durante 24 h y ofrecer «Deshacer importación» en el aviso y en Ajustes › Importar, borrando por el servicio de siempre (en modo nube emite los borrados). Completa: un `importBatchID` en el modelo, que entra en la ventana de esquema de su versión. Recomiendo la barata.

## Criterio de hecho

- [ ] Importar y deshacer deja la base como estaba (movimientos, categorías y etiquetas creadas por el import).
- [ ] En modo nube, la otra instalación ve el deshacer.

## Hecho (2026-11-22, lote 1 de Importar registros)

La opción barata que recomendaba el ticket, sin cambio de esquema (`ImportUndoService`).

- Al guardar un import se apunta en un fichero del dispositivo (Application Support) lo que creó: movimientos (por su
  instante de creación, fecha e importe), categorías, subcategorías, etiquetas, cuentas y las fechas de saldo inicial que
  retrocedió. Caduca a las 24 h; un import nuevo lo sustituye.
- «Deshacer importación» en el aviso del resultado (abre Importar y pregunta) y en Ajustes › Importar, con confirmación
  y avance («Deshaciendo la importación… 300 de 3000»). Borra con `context.delete` + `save`, por tandas de 100 con una
  vuelta del hilo principal entre tandas. Lo creado que ya usa otra cosa (una etiqueta puesta a mano después) se queda.
- **No se guardan `PersistentIdentifier`**: con ellos el deshacer no encontraba nada (medido en las pruebas).
- Pruebas: `ImportarLote1DeshacerTests` (base igual que antes, etiqueta usada se queda, saldo inicial restaurado,
  caducidad a las 24 h, un import vacío no pisa el registro) y el XCUITest `ImportarLote1UITests`.
- En modo nube, la otra instalación ve el deshacer: medido contra staging en
  `import-of-thousands-of-rows-in-cloud-mode-is-unmeasured`.

- [x] Importar y deshacer deja la base como estaba (movimientos, categorías y etiquetas creadas por el import).
- [x] En modo nube, la otra instalación ve el deshacer.
