---
name: la-puerta-de-la-unidad-no-cubre-sus-peticiones
description: Una puerta «antes de cada página» no cubre los trozos de red DENTRO de la página; la app congelada entre dos trozos se salta la puerta.
metadata:
  type: feedback
---

Puse la puerta del lease «antes de CADA página, no de cada pasada» y lo escribí como cerrado. La review lo tumbó: una
página son 4+ peticiones de 50 filas (`SyncPushClient` trocea), y la app congelada entre dos trozos reanuda el siguiente sin
volver a preguntar. Mi propio Paso 0 prometía cubrir la suspensión y solo la cubría un nivel más arriba.

**Why:** el argumento «dentro de la unidad no puede pasar X» (60 min de silencio) es falso en cuanto la unidad tiene
esperas que el sistema puede congelar. Lo que la unidad hace por dentro no se ve desde el sitio donde pongo la puerta.

**How to apply:** al poner una puerta «antes de cada X», baja un nivel: ¿cuántas peticiones o escrituras hace X por
dentro, y hay un `await` entre ellas? Si lo hay, la condición se vuelve a mirar antes de cada una (barato: un reloj
local con otro margen, no otra petición). Relacionado: [[una-ventana-dura-lo-que-su-reintento]],
[[sustituir-un-latido-cambia-que-significa-el-lease]].
