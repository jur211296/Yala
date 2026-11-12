# Auditoría UX 2.2 · lote 5: primeros días, guías y tips

> **ALCANCE ESTRICTO:** solo los 12 flujos del lote 5. Los criterios UX/UI se aplican solo a sus pantallas. Si ves algo fuera, anótalo en una línea en el informe y no lo toques.

Card: tablero-auditoria-ux-2-2-lote-5-primeros-dias-gu-k4gd (Yala, 2.2, high). Card madre ogl6: no la muevas.

**Base y PR: 2.2.** `lanzar-sesion` ignora --base: Frank ya te deja sobre origin/2.2; ANTES de tu primer commit, `git fetch origin && git log origin/2.2..HEAD` debe salir vacío. PR contra **2.2**.

## Fuentes
- Brief madre (método, cinco lentes, formato de informe, HTML acumulado y «Criterios UX/UI permanentes de Jürgen»): ~/Claude/tmp-frank/auditoria-ux-flujos-2-2.md. Léelo entero.
- Mapa: docs/ux/mapa-de-flujos-2.2.md (sección lote 5).
- Lotes anteriores como ejemplo: ~/Claude/entregas/Yala--auditoria-ux-2-2-lote-4-voz-foto-bandeja/informe.md y ~/Claude/propuestas/auditoria-ux-2.2/auditoria-ux-2.2.html.
- Referencia visual: ~/Claude/referencias-ui/kargul-2026-10-07/.

## Lote 5 (12 flujos)
«Primeros pasos» del Panel; gasto de práctica; banners de guía; guía sombreada de Ajustes; omitir un tip; tour Pro; globos de TipKit; guías del flujo de caja; permiso de notificaciones tras el tercer registro; hito de registros; pedir reseña; Novedades. Ojo: el PR #485 (L1-12) ya cambió cuándo sale la oferta Pro (tras el primer registro y al completar «Primeros pasos»); revisa sobre eso, no lo deshagas.

## Qué hacer
1. Recorre cada flujo en el simulador; capturas en ~/Claude/entregas/<sesión>/capturas/.
2. Informe en español (entregas/<sesión>/informe.md): mejoras numeradas L5-1, L5-2…; por cada una: problema, tipo de usuario, captura, opciones A/B/C y recomendación. Añade la sección del lote 5 al HTML acumulado sin borrar nada.
3. No implementes cambios de UX: solo propone. Arregla únicamente bugs claros, cada uno con su card (Yala, 2.2, frank), en un PR a 2.2 con antes/después.
4. Una card en espera decisión (Yala, 2.2, assignee jurgen) por cada mejora, con sus opciones.

## Elecciones de UI: variantes y esperar
Si alguna mejora es una elección visual, construye ~/Claude/propuestas/auditoria-ux-2.2/variantes-L5.html: autocontenida (imágenes en base64), pestañas o rejilla, **2–3 variantes claramente distintas lado a lado** por item más el «antes», hechas con maquetas reales en el simulador. Entonces:
- `xcrun simctl shutdown all`;
- avisa con `python3 ~/.claude/hooks/avisar_grok.py --avisar cierre-resumen --texto "Lote 5: variantes listas para elegir: <ruta del HTML> · PR: <url si hay>"`;
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

## Paso 0

Decisiones tomadas (modo autónomo, sin preguntas):

- **Rama y PR:** `encargo/2026-10-14-…` sobre `origin/2.2` (medido: `git log origin/2.2..HEAD` vacío). PR contra `2.2`.
- **Qué se arregla:** solo bugs claros medidos en el simulador o en el código, cada uno con su card. Todo lo demás es mejora con A/B/C y card en espera de decisión (Jürgen, 13-oct: «no implementes UX»).
- **Scheme:** `Yala Dev` (config Debug, bundle `com.jurgenschmidt.yala`), sin `-uitest`: los tips, banners y «Primeros pasos» se ocultan bajo `-uitest`. Los estados (registros guardados, fechas) se fuerzan escribiendo las preferencias de la app con la app parada.
- **Lo que el simulador no puede:** suscribirse de verdad (tour Pro) ni ver las Novedades (la 2.1 no tiene entrada). Se ven con una maqueta local que no se commitea.
- **Variantes visuales:** las elecciones de aspecto van a `variantes-L5.html` y la sesión se queda viva esperando la elección (encargo).
- **Disco:** 11 GB libres al empezar (umbral 25). Un simulador, sin `erase` de iPads; la caché de símbolos que se intentó borrar la denegó el clasificador.
