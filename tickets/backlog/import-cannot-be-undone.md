---
id: import-cannot-be-undone
status: backlog
priority: medium
area: "import"
created: 2026-10-29
updated: 2026-10-29
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
