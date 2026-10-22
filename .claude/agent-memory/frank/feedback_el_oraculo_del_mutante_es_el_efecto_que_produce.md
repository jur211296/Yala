---
name: el-oraculo-del-mutante-es-el-efecto-que-produce
description: Un mutante que SOBREVIVE no prueba que el código no corra — puede que el test mire una consecuencia que ese código no controla; instrumenta antes de concluir
metadata:
  type: feedback
---

Cuando un mutante sobrevive, la conclusión inmediata («entonces mi código no corre») es una hipótesis,
no una medición. Antes de tocar nada: **instrumenta el tramo mutado y mira si corre**. El mutante mide
lo que el ORÁCULO del test observa, y ese oráculo puede no ser el efecto que el código produce.

**Why:** el 2026-09-14, forzando la sonda de presentación a `false`, el XCUITest siguió en verde: el
aviso continuaba en pantalla a los 15 s, y la lectura natural era «la red no se está armando». Tres
`print` demostraron lo contrario — la red corría, agotaba sus nueve vueltas y apagaba los dos flags.
Lo que no ocurría era el efecto que yo estaba mirando: **UIKit no completaba el desmontaje del alert**,
así que el estado se apagaba y el dibujo se quedaba. Sin instrumentar habría «arreglado» una red que
funcionaba, persiguiendo un síntoma de UIKit.

**How to apply:**

- Antes de escribir un mutante, escribe qué efecto produce el código y comprueba que el test observa
  **ese** efecto. Si el código cambia ESTADO y el test mira PANTALLA, hay un eslabón (el framework) que
  puede romper la cadena sin que nada esté mal.
- Cuando el efecto no es observable desde el test, el control se monta por su CONSECUENCIA en otro
  sitio: aquí, encolar un paywall y mirar si presenta — eso sí depende de la matriz, que es lo que la
  red suelta. Con ese oráculo, el mismo mutante mató y el control positivo (sin red) reprodujo el brick.
- El corolario barato: un mutante que sobrevive y otro que muere sobre el MISMO código señalan al
  oráculo, no al código.

Relacionado: [[instrumentar-gana-a-razonar]], [[mis-mediciones-fallan-por-el-filtro]],
[[la-asercion-que-no-puede-fallar]].
