---
name: un-plazo-nuevo-se-clava-con-sus-dos-vecinos
description: Un número de tiempo nuevo necesita un caso en cada lado de su borde y un argumento de por qué ESE número — sin eso, el mutante que lo cambia sobrevive y los dos lados tienen daño distinto
metadata:
  type: feedback
---

Al introducir un plazo (frescura, gracia, timeout), **clávalo con sus dos vecinos** —un caso justo
dentro y otro justo fuera— y escribe **de dónde sale el número**. Sin las dos cosas, el mutante que
lo cambia sobrevive a la suite entera.

**Why:** el 2026-09-21 metí una frescura de 60 s en el testigo del re-ancla del restore y **ningún
test la consultaba**: el único caso que la rozaba pasaba por un early-return anterior, así que el
mutante `freshness = 600` quedaba verde. Lo cazó una lente de la review, y el número además era
**falso**: con 60 s, un error de import retriable —«un restore grande con la red floja», que el
propio repo llama el caso NORMAL— dejaba el estado en `.idle` mientras CloudKit reintentaba con un
backoff de minutos, y esa población perdía el re-ancla. O sea, el bug del ticket hermano.

Lo que hace defendible el 600 final no es que funcione: es que **es el mismo `hardCap` de la ventana
que el re-ancla concede**. Más allá de él, lo que se concedería ya habría caducado por su cuenta. Un
número con simetría se discute; uno elegido a ojo se cambia sin que nadie se entere.

**How to apply:**

- **Dos casos, no uno**: justo dentro (599 → sí) y justo fuera (600 → no). Con un solo punto medido
  a 1200 y otro a 30, cualquier valor intermedio sobrevive.
- **Escribe qué duele en CADA lado.** Aquí subirlo devuelve el latch monótono y bajarlo reabre el
  ticket hermano: los dos lados tienen daño y por eso el número se fija por los dos.
- **Deriva el número de otro que ya exista en el diseño** (un tope duro, una gracia, un timeout) y
  dilo en el docblock. Si no hay de dónde derivarlo, sospecha de la decisión, no del número.
- **Y comprueba que la vista no lo pueda cablear.** Mi source-scan del call-site fijaba dos
  argumentos y dejaba libres `now:` y `freshness:`: pasar `freshness: 86_400` desde la vista
  desarmaba el arreglo con toda la tabla en verde. El escáner tiene que prohibir el parámetro, no
  solo exigir los crudos.

Relacionado: [[un-numero-sustituto-lo-cumple-otra-cosa]], [[la-asercion-que-no-puede-fallar]],
[[el-mutante-que-sobrevive-puede-sobrar]], [[el-denominador-de-una-resta-es-el-numero-que-se-ve]].
