---
name: el-testigo-vive-menos-que-lo-que-describe
description: Un dato que describe a otro tiene que MORIR con él, y el borrado va DENTRO de su escritor — no en los call-sites. Sobrevivió al relevo de humano (14-sep) y un sello de excepción sobrevivió a la migración que lo cerraba (16-sep).
metadata:
  type: feedback
---

**Cuando persistas un dato que describe a otro —un testigo, un sello, una copia— el borrado va DENTRO
del escritor del dato que describe, nunca repetido en sus call-sites.**

**Why:** el 2026-09-14 guardé el `userRecordID` del Apple ID con el que nació la sesión privada, para
detectar cuándo cambia. Lo borré en `performSignOutWipeIfArmed`, al lado de `PrivateSessionMark.clear`,
y escribí en el docblock que «muere en un solo sitio». **Era falso y el propio docblock del eje lo
decía**: muere en DOS (el boot-wipe y `clearHandoverPrivateSessionMark`, el relevo de humano de
«Empiezo de cero»), y además se APAGA desde ocho sitios más.

El daño, que cazó una lente: el dueño entrega su teléfono → «Empiezo de cero» → la marca se borra y
**el testigo se queda** (lleva el prefijo `cloudSync.` justo para sobrevivir a «Vaciar datos»). La
persona nueva termina su onboarding, la marca se enciende con SU Apple ID, y en el arranque siguiente
la app le ofrece cerrar la sesión y **borrarle sus propios datos**, diciéndole que son de la cuenta
anterior. Y con `confirmedWithoutICloudCopy: true`, sin esperar al export.

**How to apply:**

- La pregunta no es «¿dónde se borra lo que describo?» sino **«¿cuántos sitios lo borran o lo apagan,
  y los conozco todos?»**. Si la respuesta tiene más de uno, colgar el borrado de los call-sites es una
  lista que hay que acordarse de ampliar — y nadie se acuerda.
- Si el dato descrito tiene un **embudo** (aquí `PrivateSessionMark.set/clear`, por donde pasan sus
  nueve escrituras), el borrado va ahí. Acoplar las dos piezas es correcto: el testigo no significa
  nada sin lo que describe.
- **Apagar cuenta igual que borrar.** No basta con `clear()`: `set(false)` también tiene que llevárselo,
  o el ciclo «se apaga por una puerta de grupos → se vuelve a encender al activar Yala completo» revive
  el testigo viejo.
- Y el pin es un source-scan sobre el cuerpo del escritor, porque **ningún test de comportamiento lo
  ve**: con el borrado quitado, todo lo observable sigue igual hasta que aparece el segundo humano.
- Corolario de escritura: si tu docblock dice «muere en un solo sitio», **cuéntalos** antes de escribirlo.
  El mío contradecía al docblock del fichero de al lado, que tenía razón.

**Segunda vez, 2026-09-16, por el lado de una EXCEPCIÓN.** Para que «Reintentar» tras un fallo no se bloqueara, dejé
pasar por la comprobación de «Migrar a la nube» las cuentas `complete` con el sello `.proceedMigration` de este teléfono.
Ese sello describe «intento a medias» y no moría al terminar la migración ni al cerrar sesión: una migración TERMINADA
seguía abriendo la puerta. Lo cazó la segunda pasada de la review. Se arregló en el escritor del hecho que lo termina
(el `complete` del líder cambia el sello). ⇒ **si un dato abre una excepción, busca también el escritor que la cierra.**

Relacionado: [[mi-docblock-tambien-es-una-premisa]] · [[el-guard-va-dentro-del-escritor]] ·
[[el-prefijo-que-elegi-tiene-dos-efectos]] · [[el-flag-que-conserva-deja-estado-incoherente]]
