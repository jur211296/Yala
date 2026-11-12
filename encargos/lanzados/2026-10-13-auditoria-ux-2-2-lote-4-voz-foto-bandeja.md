# Auditoría UX 2.2 · lote 4: voz, foto, compartir y la Bandeja

> **ALCANCE ESTRICTO:** solo los 9 flujos del lote 4. Los criterios UX/UI se aplican solo a sus pantallas. Si ves algo fuera, anótalo en una línea en el informe y no lo toques.

Card: tablero-auditoria-ux-2-2-lote-4-voz-foto-compart-frwk (Yala, 2.2, high). Card madre ogl6: no la muevas.

**Base y PR: 2.2.** `lanzar-sesion` ignora --base: Frank ya te deja sobre origin/2.2; ANTES de tu primer commit, `git fetch origin && git log origin/2.2..HEAD` debe salir vacío. PR contra **2.2**.

## Fuentes
- Brief madre (método, cinco lentes, formato de informe, HTML acumulado y «Criterios UX/UI permanentes de Jürgen»): ~/Claude/tmp-frank/auditoria-ux-flujos-2-2.md. Léelo entero.
- Mapa: docs/ux/mapa-de-flujos-2.2.md (sección lote 4).
- Lotes anteriores como ejemplo: ~/Claude/entregas/Yala--auditoria-ux-2-2-lote-3-panel/informe.md y ~/Claude/propuestas/auditoria-ux-2.2/auditoria-ux-2.2.html.
- Referencia visual: ~/Claude/referencias-ui/kargul-2026-10-07/.

## Lote 4 (9 flujos)
Dictar un gasto; foto/recibo/PDF; compartir capturas desde otra app; soltar un recibo en iPad; revisar la Bandeja; aprobar o eliminar deslizando; aprobar varios; pagos planificados vencidos en la Bandeja; recuperar un borrador archivado. Para la voz y la IA en el simulador usa los hooks de QA/semillas existentes (no hay respuesta real de la IA en el simulador).

## Qué hacer
1. Recorre cada flujo en el simulador; capturas en ~/Claude/entregas/<sesión>/capturas/.
2. Informe en español (entregas/<sesión>/informe.md): mejoras numeradas L4-1, L4-2…; por cada una: problema, tipo de usuario, captura, opciones A/B/C y recomendación. Añade la sección del lote 4 al HTML acumulado sin borrar nada.
3. No implementes cambios de UX: solo propone. Arregla únicamente bugs claros, cada uno con su card (Yala, 2.2, frank), en un PR a 2.2 con antes/después.
4. Una card en espera decisión (Yala, 2.2, assignee jurgen) por cada mejora, con sus opciones.

## Elecciones de UI: variantes y esperar
Si alguna mejora es una elección visual, construye ~/Claude/propuestas/auditoria-ux-2.2/variantes-L4.html: autocontenida (imágenes en base64), pestañas o rejilla, **2–3 variantes claramente distintas lado a lado** por item más el «antes», hechas con maquetas reales en el simulador. Entonces:
- `xcrun simctl shutdown all`;
- avisa con `python3 ~/.claude/hooks/avisar_grok.py --avisar cierre-resumen --texto "Lote 4: variantes listas para elegir: <ruta del HTML> · PR: <url si hay>"`;
- **NO ejecutes /cerrar-total. Quédate viva** esperando la elección de Jürgen (llegará por decirle). No borres el worktree.
Si no hay ninguna elección de UI, cierra normal con /cerrar-total.

## Reglas duras de UI
- NADA de degradados, NADA de glows/brillos, NADA de contraste en blanco sólido.
- El botón «Siguiente» NO se toca.
- El liquid glass se queda.
- Copy nueva en los 16 idiomas (es-AR con voseo).

## Cómo
- Pipeline serie en la Mini: `nice -n 10 xcodebuild -jobs 2`, como máximo 1 simulador, `xcrun simctl shutdown all` al terminar.
- Tests de lo que arregles con -only-testing y /gate.

## Reglas
Totalmente autónomo: nunca AskUserQuestion ni preguntas, decide tú. Sin deploy.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Qué cuenta como «bug claro» que se arregla en el PR?** → Lo que contradice a la propia app sin decisión de diseño: plurales rotos («1 pendientes», «listo(s)», «y … y»), textos en inglés en otros idiomas, VoiceOver leyendo el enum crudo, Archivados vacío tras rechazar hasta reabrir, y una pista que nombra un botón que no existe.
Por qué: ninguno pide elegir entre opciones; hay una sola respuesta correcta. Alternativa descartada: arreglar también el deslizar que borra sin confirmar — eso es elegir qué hace el gesto, va a card.

**D2 · Plurales: ¿`.stringsdict` o lógica en Swift?** → `.stringsdict` en los 10 idiomas base y forma plana «other» en las 4 variantes, el contrato que ya fija `LocalizationParityTests`.
Por qué: es como el repo hace los plurales. Alternativa descartada: `if count == 1` en Swift, que no sirve para polaco.

**D3 · El conector «y» del aviso** → se quita la clave y la lista la une `ListFormatter` con `AppLocale.current`.
Por qué: un conector fijo produce «A y B y C» con tres partes. Alternativa descartada: añadir una clave «, » (no sabe del orden ni de la coma final del inglés).

**D4 · La pista «Toca Seleccionar…»** → la pista pasa a nombrar el ✓ («Toca ✓ para elegir varios a la vez») y VoiceOver llama al ✓ «Seleccionar» en vez de «Aprobar todo».
Por qué: es lo mínimo que deja la pantalla diciendo la verdad sin tocar la UI. Rediseñar «aprobar varios» va a card (L4-7). Alternativa descartada: volver a un botón de texto «Seleccionar», que cambia la barra.

**D5 · El pago planificado vencido (4.8) no se pudo recorrer en el simulador** → se documenta por código y se anota el hueco de cobertura; no se añade un hook nuevo en este lote.
Por qué: bajo `-uitest` el arranque no procesa vencidos y volver a primer plano tampoco creó el borrador; añadir el hook es trabajo de QA, no de auditoría. Alternativa descartada: depurar el procesado en esta sesión.

**D6 · Elecciones visuales** → tres mejoras llevan variantes en el simulador (L4-1 botones de voz/foto, L4-5 cabecera del editor, L4-13 pantallas de éxito), con un parche de maqueta que no se commitea.
Por qué: son las tres donde la decisión es de aspecto; el resto se decide leyendo opciones.
