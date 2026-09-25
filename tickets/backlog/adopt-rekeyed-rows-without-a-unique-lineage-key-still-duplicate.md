---
id: adopt-rekeyed-rows-without-a-unique-lineage-key-still-duplicate
status: backlog
priority: medium
area: "modo-nube, adopt"
created: 2026-09-25
updated: 2026-09-25
source: "ticket `adopt-window-late-leader-identity-export-can-duplicate-after-the-remount` (2026-09-25), residual del Paso 0"
---

# En el adopt, una fila re-identificada que no casa por clave sigue subiendo duplicada

## El problema, en lenguaje de usuario

Activaste la nube con un teléfono mientras otro estaba sin red. El otro volvió días después y mandó a iCloud sus datos
viejos. Si ahora activas la nube en otro teléfono (o en ese mismo), algunas de tus categorías, y los movimientos más
antiguos, pueden aparecer dos veces en todos tus teléfonos.

## Lo medido y lo inferido (2026-09-25)

- **Medido, con tests**: con el marcador del líder, el adopt ya casa por clave de linaje ÚNICA las filas que llegan con
  una identidad que el backend no conoce (`MigrationWorkExecutor.rebindRekeyedRows`). Movimientos, borradores y
  favoritos casan por `created_at` en ms; comercios, por su clave canónica; las categorías semilla, por la clave del
  deduplicador.
- **Medido en el código**: no casan las categorías del usuario (no tienen clave: una fila del backend sin clave apaga el
  casado de toda la tabla, `lineageKeyRebinds`), los movimientos cuyo `createdAt` rellenó cada teléfono en la migración
  ligera, ni las claves repetidas. Tampoco los tipos de cambio (`adoptLineageExemptTables`, fuera del casado) ni una fila
  cuya gemela está BORRADA en el backend (el casado solo mira las vivas): esa sube como nueva y el movimiento borrado
  vuelve en todos los teléfonos. Esas filas suben como huérfanas: el duplicado queda en el backend (lo señaló la review
  adversarial del ticket de origen).
- **Por qué no se bloquean**: el líder desplazado trae también filas que creó sin red, que no están en el backend y
  tienen que subir, y con el marcador casi siempre faltan filas (lo que el relevo escribe tras su remonte no llega por
  CloudKit). Bloquear dejaba fuera para siempre a todo teléfono que adopte.
- **Sin medir**: qué gana CloudKit en el conflicto del campo `syncID` (lo mide el canario `cloudRelayIdentityRestored`).
  Si gana el primero en exportar, este ticket no pasa nunca.

## Opciones (sin decidir)

1. Guardar en el backend las coordenadas del record de CloudKit de cada fila (columna nueva, subida con el snapshot):
   el adopt casaría por el record, que es el mismo en todos los teléfonos. Es el puente exacto; pide migración de
   esquema, cambio del gateway y del snapshot.
2. Casar por el contenido entero de la fila además de la clave. Más alcance, con riesgo de fundir dos movimientos
   iguales de verdad.
3. Dejarlo si el canario sale a cero en la flota.

## Criterios de aceptación

- [ ] Medido con el canario si CloudKit le da la razón al líder desplazado y, si se la da, que el adopt no duplique las
      filas sin clave única.
