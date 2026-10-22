---
name: mi-arreglo-rompe-la-premisa-de-otro-guard
description: Ensanchar un predicado deja mentirosos a los guards que se apoyaban en su forma vieja — y el que se rompe suele estar a varios ficheros de distancia, justificado por escrito.
metadata:
  type: feedback
---

Cuando ensancho un predicado, los guards que se apoyaban en su forma ANTERIOR pasan a ser falsos, y no
me entero: siguen compilando, siguen verdes, y su docblock sigue explicando por qué son correctos.

**Why:** el 2026-09-10 añadí un tercer término al neutro durable. Un callback a cinco ficheros de
distancia justificaba saltarse el aviso de datos existentes así: «el mount neutro exige que no haya
archivo de store, así que en este camino no puede haber datos que confirmar». Era cierto con los dos
términos viejos —los dos exigen que el archivo no exista— y mi término lo rompió: una sesión solo-grupos
tiene archivo lleno y monta neutro igual. Resultado: «Primera vez → privado» dejaba de borrar los datos
del anterior, y en el arranque siguiente el espejo los subía a iCloud. Regresión GRAVE, con la suite
entera en verde, y la escribí yo.

El mismo día, la versión corta del mismo error: escribí la regla «quien no arma, no desarma» en el
docblock del sitio donde SÍ la cumplía, y omití el guard en el otro sitio, tres ficheros más allá.

**How to apply:**

- Al ensanchar un predicado compartido, **busca quién razona sobre su forma**, no quién lo llama:
  `grep` de los términos que quitas del camino crítico («no existe el archivo», «solo un arranque»,
  «solo si X»). Los guards que se apoyan en una IMPLICACIÓN del predicado no aparecen en el grafo de
  llamadas.
- Una frase de docblock del tipo «aquí no puede pasar X porque Y» es una **precondición heredada**. Si
  tocas Y, esa frase es un bug pendiente. Vale igual para las mías: en la misma sesión escribí cuatro
  copias de una justificación cuyo recorrido no existía (la vuelta por el Welcome repone el flag), y la
  conclusión se sostenía por OTRO camino — o sea que el diseño era correcto y el argumento, inventado.
- **Y aplícate la regla que acabas de escribir a los demás sitios del mismo diff**, uno por uno. Es
  literalmente la forma del bug: enunciar el invariante donde ya se cumple.

Relacionado: [[mi-fix-hereda-la-forma-del-bug]], [[mi-docblock-tambien-es-una-premisa]],
[[la-correccion-de-la-lente-reintroduce-el-bug]].

---

## La variante del 2026-09-14: no ensanché el predicado — abrí un CAMINO donde su premisa no se cumple

`restore-start-fresh-keeps-the-imported-corpus`. El predicado no cambió ni una letra; lo que cambió fue
**por dónde se llega a él**, y dos guards a varios ficheros de distancia se volvieron inertes:

- **El neutro durable del borrado.** `armICloudCorpusWipe` arma también `armNeutralMount`, cuyo
  predicado es `armado && !hasShownWelcomeChooser`. El docblock lo justificaba así: «en la puerta nadie
  ha marcado el chooser todavía — lo marcan las SALIDAS, no la puerta». Cierto por la entrada vieja;
  falso por la mía, que llega **desde Restaurar**, donde el flag ya se marcó al entrar. Un kill durante
  el borrado volvía a montar espejo y re-importaba justo lo que se estaba borrando.
- **La retirada del arm.** Nadie la hacía en las salidas no destructivas de la puerta, y no mordía por
  un **efecto colateral**: con el mount neutro toda salida RELANZA, persiste un destino, y
  `presentNextOnboardingScreen` retira el arm junto con él. Mi camino llega con el espejo ya adjunto, así
  que **no relanza** y esa red no existe. Consecuencia medida: salir por «Traer mis datos», restaurar el
  histórico, terminar — y el arranque siguiente lo borraba entero, a ciegas.

**Lo que añade a la ficha:** un guard no solo depende de la FORMA de su predicado, sino de **qué es
cierto en el camino por el que se llega**. Al dar una entrada nueva a una pantalla existente, la
pregunta es «¿qué daba por sentado quien la escribió sobre cómo se llega aquí?» — y eso suele estar en
un docblock que empieza por «aquí todavía no…» o «en este punto ya…».

**Y el olfato barato:** si una red funciona «porque el proceso muere» o «porque el arranque siguiente lo
recalcula», tu camino nuevo la desactiva en cuanto no relance. Buscar el relanzamiento es un `grep`.

---

## La variante del 2026-09-17: escribí la regla en una rama y la rompí en su HERMANA, en el mismo diff

`previous-person-cloud-session-survives-fresh-start-and-reinstall`. En la rama «Soy nuevo sin datos»
escribí, con todas las letras: «**solo el retiro, no el sello** — el sello es irreversible en este
teléfono y se lo comería quien reinstala su PROPIA app». Doce líneas más arriba, en
`performICloudCorpusWipe`, hice exactamente lo contrario: extendí el sellado a la celda sin filas locales,
que es **literalmente la reinstalación**, y de paso al aviso del espejo tardío, cuya población es la misma
persona por definición.

Lo cazaron **dos lentes por separado**, y la coincidencia es lo que lo hizo decisivo. La justificación que
yo me había dado era «el enum promete purga + sello y el guard incumplía su docblock»: cierta, y el
arreglo correcto no era cumplir la promesa sino **corregir la promesa** — el docblock del scope también
estaba mal.

**Lo que añade a la ficha, y es la forma más barata de cazarlo:** cuando en un diff escribo una frase del
tipo «aquí NO hago X porque X sería irreversible / dañino / ajeno», **esa frase es una regla, y hay que
aplicarla a los demás sitios del mismo diff, uno por uno, con su nombre**. `grep` del token que nombra
(aquí `groupsDomainSealedForFreshStart`) sobre el diff entero, y por cada acierto contestar «¿y aquí por
qué sí?».

Y el corolario sobre las promesas: **cuando el docblock de un tipo y el comportamiento de un call-site no
casan, no des por hecho que el equivocado es el call-site.** El docblock también es una premisa.
