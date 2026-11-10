---
name: diff-de-pixeles-en-la-misma-sesion
description: Un diff de píxeles antes/después solo vale con las dos versiones capturadas seguidas, en el mismo estado del simulador; el cristal cambia con Reducir movimiento
metadata:
  type: feedback
---

Captura el «antes» y el «después» uno detrás del otro, con el mismo estado del simulador, y prueba antes que dos
corridas del MISMO build dan 0 píxeles.

**Why:** el 2026-11-09 (lote de cierre 2.2) salieron ~990 píxeles distintos en la barra de pestañas de cristal entre un
«antes» de hacía una hora y el «después». Era el entorno: entre medias activé Reducir movimiento (para parar el latido
del menú del +) y el Liquid Glass pinta distinto lo de debajo. Recapturado el antes en ese momento: 0. Y un scroll con
inercia (`axe swipe` rápido) deja la lista en otra posición cada vez: no sirve para comparar.

**How to apply:** pantalla sin scroll o arrastre lento (`--duration 3`, sin inercia); control de dos corridas del mismo
build; el antes desde su propio derivedData, reinstalado justo antes. Lo que tiene animación perpetua (el `phaseAnimator`
del menú del +) necesita Reducir movimiento en los DOS.

Relacionado: [[antes-del-iphone-con-git-archive]].
