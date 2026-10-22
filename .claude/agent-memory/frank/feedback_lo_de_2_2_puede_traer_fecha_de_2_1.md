---
name: lo-de-2-2-puede-traer-fecha-de-2-1
description: una revisión «para la versión siguiente» de un proveedor externo empieza por su página de retiradas — el 2026-10-07 escondía un apagado a 16 días
metadata:
  type: feedback
---

Una investigación etiquetada «para 2.2, no entra en 2.1» sobre un proveedor externo (modelos de IA,
APIs) empieza por la **página de retiradas/deprecaciones** del proveedor, antes que por precios o
calidad. El 2026-10-07 la revisión de IA iba encuadrada como trabajo futuro y la deprecación de OpenAI
decía que `gpt-4.1-nano` —el que lee las fotos— se apagaba **16 días después**, en producción y en todas
las versiones instaladas.

**Why:** el encuadre del encargo («2.2, investigación») heredado de la card me habría llevado a
entregar un informe tranquilo; el dato que cambia la prioridad estaba en la fuente, no en el repo.
Ver [[la-premisa-del-encargo-tambien-se-mide]].

**How to apply:** en cualquier encargo que toque un servicio de terceros, mide primero las fechas de
apagado contra lo que usa el código; si alguna cae antes de la próxima release, súbelo al principio del
informe y al «Necesita de ti», con ticket propio y fecha límite de decisión. Y recuerda que si el
identificador del modelo va en el binario, solo el servidor llega a tiempo a las versiones instaladas.
