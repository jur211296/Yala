---
name: sesion-de-rediseno
description: Cómo funcionó la sesión de rediseño del 9-sep (Jürgen dicta, yo mido cada afirmación y anoto; cierre = ADR + tickets + descartes) y qué hacer cuando dice «asume que lo desplegué»
metadata:
  type: feedback
---

**Cuando un device-QA se convierte en conversación de producto, se sigue la conversación y el cierre
es documental: ADR + tickets bien especificados + board limpio.** No se parchea sobre la marcha.

**Why:** el 9-sep Jürgen abrió con un device-QA, a la segunda respuesta ya estaba rediseñando el
modelo de sesiones, y lo ratificó explícitamente: «la sesión ha sido de rediseño y eso está
perfecto. Lo que espero es documentar todo perfecto, crear los tickets y dejar el camino limpio
para lanzar sesiones autónomas». Lo que valoró: que cada afirmación suya se contrastara con una
medición antes de contestar (curl a prod, greps con línea), que la lista de «qué más se nos escapa»
fuera contable (19 vistas, 32 strings) y no intuida, y que mis opiniones fueran firmes y marcadas
como mías (desasociar, «pública» vs «en la nube», una sesión conmutable en vez de un selector).

**How to apply:**
- Un documento de sesión en `docs/sessions/` como acta viva mientras dicta; al cerrar, lo dictado se
  consolida en `docs/DECISIONS.md` y el acta se congela.
- **Cada punto del ADR = un ticket** con: síntoma en lenguaje de usuario, lo medido con `fichero:línea`
  del árbol, alcance, AC verificables, cómo se prueba (unit / XCUITest / device), depende de. Y el
  **orden de implementación** con dependencias reales, dentro del ADR.
- Releer los tickets del área contra el modelo nuevo y **descartar** los que no encajan, con el ADR
  como motivo en la línea `Why:`; la consecuencia que él no dictó palabra por palabra se marca como
  «ratificación pendiente», no se esconde ni se omite.
- «Asume que lo desplegué» → **mido igual, en 30 s, antes de reescribir** (curl al `/config`); si
  coincide, se lo confirmo como medido; si no, lo sabe antes de la pantalla. No le molestó: le sirvió.
- Lo que Apple obliga (5.1.1 v, borrado de cuenta) se dice aunque contradiga lo que acaba de pedir.
