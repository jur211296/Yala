---
name: el-scan-de-la-condicion-no-ve-la-rama-vacia
description: Un source-scan que busca `x > 0` lo cumple un `if false, x > 0` y una rama vacía; exige que la rama AÑADA, y con la cifra correcta
metadata:
  type: feedback
---

**Un source-scan que comprueba la CONDICIÓN de un `if` no prueba que dentro pase nada. Acota la
rama y exige que añada — y que añada con SU cifra, no con la del vecino.**

**Why:** el 2026-09-21 escribí un test que deriva los términos de un predicado del propio código y
exige que cada uno tenga su card en la pantalla. Comprobaba `lista.contains("s.\(termino) > 0")`.
Sonaba bien y tenía control positivo. El mutante `if false, s.categoriesCount > 0 {` **SOBREVIVIÓ**:
el literal seguía ahí. Y el mutante realista —vaciar el cuerpo del `if`, dejando la condición— lo
habría pasado igual.

Con el scan endurecido (acotar el cuerpo del `if` con llaves balanceadas y exigir dentro
`items.append(CountItem(` **y** `count: s.<termino>`), cayeron los tres: la card borrada, la rama
vacía y la card que se añade con la cifra del vecino — este último compila, no deja warning y en
pantalla son dos números creíbles.

**How to apply:**

- El patrón es: `body(of: "<cond> {", in: <cuerpo ya acotado>)` y dentro **dos** aserciones, la del
  efecto (`append`, `state =`, la llamada) y la del DATO que viaja. Una sola deja pasar el swap.
- **`body(of:)` cuenta LLAVES.** Sobre un marcador que abre paréntesis —`Foo(`— no acota nada:
  sigue hasta la primera `}` de fuera y devuelve medio fichero, con lo que el `contains` lo cumple
  cualquier vecino. Para eso está `call(of:)`, por paréntesis balanceados.
- Y el marcador de una función se pone en el **cierre de su signatura** (`…) {`), no en su apertura:
  empezar en `func f(` deja `depth` sin la llave que abre, así que el cierre de la función baja a 1
  en vez de a 0 y el tramo se come el resto del fichero. Mide antes que el marcador sea único.
- La prueba de que el scan sirve **no es leerlo: es el mutante que vacía la rama**. Si no lo tienes
  escrito en la tanda, el scan no está verificado.
- Hermanas: [[el-source-scan-de-dos-literales-no-es-una-red]], [[el-tramo-sin-acotar-lo-cumple-el-vecino]],
  [[la-asercion-que-no-puede-fallar]], [[el-oraculo-del-mutante-es-el-efecto-que-produce]].
