---
name: push-solo-lo-de-la-sesion
description: Se pushea únicamente lo que produjo esta sesión; lo que encuentres pendiente de otros se deja para el agente que lo hizo
metadata:
  type: feedback
---

Se pushea **solo lo de la sesión**. Si al llegar hay commits pendientes de otro
—otra sesión, otro agente, un `2.1` por delante del remoto— **se dejan**, se
avisa, y los sube quien los hizo. Nunca los arrastres en tu push «ya que estás».

**Why:** Jürgen lo fijó el 2026-08-31. Cada agente responde de lo que empujó; un
push que arrastra trabajo ajeno mezcla autorías y mete en el remoto cambios que
nadie verificó en esta sesión.

**How to apply:** al arrancar, el volcado del hook suele decir «hay N commits sin
pushear» — eso es información, no una tarea. Contrástalo (`git fetch` primero: el
volcado puede estar desfasado) y menciónalo en el briefing sin actuar.

Corolario para el hook de secretos: escanea **todo lo trackeado** del repo, no el
rango que vas a empujar, así que te bloquea por ficheros que ya están en el
remoto y que tu rama ni toca. Ver [[hook-secretos-disparador-substring]].
