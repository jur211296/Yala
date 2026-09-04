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
