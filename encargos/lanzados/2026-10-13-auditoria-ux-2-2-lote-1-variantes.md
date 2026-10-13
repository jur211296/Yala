# Auditoría UX 2.2 · lote 1: 2-3 variantes UI lado a lado para elegir

> **ALCANCE ESTRICTO:** solo el lote 1 (primera vez / onboarding). Si ves algo fuera del lote, anótalo en una línea y no lo toques.

> **CRÍTICO: NO ejecutes /cerrar-total.** Cuando el HTML esté listo: `xcrun simctl shutdown all`, avisa con
> `python3 ~/.claude/hooks/avisar_grok.py --avisar cierre-resumen --texto "Variantes L1UI listas para elegir: <ruta del HTML>"`
> y QUÉDATE VIVA esperando la elección de Jürgen (te llegará por decirle). No cierres, no borres el worktree.

Card: tablero-auditoria-ux-2-2-lote-1-2-3-variantes-ui-g9r7 (Yala, 2.2). Base y PR: **2.2**.

## Contexto
Jürgen aceptó la opción recomendada de las 8 propuestas L1UI-1…8 (cards en espera decisión), pero rechazó dos diseños:
1. degradados con glow (se ve hecho con IA) — PR #485;
2. contraste en blanco sólido — PR #488 (~/Claude/entregas/Yala--auditoria-ux-2-2-lote-1-nueva-propuesta-ui/).

## Qué hacer
- Una página HTML interactiva, autocontenida (imágenes en base64) y fácil de abrir (también en el móvil), con pestañas o rejilla: por cada L1UI-1…8, **2 o 3 variantes claramente distintas lado a lado**, más el «antes». Ejemplos de familias: rosa de marca como acento; tonos oscuros o tintes sobre el glass; cambios mínimos.
- Cada variante sale de una maqueta REAL en el simulador (rama de maqueta, no se mergea) y lleva una línea que explica qué cambia.
- PROHIBIDO: degradados, glows/brillos, contraste en blanco sólido. «Siguiente» NO se toca. El liquid glass se queda.
- Referencia: ~/Claude/referencias-ui/kargul-2026-10-07/.
- Solo maquetas: nada se implementa en la app.
- Guarda el HTML en ~/Claude/propuestas/auditoria-ux-2.2/variantes-L1UI.html y enlázalo como sección nueva del HTML acumulado auditoria-ux-2.2.html (sin borrar nada).

## Reglas
Totalmente autónomo: nunca AskUserQuestion ni preguntas hasta tener el HTML. Como máximo 1 simulador, apagado al terminar. Tras la elección de Jürgen, sigue sus instrucciones (podrán incluir implementar la variante elegida en un PR a 2.2).
