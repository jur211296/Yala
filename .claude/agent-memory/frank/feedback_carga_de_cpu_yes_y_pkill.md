---
name: carga-de-cpu-yes-y-pkill
description: Cargar la CPU con `yes` para reproducir un rojo del CI no lo reprodujo, y matar los `yes` con una variable de PIDs en zsh no mata nada
metadata:
  type: feedback
---

Para simular el runner lento del CI cargué los 10 núcleos con `yes > /dev/null` y repetí el XCUITest del formulario a
medias: 0 rojos de 8 (2026-11-01). Y el `kill $PIDS` del final falló en silencio («illegal pid»): zsh no parte la
variable, así que los `yes` siguieron vivos hasta que lo vi en el `uptime`.

**Why:** dejar diez `yes` corriendo carga la Mini para todas las sesiones y para el gate siguiente.

**How to apply:** si vuelvo a cargar la CPU, limpio con `pkill -x yes` y lo compruebo con `pgrep -x yes`. Y no lo uso
como reproductor de rojos «solo del CI» de presentación: el que sí lo reprodujo fue una corrida normal justo después de
la suite unitaria. Ver [[project-5xj4-espera-la-nocturna-con-marcador]].
