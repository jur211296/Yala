---
name: el-paso-de-antes-tambien-lee
description: Al cerrar una familia «lectura fallida = vacío», mide también el paso que corre ANTES de los sitios del ticket y los alimenta; el 23-sep el backfill de identidades tragaba su error igual que los seis inventarios.
metadata:
  type: feedback
---

Al cerrar una familia de «no pude leer = no hay nada», recorre el paso que corre ANTES de los sitios que nombra el
ticket y les prepara la entrada. Si ese paso traga su error, los sitios que arreglaste reciben un corpus incompleto por
otra puerta y vuelven a decidir mal, con los tests en verde.

**Why:** el 23-sep (`an-incomplete-inventory-reads-as-the-whole-corpus`) cerré los seis inventarios de la migración y
sus mutantes murieron. La lente de gemelos encontró `SyncIdentityService.backfillIdentities`, que corre justo antes de
dos de ellos y tragaba su fallo. Las filas que se quedaban sin identidad las saltaba el snapshot (`identityGap`), y el
adopt las contaba como `needsIdentity` y no como huérfanas, así que se cerraba en falso por el camino que yo creía
cerrado. Ningún ticket lo nombraba: no figuraba en la tabla del ticket porque no es un inventario, sino su productor.

**How to apply:** antes de dar por cerrada la familia, para cada sitio arreglado pregunta «¿quién escribe lo que este
sitio lee, en el mismo flujo?» y mira el `catch` de ese escritor. Emparenta con [[el-gemelo-vive-en-el-mismo-save]] (el
alcance lo decide el flujo, no la lista del ticket) y con [[la-premisa-del-encargo-tambien-se-mide]].
