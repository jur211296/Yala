---
name: feedback-sentry-dev-cuadra-con-las-sesiones
description: Un issue de Sentry del entorno development en simulador se cuadra por minuto con las sesiones de esa hora antes de buscar el bug en la app
metadata:
  type: feedback
---

Antes de buscar en la app un issue `environment: development` con `build_type: simulator`, cruza sus marcas de tiempo
con `git log origin/2.2` de esa franja y con la ruta del binario (`Yala.debug.dylib` + UDID del simulador) que trae el
evento.

**Why:** YALA-IOS-3/4 (2026-11-03) parecían caídas de arranque de la app; eran 12 relanzamientos de las previews de
otra sesión (cada ~6–12 s) y el commit de esa sesión ya nombraba el error. Las previews corren la app de desarrollo con
Sentry encendido (cerrado en #760). El binario Debug sí tendría símbolos, pero el simulador ya no existía.

**How to apply:** si el ritmo es «un evento cada pocos segundos durante minutos, ~1 s tras arrancar», piensa en
previews o en un bucle de lanzamientos de otra sesión. Y si el binario Debug aún existe, simboliza con él antes de que
se borre el simulador. Relacionado: [[feedback-sentry-vacio-no-descarta-un-crash]], [[reference-sentry-tokens-y-api]].
