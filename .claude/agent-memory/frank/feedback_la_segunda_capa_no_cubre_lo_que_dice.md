---
name: la-segunda-capa-no-cubre-lo-que-dice
description: Una defensa en profundidad puede no alcanzar al objeto que dice proteger — mide el ALCANCE de cada capa por separado antes de llamarla capa, y pregunta qué cuesta la que no sirve
metadata:
  type: feedback
---

**Antes de llamar «segunda capa» a algo, mide si el objeto que quieres proteger cae DENTRO de su
alcance.** Dos mecanismos que atacan el mismo bug no son dos capas si uno de ellos no llega.

**Why:** el 2026-09-11, en `detach-history-replay-can-tombstone-groups-on-next-launch`, el daño era que
los borrados locales del desasociar acabaran viajando al servidor y borrando los gastos de todos los
miembros. Entregué dos mitades y escribí en el docblock que «van juntas: la firma impide traducirlas y el
ancla impide siquiera mirarlas».

**El ancla no impedía nada.** El ancla que se conservaba era la del último drain **anterior** al
desasociar, y los deletes son **posteriores**: `fetchHistory($0.token > token)` los devuelve igual. Lo
único que los descartaba era el autor. La segunda capa no existía — y lo peor es que mi propio test (2) lo
enseñaba en su traza y no lo leí: el tercer drain SÍ ve esas transacciones.

Y además **costaba**: `lastDrainedTxAt` es uno de los cuatro suelos del corte de purga del History, y
conservarlo sin canal que lo avance —tras soltar la cuenta no hay sesión— lo dejaba congelado. Inocuo hoy
por un detalle de otro subsistema (la purga solo corre con el runtime personal, que es de `.cloud`), pero
clavado para siempre en cuanto esa persona migrara a la nube.

⇒ Una capa que no cubre + un pasivo latente = **se retira**. El arreglo quedó en un solo mecanismo, y es
más fuerte que los dos: vive dentro del escritor, no se puede saltar por olvido, y su mutante está medido.

**How to apply:**

- **Sitúa el objeto en el eje de la capa.** Si la defensa es un high-water, un umbral, una ventana o un
  rango, la pregunta es literal: *¿el objeto cae por encima o por debajo?* Aquí bastaba mirar que un
  borrado que acabo de hacer es posterior a cualquier ancla anterior a él. Treinta segundos.
- **Cada capa se muta por separado.** Si el mutante de la capa B no pone rojo ningún test que mida
  CONSECUENCIA —solo los que miden su propia forma—, lo más probable es que B no defienda nada. Esa fue la
  señal y la tuve delante: el mutante de B mataba un test de forma y ninguno de daño.
- **A una capa que no llega, súmale lo que cuesta.** Un mecanismo inútil rara vez es gratis: suele
  congelar un estado, retener memoria o disco, o mentirle a un tercero que lo lee. Búscale al menos un
  lector (`grep` de su campo) antes de dejarlo puesto.
- **Y el ticket puede estar pidiendo la capa que no sirve.** Éste ofrecía dos vías —boot-wipe por archivos
  o anclar el cursor— y la buena era una tercera que no nombraba. Lo que es innegociable es el **criterio**
  («que no dependa del orden de `syncCycleOnce`»); el «cómo» de un ticket es una propuesta, y se mide igual
  que todo lo demás. Ver [[feedback_la_premisa_del_encargo_tambien_se_mide]].

Relacionado: [[feedback_prefiere_lo_limpio_a_lo_defensivo]] — Jürgen retira el mecanismo que falla en vez
de apuntalarlo, y al limpiar hay que nombrar qué se pierde (aquí: la defensa queda en una sola capa, y se
acepta por dónde vive). Y [[feedback_review_adversarial_caza_lo_mio]]: esto lo cazó la tercera lente, no yo.
