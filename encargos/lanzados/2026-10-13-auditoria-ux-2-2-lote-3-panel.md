# Auditoría UX 2.2 · lote 3: el Panel, cómo voy

> **ALCANCE ESTRICTO:** solo los 12 flujos del lote 3. Los criterios UX/UI se aplican solo a sus pantallas. Si ves algo fuera, anótalo en una línea en el informe y no lo toques.

Card: tablero-auditoria-ux-2-2-lote-3-el-panel-como-vo-znm3 (Yala, 2.2, high). Card madre ogl6: no la muevas.

**Base y PR: 2.2.** `lanzar-sesion` ignora --base: Frank ya te deja sobre origin/2.2; ANTES de tu primer commit, `git fetch origin && git log origin/2.2..HEAD` debe salir vacío. PR contra **2.2**.

## Fuentes
- Brief madre (método, cinco lentes, formato de informe, HTML acumulado y «Criterios UX/UI permanentes de Jürgen»): ~/Claude/tmp-frank/auditoria-ux-flujos-2-2.md. Léelo entero.
- Mapa: docs/ux/mapa-de-flujos-2.2.md (sección lote 3).
- Lotes anteriores como ejemplo: ~/Claude/entregas/Yala--auditoria-ux-2-2-lote-2-apuntar-a-mano/informe.md y ~/Claude/propuestas/auditoria-ux-2.2/auditoria-ux-2.2.html.
- Referencia visual: ~/Claude/referencias-ui/kargul-2026-10-07/.
- Ticket ya abierto en este lote: tickets/backlog/first-panel-says-available-zero-next-to-the-opening-balance.md.

## Lote 3 (12 flujos)
Ver el mes; solo ingresos o gastos; período; filtrar; ordenar secciones; «?» de los widgets; avisos apilados; ver/filtrar/editar/crear cuentas desde el carrusel; últimos registros; hojas de detalle (saldo de hoy, ganancia cambiaria, salud financiera). Revísalo antes de las cards de hero personalizable y de cuentas con más presencia.

## Qué hacer
1. Recorre cada flujo en el simulador; capturas en ~/Claude/entregas/<sesión>/capturas/.
2. Informe en español (entregas/<sesión>/informe.md): mejoras numeradas L3-1, L3-2…; por cada una: problema, tipo de usuario, captura, opciones A/B/C y recomendación. Añade la sección del lote 3 al HTML acumulado sin borrar nada.
3. No implementes cambios de UX: solo propone. Arregla únicamente bugs claros, cada uno con su card (Yala, 2.2, frank), en un PR a 2.2 con antes/después.
4. Una card en espera decisión (Yala, 2.2, assignee jurgen) por cada mejora, con sus opciones.

## Elecciones de UI: variantes y esperar
Si alguna mejora es una elección visual, construye ~/Claude/propuestas/auditoria-ux-2.2/variantes-L3.html: autocontenida (imágenes en base64), pestañas o rejilla, **2–3 variantes claramente distintas lado a lado** por item más el «antes», hechas con maquetas reales en el simulador. Entonces:
- `xcrun simctl shutdown all`;
- avisa con `python3 ~/.claude/hooks/avisar_grok.py --avisar cierre-resumen --texto "Lote 3: variantes listas para elegir: <ruta del HTML> · PR: <url si hay>"`;
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

## Paso 0 — decisiones (resueltas en autónomo (bypass), 2026-10-13)

1. **Base y PR:** rama sobre `origin/2.2` (comprobado: `git log origin/2.2..HEAD` vacío). PR contra `2.2`.
2. **Qué se arregla en código:** solo bugs claros del lote, donde la pantalla dice algo falso o se lee mal, y el arreglo no decide producto:
   - B1 «Hoy ⓘ» con todo el dinero en la divisa principal abre una hoja que dice «tienes dinero en otras monedas» → la píldora y el punto solo abren la hoja si hay saldo en otra moneda.
   - B2 «Tienes S/ 1.800 en 3 cuentas» con el Panel filtrado a una cuenta → el conteo sale de las mismas cuentas que suma el saldo (ticket `panel-lee-el-filtro-de-cuentas-en-singular-fuera-del-saldo`, punto 1).
   - B3 eje de las gráficas del Panel «2K 2K 2K» → decimales según el paso del eje (solo gráficas del Panel; las de Estadísticas, Planificación y Reportes se anotan, no se tocan: alcance estricto).
   - B4 «botones del header» / «la estrella del header» en las ayudas en español → «de arriba» (4 variantes de español; es-AR con voseo). Los demás idiomas ya dicen «cabecera».
3. **Qué NO se arregla:** lo que necesita decidir qué mide o qué dice la app (Disponible, Salud financiera, avisos, filtros…) va a mejora con opciones A/B/C y card de Jürgen. El «quitar filtro que no recalcula» se vio una vez y no se reprodujo en 3 intentos: ticket de backlog, sin arreglo.
4. **Elecciones visuales:** hay varias (foco con relleno sólido, cuentas plegadas, estado sin cuentas). Se construye `variantes-L3.html` con maquetas del simulador y la sesión se queda viva esperando la elección; no se ejecuta `/cerrar-total`.
5. **Merge del PR de bugs:** queda en cola de auto-merge (modo autónomo); no depende de la elección visual.
