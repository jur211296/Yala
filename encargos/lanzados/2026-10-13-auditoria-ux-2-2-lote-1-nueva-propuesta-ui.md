# Auditoría UX 2.2 · lote 1: nueva propuesta UI sin gradientes ni glows

> **ALCANCE ESTRICTO:** solo el lote 1 (primera vez / onboarding). Si ves algo fuera del lote, anótalo en una línea en el informe y no lo toques.

Card: tablero-auditoria-ux-2-2-lote-1-nueva-propuesta-wqmy (Yala, 2.2). Base y PR: **2.2**.

## Contexto
Jürgen aceptó la opción recomendada de las 8 propuestas L1UI-1…8 (cards en espera decisión; informe en ~/Claude/entregas/Yala--auditoria-ux-2-2-lote-1-pasada-ui/ y sección L1UI del HTML acumulado), pero RECHAZÓ el diseño anterior: botones con degradado de color (se ve hecho con IA) y un glow alrededor de «Siguiente».

## Qué hacer
- Maquetas NUEVAS marcadas PROPUESTA para L1UI-1…8, en el simulador o como mock, con captura antes/después.
- El foco sale de contraste, rellenos sólidos, tipografía, efectos sutiles y transiciones. El liquid glass se queda.
- Referencia principal: ~/Claude/referencias-ui/kargul-2026-10-07/.
- PROHIBIDO: degradados, glows o brillos. El botón «Siguiente» NO se toca.
- Solo maquetas: no implementes nada en la app.
- Añade la sección «Lote 1 · nueva propuesta UI (sin degradados ni glows)» a ~/Claude/propuestas/auditoria-ux-2.2/auditoria-ux-2.2.html sin borrar nada, y actualiza cada card L1UI-n con la nueva maqueta.
- Si hay cambios de repo (docs), PR contra 2.2.

## Reglas
Totalmente autónomo: nunca AskUserQuestion ni preguntas, decide tú. Como máximo 1 simulador; `xcrun simctl shutdown all` al terminar. Cierra con /cerrar-total.
