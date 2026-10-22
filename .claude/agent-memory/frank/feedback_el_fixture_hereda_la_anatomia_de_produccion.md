---
name: el-fixture-hereda-la-anatomia-de-produccion
description: Un fixture que inventa la forma de sus filas en vez de copiar la que escribe producción da un veredicto falso — y el error se ve en el TOTAL, no en la fila; además tiene que ser DISCRIMINANTE y no solo "sembrar algo"
metadata:
  type: feedback
---

**Cuando escribas un fixture de QA que reproduzca un estado que la app produce sola, cópiale la
anatomía a producción campo por campo. No la deduzcas del ticket.**

**Why:** el 2026-09-09, sembrando las dos patas de un gasto de grupo, puse la pata real con **«mi
parte»** porque era lo que el ticket describía como resultado. Producción escribe `-totalAmount` y
la de préstamo `lent = total - myShare`; el neto que reconstruye el adjustment es entonces
`-total + lent = -myShare`. Con mi versión el neto salía **`+lent`**: un gasto de grupo que aparecía
como **ingreso**, con el importe cambiado de signo y de magnitud.

Lo delator no fue la fila —cada pata parecía razonable por separado— sino **el total sintetizado**,
que el propio fixture imprimía: `+750` donde tenían que salir `−150`. Sin ese `print` el fixture
habría sembrado durante meses un escenario que no existe, y los veredictos que colgaran de él
habrían sido falsos con la suite en verde.

**How to apply:**

- Antes de escribir el fixture, **lee la función de producción que crea esas filas** y anota qué
  pone en cada campo, con su `fichero:línea`. En este caso `GroupTransactionBridge.createVirtualLent`
  y su hermana; el dato que faltaba estaba en dos líneas separadas por 200.
- **Haz que el fixture imprima el resultado agregado que va a producir**, no solo «sembré N filas».
  El error de composición se ve ahí y en ningún otro sitio.
- Fija esa relación con un test que compare el agregado contra la constante del fixture, no contra
  un número escrito a mano. El mío es
  `theAdjustment_suppressesTheLoanLeg_andNetsTheRealOne`, y con el mutante de «mi parte» se pone
  rojo.

## La segunda mitad: un fixture tiene que ser DISCRIMINANTE

Sembrar el escenario no basta. **La pregunta es si el fixture daría un veredicto distinto con el
bug dentro y con el bug fuera**, y hay que responderla a propósito porque es fácil que no.

El del bridge lo es porque la pata real se siembra **exacta**: si la síntesis no leyera la pata de
préstamo suprimida, la magnitud dudosa sería **cero** y el mes no marcaría. Si hubiera sembrado las
dos provisionales —que es lo natural, porque producción las crea así— el mes habría marcado igual
leyendo solo el flag de la pata real, **con el bug dentro**, y el fixture habría dado verde sobre
código roto.

El del chat es lo mismo por otro lado: guarda el monto **convertido** y no el crudo, porque el
cociente de los dos montos es lo que separa la población que se cura en el sitio de la que se
reabre. Con el monto crudo el fixture habría ejercitado el camino contrario al del ticket.

**El gesto:** por cada fixture, escribe la frase «con el bug dentro, este fixture daría ___». Si la
respuesta es «lo mismo», el fixture no sirve todavía. Y cuando puedas, demuéstralo con el mutante en
vez de razonarlo.

Relacionado: [[la-asercion-que-no-puede-fallar]] · [[mi-fix-hereda-la-forma-del-bug]] ·
[[la-premisa-del-encargo-tambien-se-mide]].
