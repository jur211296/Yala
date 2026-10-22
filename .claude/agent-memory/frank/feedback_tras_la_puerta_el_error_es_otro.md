---
name: tras-la-puerta-el-error-es-otro
description: Un error que llega DESPUÉS de una puerta que ya filtra una causa no es de esa causa — contar el 401 del attest del canal personal en la racha del teléfono dio tres falsos positivos, y lo cazaron tres lentes a la vez
metadata:
  type: feedback
---

**Antes de copiar el criterio de un canal a otro, mira qué corre DELANTE de la petición en cada uno.** Si una puerta ya
filtra una causa, el error que llega después de ella habla de OTRA cosa, aunque el código de respuesta sea el mismo.

**Why:** el 2026-09-16 (`personal-sync-reads-an-offline-token-refresh-as-a-session-expiry`) copié de Grupos «el 401
`yala_attest_required` suma a la racha del TELÉFONO» al canal personal, y moví el acierto de la racha al 200 para que el
aviso fijo pudiera salir, que es lo que pedía el ticket. En Grupos no hay puerta: el cliente manda la petición sin cabecera
cuando no consigue el token, así que el 401 incluye al teléfono. En el personal, `CloudSyncRuntime.resolveAttest` consigue
el token ANTES de subir: el 401 que llega después es el reloj, un build o el servidor. Tres lentes de la review lo cazaron
por separado con tres escenarios (reloj atrasado 24 h con la salida con pérdida ofrecida a quien atesta, una regresión de
build diciendo «usa otro teléfono» a todo el parque, un fallo de subida que dejaba el aviso para siempre). Retirarlo fue lo
limpio: pasajero, canario propio y sin tocar la racha.

**How to apply:**

- Al portar un criterio «como en X», escribe en una frase **qué filtra ya el camino de destino antes de ese punto**. Si la
  respuesta no es «nada», el mismo código de error cambia de significado.
- Un ticket que pide «que el aviso aparezca para esta población» trae una premisa: que el aviso DIGA la verdad a esa
  población. Léele el copy antes de hacerlo salir (aquí culpaba al teléfono). Ver [[la-premisa-del-encargo-tambien-se-mide]].
- Y la contracara: la migración y el adopt usan los mismos clientes SIN la puerta, así que un canario sobre ese 401 mezcla
  las dos poblaciones. Cuenta los llamadores del cliente, no solo el del camino que estás arreglando
  ([[una-frase-de-alcance-se-cuenta-por-llamadores]]).

Relacionado: [[review-adversarial-caza-lo-mio]] · [[el-predicado-del-ticket-no-es-el-criterio]].
