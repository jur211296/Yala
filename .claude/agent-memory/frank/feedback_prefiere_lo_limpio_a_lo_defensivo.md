---
name: prefiere-lo-limpio-a-lo-defensivo
description: Ante un mecanismo que falla, Jürgen retira y sustituye antes que apuntalar; la opción "cinturón y tirantes" la descarta aunque venga recomendada
metadata:
  type: feedback
---

**Cuando algo no funciona, prefiere quitarlo y poner otra cosa, no envolverlo en salvaguardas.**

**Why:** medido el 2026-09-03 con el paso de zona horaria del CI. Le presenté cuatro opciones con
su consecuencia escrita y **recomendé la defensiva** —dejar `systemsetup` como no-bloqueante Y
añadir `TEST_RUNNER_TZ` como red, que conservaba una propiedad de su propia decisión del día
anterior—. Eligió **«Solo TEST_RUNNER_TZ»**: fuera el mecanismo viejo entero, aunque eso le costara
la propiedad que él mismo había argumentado 24 h antes («fijar la zona del sistema prueba además
que el algoritmo no depende del entorno»).

El patrón no es tozudez con su decisión previa: es lo contrario. **Un argumento suyo de ayer no le
ata si la medición de hoy lo desmiente.** Lo que descarta es el apaño que convive con lo roto.

**How to apply:**

- Al ofrecerle opciones para un mecanismo que falla, **incluye siempre la de retirarlo del todo** y
  dale su coste real. Es la que suele elegir.
- **No marques como recomendada la opción defensiva por prudencia.** Aquí la marqué así y la
  descartó — es la tercera vez que se aparta de mi recomendación (ver [[decisiones-que-esperan-a-jurgen]],
  3 de 8). Marcar la recomendación le sigue ahorrando tiempo; darla por tomada, no.
- **Nombra qué se pierde al limpiar.** Aceptó perder la propiedad del entorno porque se lo puse
  delante como precio explícito, no porque no le importara. Escamotearlo habría sido peor que
  recomendarlo mal.
- Corolario del mismo día: cuando el trabajo ya está medido, delega el resto («commit y push cuando
  consideres»). La medición es lo que compra la autonomía, no la insistencia.

Relacionado: [[jurgen-levanta-sus-reglas]] · [[el-tablero-antes-que-el-bug]] · [[mis-mediciones-fallan-por-el-filtro]]

**Tercer caso el mismo día, y ya no es una preferencia de mecanismo: es de ALCANCE.** El
2026-09-04, con el fix de identidad de miembro en Grupos, le ofrecí cuatro opciones y recomendé la
mínima —un getter aparte que alimentara solo los dos banners de estado, sin tocar un permiso—.
Eligió **«los cinco resolvedores»**: alinear también los gates de escritura del servicio, que es el
camino donde un bug sale más caro. Antes, ese mismo día, había elegido dos veces más lo definitivo
sobre lo prudente (retirar `systemsetup` en vez de apuntalarlo; el orden 3→1→2 completo en vez de
parar en lo que más rojo quitaba).

**Why:** las tres veces el argumento de mi recomendación era el riesgo, y las tres lo aceptó a
cambio de que la cosa quede coherente. Lo que NO tolera es la mitad: un fix que arregla el síntoma
y deja la app diciendo dos cosas distintas según la pantalla.

**How to apply:**
- **Ofrece la opción completa aunque la descartes en la recomendación**, y dale su coste real. Es
  la que suele elegir, así que omitirla le quita la decisión.
- **La recomendación mínima sigue valiendo la pena escribirla**: es lo que hace que compare. Pero
  cuenta con que en trabajo de coherencia estructural elija la grande.
- **Y entonces el listón sube, no baja.** Al elegir la completa aceptó tocar los gates de permisos:
  eso es exactamente donde la review adversarial dejó de ser un trámite —cazó una auto-expulsión
  que yo habría commiteado— y donde el alcance mínimo no la habría necesitado. Si elige la grande,
  la review adversarial deja de ser opcional.
