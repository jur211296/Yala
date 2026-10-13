---
name: auditoria-ui-glass-se-queda-jerarquiza
description: Criterio de Jürgen para auditar UI en Yala — el glass se queda, se jerarquiza con contraste/rellenos/movimiento; instruir sin pasos extra; adaptar, no transformar; referencia Kargul; solo lo del lote
metadata:
  type: feedback
---

Al auditar la UI de Yala (auditoría UX 2.2, desde el lote 2):

1. **El liquid glass se queda.** El problema no es que haya glass sino que, si todo es glass, nada tiene foco.
   Se jerarquiza **sumando** contraste, rellenos, acentos de color, efectos, animaciones y transiciones. Lo
   elegido va **relleno de color**, no solo con contorno.
2. **La persona siempre se siente instruida, sin pasos adicionales, y nunca perdida**: microcopy, ejemplos y
   ayuda contextual dentro de la misma pantalla. Si no entiende qué pasa, deja la app.
3. **Adaptar la app, no transformarla.** Se mejora lo que hay; no se rediseña la pantalla entera.
4. **Referencia principal: `~/Claude/referencias-ui/kargul-2026-10-07/`** (la que más le gusta): fichas con
   color sólido e icono blanco, filtros elegidos rellenos, barras con degradado y brillo, píldoras de
   tendencia, tarjeta lateral que explica qué va a pasar.
5. **Solo lo del lote.** «Si tu lote no tiene calculadoras, no es tuyo»: lo que se ve de otro lote va a su
   card, no a esta sesión.

**Why:** 2026-10-13, lote 2, Jürgen amplió el encargo a mitad de sesión y lo corrigió dos veces: primero pidió
«menos liquid glass», luego precisó que el glass se queda y que lo que falta es jerarquía; y cuando empecé a
capturar las calculadoras del onboarding y de cuentas, me cortó.

**How to apply:** cada propuesta UI lleva captura antes, maqueta después renderizada en el simulador (parche
que no se commitea), A/B/C con recomendación y card en espera de decisión. Si la propuesta quita glass o cambia
la estructura de la pantalla, no es la recomendada. Relacionado: [[auditoria-ux-lote-propone-no-implementa]],
[[tarjetas-blancas-identidad]].
