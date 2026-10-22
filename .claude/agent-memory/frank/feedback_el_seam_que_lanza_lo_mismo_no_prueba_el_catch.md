---
name: el-seam-que-lanza-lo-mismo-no-prueba-el-catch
description: Un seam de test que lanza el MISMO error que relanza el catch deja vivos «seam fuera del do» y «throw error»; que lance otro.
metadata:
  type: feedback
---

Un seam de «el fetch falla» debe lanzar un error DISTINTO del que el `catch` relanza (p. ej. `CocoaError(.fileReadCorruptFile)`),
y el test debe esperar el error convertido.

**Why:** el 2026-09-23 (Merkle de grupos) el seam lanzaba `GroupMerkleLocalReadError.leafFetchFailed`, igual que el `catch`.
Una lente cazó que sacar el seam fuera del `do`, o dejar el `catch` en `throw error`, pasaban en verde: el docblock
«el seam va DENTRO del `do`» afirmaba algo que nada verificaba. Con el `CocoaError` los dos mutantes murieron.
`SyncMerkle._testThrowOnLeafFetch` (canal personal) sigue con la misma debilidad.

**How to apply:** al escribir un seam dentro de un `do/catch` que convierte errores, que el seam lance un error ajeno y
añade esos dos mutantes a la tanda. Relacionado: [[el-oraculo-del-mutante-es-el-efecto-que-produce]].
