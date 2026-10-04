# Mejorar las cards de registros nuevos en Yala AI

## Contexto
Cola 2.1 domingo/noche (Jürgen 2026-10-03 ~23:05): tras hero Estadísticas (PR #346 en auto-merge) toca diseño de cards de registros nuevos en Yala AI, antes de dictado/voz/imagen/vistas en grupos y del barrido QA del lunes. No es 2.2 (revisión de modelos, partir nube/privado, mascota, etc.).

Card tablero: tablero-mejorar-cards-de-registros-nuevos-en-yal-rdfd (asignada a Frank).
Nota del card: rediseño de las cards que Yala AI muestra al proponer un registro nuevo, y más funciones en esa card (editar antes de guardar, descartar, detallar). Si el diseño no está cerrado, la sesión deja propuestas y espera a Jürgen. No inventar el diseño final.

## Qué se pide
Mejorar el diseño/UX de las cards que muestran registros nuevos creados/propuestos desde Yala AI. Incluye claridad visual coherente con el DS y, si el camino es claro, funciones en la card: editar antes de guardar, descartar, detallar. Implementa si el camino es claro; si hay UI/UX sin decidir, deja propuestas concretas (2–3 opciones con recomendada) y PARA — no inventes el diseño final ni asumas preferencias de Jürgen.

## Qué NO hay que tocar
- No cambiar modelo/proveedor de IA.
- No partir nube/privado ni revisión de coste de modelos.
- No dictado, registro por voz, por imagen, ni vistas en grupos (van después).
- No mergear a 2.1 a mano si el flujo normal es PR + auto-merge.

## Cómo se sabe que está bien
Cards de registros nuevos en Yala AI más claras y coherentes con el DS; capturas antes/después en capturas/ si el cambio se ve; PR a 2.1. Si quedó a la espera de decisión de diseño, el cierre parcial lista las propuestas y qué falta.

/cerrar-total

## Paso 0 — decisiones

> Resueltas en autónomo (bypass, 00:50 Lima — fuera del horario de preguntar): las recomendaciones se dan por buenas. Se discuten en el PR.

**Hechos medidos antes de decidir.** La card vive en `Yala/App/Views/Chat/ChatTransactionDraftCard.swift` (570 líneas). **Ya tiene las tres funciones que pide la nota del tablero**: editar en línea (monto, cuenta, subcategoría, fecha, etiquetas, nota), «Descartar» y «Editar», que cierra el chat y abre el formulario completo (= detallar). Lo que falta es diseño, no funciones. El onboarding de Yala IA tiene una copia decorativa (`ChatDraftPreviewCard`) que «replica el layout» de la real. En el simulador Yala IA responde «no disponible», así que sin un hook no hay card que capturar.

**D1 · ¿Implemento el rediseño o propongo?** → Propongo y paro. 3 propuestas en un lienzo, con los mismos datos, más el estado actual; una recomendada.
Por qué: el encargo y la nota del tablero lo piden si el diseño no está cerrado, y no lo está (nadie ha dicho cómo debe verse). Alternativa descartada: construir mi interpretación — la memoria de Jürgen dice que en UI sin diseño quiere elegir entre propuestas.

**D2 · ¿Funciones nuevas en la card?** → Ninguna. Las tres pedidas existen; las propuestas solo cambian dónde y cómo se ofrecen (p. ej. «Editar» que hoy saca del chat).
Por qué: inventar funciones sería producto sin decidir. Alternativa descartada: añadir «duplicar» o «dividir» — nadie lo pidió.

**D3 · ¿Hook de test para la card?** → Sí: `-uitest-chat-draft`, solo DEBUG, siembra en `setContext` un mensaje del asistente con dos borradores (uno completo, uno sin subcategoría) contra los datos sembrados. No persiste.
Por qué: sin él no hay captura del antes ni del después, y quien implemente la propuesta elegida lo necesitará para sus XCUITest. Alternativa descartada: capturar desde el onboarding — es una copia decorativa, no la card real.

**D4 · ¿Qué entra en el PR?** → El hook + un ticket de backlog con las tres propuestas y el enlace al lienzo + la captura del antes. Sin «después»: el aspecto no cambia en este PR.
Por qué: el hook es código y necesita gate y PR; el ticket deja la decisión donde Jürgen la encuentra. Alternativa descartada: PR solo de docs — el hook se perdería.
