---
name: el-filtro-va-detras-de-la-traduccion
description: Un filtro de «no emitas esto» mira la identidad con la que la fila SALE, no la que trae; si otra función la traduce después, el filtro va detrás
metadata:
  type: feedback
---

**Un filtro que decide «esto no sale» tiene que mirar las identidades con las que la fila va a salir, no con las que
entra al paso.** El 26-sep puse el filtro del adopt en la rama `.delete` de `translateChange` ANTES de
`relayTombstoneIdentity`, mirando solo la identidad preservada. Esa función traduce después a la identidad del registro
—la que el backend conoce—, y el tombstone traducido se escapaba justo en el caso que el ticket quería frenar. Lo cazaron
dos lentes de la review por separado; los tests y 11 mutantes estaban verdes.

**Why:** es la forma inversa de [[la-huella-se-ata-al-que-entra]]: allí el sello se ataba a la respuesta y no al que
entra; aquí el filtro se ató al que entra y no a lo que sale. Una función que emite «además» otra identidad es un
segundo escritor de la salida, y el filtro no la ve si va delante.

**How to apply:** antes de colgar un filtro de una rama del drain (o de cualquier emisor), lista TODO lo que esa rama
acaba emitiendo —tombstones extra, traducciones, remaps— y pasa el filtro por cada uno. Si la función que añade salidas
también emite rastro o canario, muévelo detrás del filtro: si no, cuenta un borrado que no salió.
