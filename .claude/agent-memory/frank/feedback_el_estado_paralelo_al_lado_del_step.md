---
name: el-estado-paralelo-al-lado-del-step
description: Cuando un dato «acompaña» a otro que ya viaja, mételo DENTRO en vez de al lado — un acompañante se hereda en silencio, y mi propio docblock afirmaba que no podía pasar.
metadata:
  type: feedback
---

Si un dato nuevo tiene que ir siempre junto a otro que ya existe, no lo pongas al lado: mételo
dentro, con payload, y deja que el compilador obligue a cada productor a decidirlo.

**Why:** el 2026-09-11 añadí un `Purpose` a la puerta de Grupos del Welcome y lo puse en un `@State`
de `ContentView`, «acompañante obligado» del step. Escribí en su docblock que *cada productor que
pone `.groupsGate` lo escribe EXPLÍCITO*. **Tres de los cinco no lo hacían** — y eran los tres que ya
existían antes de mí, así que heredaban el valor del uso anterior: quien volvía atrás en una
invitación y tapeaba «Crear mi primer grupo» acababa **uniéndose al grupo de otro**. Dos lentes
adversariales lo cazaron por separado, y las dos citaron mi comentario como la afirmación que el
código contradecía. Moverlo a `case groupsGate(purpose:)` lo mató de raíz: un caso nuevo del enum no
compila sin decidirlo.

**How to apply:** cuando estés a punto de escribir «esto siempre va con aquello», pregúntate quién
más escribe *aquello* y cuéntalos — no lo afirmes. Si son más de uno y no puedes tocarlos todos con
una razón clara, el dato va DENTRO. Es la misma familia que el «sin valor por defecto a propósito»
que el repo ya usa para los términos de sus puertas: un default y un acompañante son la misma
trampa, porque los dos dejan que un call-site nuevo herede en silencio.

Y el corolario de método, que es el que más me repito: **un docblock que declara lo que hacen los
demás call-sites es una afirmación verificable con un grep** — ver [[mi-docblock-tambien-es-una-premisa]].
