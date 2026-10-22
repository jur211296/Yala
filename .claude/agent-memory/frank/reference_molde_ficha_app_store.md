---
name: molde-ficha-app-store
description: Capturas y vídeo de la App Store por idioma salen del molde ficha-app-store/ (reloj falso al 13-oct, simulador borrado por corrida); lo que se intentó y no funcionó para la barra del iPad y el Panel
metadata:
  type: reference
---

Las capturas (iPhone 6,9/6,5, iPad 13) y la vista previa de la ficha salen de **`ficha-app-store/`** en el repo, con
un solo parámetro de idioma. Su README trae la corrida y las trampas; esto es lo que NO está ahí y costó probar.

- **Las cifras de un día concreto se clavan con un reloj falso, no con la semilla**: un dylib inyectado con
  `SIMCTL_CHILD_DYLD_INSERT_LIBRARIES` que desplaza `gettimeofday`/`clock_gettime`/`CFAbsoluteTimeGetCurrent`. Con la
  app en el 13-oct-2026, `realista` dio al dígito el set en español («19 días», 1,330 de 1,800). Vale para cualquier
  captura o demo que cite fechas relativas.
- **Barra del iPad, intentado y descartado**: `status_bar --time` con fecha ISO (solo acepta `…T…:00.000Z`) la escribe
  en inglés en cualquier idioma y, tras relanzar la app, con el día de la semana de hoy. Ni `clear` antes ni
  reaplicarla lo cura. Se queda solo la hora.
- **Panel con todas las secciones al relanzar sin `-uitest-reset`**: probado `simctl erase` (no lo cura) y mandar la
  app al fondo antes de matarla (azar, 1 de 2). Lo que funcionó 3 de 3: el Panel por argumentos de arranque. Ticket
  `uitest-relaunch-without-reset-can-lose-the-new-user-panel`.
- **Para conducir el iPad**, `axe tap` sobre el centro de un elemento de carrusel que asoma por el borde toca fuera:
  hay que tocar la parte visible (`tocar_linea` del molde).

Relacionado: [[conducir-simulador-con-axe]], [[el-video-del-simulador-salta-pantallas-cortas]],
[[simulador-preferencias-fuera-del-contenedor]].
