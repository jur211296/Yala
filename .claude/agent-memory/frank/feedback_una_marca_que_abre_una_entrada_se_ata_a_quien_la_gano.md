---
name: una-marca-que-abre-una-entrada-se-ata-a-quien-la-gano
description: Una marca durable que ensancha quién ve una entrada SIN puerta la hereda cualquier identidad posterior; átala a la cuenta que la ganó, y mira también la sesión que aparece DESPUÉS de escribirla
metadata:
  type: feedback
---

Si una marca durable abre una entrada que se salta una comprobación (una tarjeta sin la puerta de identidad, un atajo sin
guard), **átala a la identidad que la ganó** y compara en los dos momentos: al PINTAR (la sesión que haya entonces) y
tras FIRMAR (la cuenta que se eligió después, que al pintar no existía).

**Why:** el 2026-09-23 (`adopt-claim-stays-parked-with-no-ceiling`) la salida de un adopt dejaba `adoptClaimExitRaw` para
que Almacenamiento ofreciera «Activar la nube en este dispositivo» sin marcador. En el Paso 0 acepté el riesgo con «la
sesión será la del intento». La lente de consumidores midió que no: semanas después la persona entra en Grupos con OTRA
cuenta, la tarjeta reusa esa sesión sin preguntar, y el adopt —que no pasa por la puerta de «Migrar»— sube lo local a esa
cuenta. Además la marca no caducaba: sobrevivía a volver a iCloud, donde abría el adopt de una cuenta congelada.

**How to apply:** al diseñar una marca que ofrece algo, tres preguntas: **(1)** ¿qué comprobación se salta lo que abre?;
**(2)** ¿de QUIÉN es la marca? Apúntalo cuando se gana, no cuando se lee: si el motivo de la salida es la sesión borrada, al
salir ya no hay cuenta que leer; **(3)** ¿qué la borra además del camino feliz? Recorre los cierres de la máquina (aquí
`icloudActive`). Un «acepto el residual porque la sesión será la misma» es una premisa: mídela como cualquier otra.
Relacionado: [[feedback_mi_salida_nueva_es_un_camino_muerto]], [[feedback_un_registro_no_prueba_la_eleccion]],
[[feedback_la_premisa_del_encargo_tambien_se_mide]].
