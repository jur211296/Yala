---
name: el-denominador-de-una-resta-es-el-numero-que-se-ve
description: Al medir la proporción de un total, el denominador es el número que se MUESTRA; si ese número es una resta, usar la suma de magnitudes que lo formó apaga la marca justo en quien más historial tiene.
metadata:
  type: feedback
---

Cuando midas «qué fracción de este número es dudosa», el denominador es **el número que el usuario
ve**. Si ese número es una resta (un saldo, un neto), no uses la suma de magnitudes que lo formó.

**Why:** el 9-sep escribí `periodBalanceIsApproximate` del widget dividiendo entre `Σ|monto|` de todo
el histórico, cuando el saldo mostrado es la resta. Dos lentes de la review lo cazaron por separado.
El daño es sistemático y va **en la dirección de no marcar**: 400 dudosos sobre un saldo de 500 son
el 80 % y marcan; sobre una facturación de 300.000 son el 0,13 % y no. Cuanto más historial tiene el
usuario, más se apaga la marca — al revés de lo que necesita. El contrato ya lo decía en el docblock
de `ApproximateMarkThreshold` («o su valor absoluto cuando el número es una resta») y el propio
`return` lo hacía bien tres campos más arriba, para el neto de caja.

**El numerador es el caso opuesto y no se confunden**: ése SÍ suma magnitudes siempre, porque los
errores de dos conversiones distintas no se cancelan entre sí. Numerador en magnitudes, denominador
en el número que se ve.

## Y al día siguiente cometí el error GEMELO, por el otro lado del cociente (2026-09-09)

Sabiendo todo lo de arriba, en el bridge de grupos metí **el neto en el NUMERADOR**: un gasto de
grupo se sintetiza como `pata real + patas de préstamo`, y marqué `abs(neto)` como magnitud dudosa.
La lente 2 lo tumbó citando el contrato del helper, que trae **este mismo ejemplo numérico**. Falla
en las dos direcciones: con mi parte pequeña se queda corto (1.000 sobre 26.000 = 3,8 %, sin marca,
con un tercio de la aritmética dudosa) y con mi parte grande se pasa (9.700 sobre 10.300 = 94 %,
marcando el mes por 300 dudosos; en el límite, dos céntimos).

**Why:** haber aprendido la mitad de una regla la deja peor que no saberla, porque el «ya me sé
esto» apaga la comprobación. La frase de arriba —«numerador en magnitudes»— ya estaba escrita en
esta ficha **y en el docblock del helper**, y aun así la incumplí en el fichero de al lado.

**How to apply:** cuando un importe **no salga de una sola fila** —una síntesis, un neteo, un bridge—
las dos mitades del cociente se deciden por separado y en voz alta: *¿qué incertidumbre ENTRÓ?*
(magnitudes de las piezas) y *¿qué número SALE?* (lo que se pinta). Y el test que las distingue no es
uno: son **dos**, uno por dirección — con la parte pequeña y con la parte grande. Con un solo caso,
las dos implementaciones dan el mismo veredicto.

**How to apply:** por cada llamada al umbral, pregúntate qué `value:` pinta la vista con esa marca y
pásale eso. Y **el test tiene que discriminar**: el que yo tenía usaba −500 dudosa y −500 exacta, que
da 50 % por las dos reglas y pasaba igual con el bug dentro — la misma trampa que
[[la-asercion-que-no-puede-fallar]]. El caso que separa es el de dos lados grandes con una resta
pequeña.

Corolario de método del mismo día: **cuando dos lentes independientes coinciden en un hallazgo, es
real; cuando una lo levanta y hay una decisión escrita en contra, gana la decisión.** Las mismas
lentes señalaron el OR de `LiveBalanceCalculator` como bug — y era una decisión explícita de Jürgen
del 8-sep («su unidad ya es la divisa, no la transacción»). Lo que faltaba no era el fix: era que la
decisión estuviera escrita **donde se lee el código**, para que la próxima review no la vuelva a
levantar.
