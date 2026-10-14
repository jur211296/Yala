# Auditoría UX 2.2 · lote 7: cuentas, categorías, etiquetas, favoritos e importar

> **ALCANCE ESTRICTO:** solo los 16 flujos del lote 7. Los criterios UX/UI se aplican solo a sus pantallas. Si ves algo fuera, anótalo en una línea en el informe y no lo toques.

Card: tablero-auditoria-ux-2-2-lote-7-cuentas-categori-q0da (Yala, 2.2, high). Card madre ogl6: no la muevas.

**Base y PR: 2.2.** `lanzar-sesion` ignora --base: Frank ya te deja sobre origin/2.2; ANTES de tu primer commit, `git fetch origin && git log origin/2.2..HEAD` debe salir vacío. PR contra **2.2**.

## Fuentes
- Brief madre (método, cinco lentes, formato de informe, HTML acumulado y «Criterios UX/UI permanentes de Jürgen»): ~/Claude/tmp-frank/auditoria-ux-flujos-2-2.md. Léelo entero.
- Mapa: docs/ux/mapa-de-flujos-2.2.md (sección lote 7).
- Lotes anteriores como ejemplo: ~/Claude/entregas/Yala--auditoria-ux-2-2-lote-6-datos-previos-nube/informe.md y ~/Claude/propuestas/auditoria-ux-2.2/auditoria-ux-2.2.html.
- Referencia visual: ~/Claude/referencias-ui/kargul-2026-10-07/.

## Lote 7 (16 flujos)
crear, editar, archivar, eliminar y reordenar cuentas, cambiar su divisa, ajustar saldo, categorías y subcategorías (crear, borrar, ocultar), etiquetas, favoritos, segunda divisa, importar CSV/Excel, cuenta por defecto (no existe). Incluye el ticket deleting-an-account-asks-nothing.
Nota: crear/editar cuentas tiene el criterio de Jürgen de claridad absoluta en las calculadoras (igual que el onboarding). Las cuentas con varias divisas son de 2.2 pero van en sus propias entregas (mxt7, 17ec, i9rh, dbxp): no las diseñes aquí.

## Qué hacer
1. Recorre cada flujo en el simulador; capturas en ~/Claude/entregas/<sesión>/capturas/.
2. Informe en español (entregas/<sesión>/informe.md): mejoras numeradas L7-1, L7-2…; por cada una: problema, tipo de usuario, captura, opciones A/B/C y recomendación. Añade la sección del lote 7 al HTML acumulado sin borrar nada.
3. No implementes cambios de UX: solo propone. Arregla únicamente bugs claros, cada uno con su card (Yala, 2.2, frank), en un PR a 2.2 con antes/después.
4. Una card en espera decisión (Yala, 2.2, assignee jurgen) por cada mejora, con sus opciones.

## Elecciones de UI: variantes y esperar
Si alguna mejora es una elección visual, construye ~/Claude/propuestas/auditoria-ux-2.2/variantes-L7.html: autocontenida (imágenes en base64), pestañas o rejilla, **2–3 variantes claramente distintas lado a lado** por item más el «antes», hechas con maquetas reales en el simulador. Entonces:
- `xcrun simctl shutdown all`;
- avisa con `python3 ~/.claude/hooks/avisar_grok.py --avisar cierre-resumen --texto "Lote 7: variantes listas para elegir: <ruta del HTML> · PR: <url si hay>"`;
- **NO ejecutes /cerrar-total. Quédate viva** esperando la elección de Jürgen (llegará por decirle). No borres el worktree.
Si no hay ninguna elección de UI, cierra normal con /cerrar-total.

## Reglas duras de UI
- NADA de degradados, NADA de glows/brillos, NADA de contraste en blanco sólido.
- El botón «Siguiente» NO se toca.
- El liquid glass se queda.
- La moneda «S/» frente a «PEN» es una preferencia del usuario: nunca la pongas como opción A/B/C.
- Capturas de HOY (de esta sesión) y maquetas reales en el simulador para cada propuesta visual.
- Copy nueva en los 16 idiomas (es-AR con voseo).

## Cómo
- Pipeline serie en la Mini: `nice -n 10 xcodebuild -jobs 2`, como máximo 1 simulador, `xcrun simctl shutdown all` al terminar.
- Tests de lo que arregles con -only-testing y /gate.

## Reglas
Totalmente autónomo: nunca AskUserQuestion ni preguntas, decide tú. Sin deploy.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Qué cuenta como «bug claro» que se arregla en el PR?** → Lo que contradice lo que la app dice o promete, borra sin preguntar, o rompe un camino oficial: 12 bugs (B1-B12). Lo que cambia el flujo o el aspecto va a card.
Por qué: el encargo pide no implementar UX. Alternativa descartada: arreglar también «la X descarta sin preguntar» en el formulario de cuenta — cambia el flujo y Jürgen tiene un rediseño aprobado del formulario; va a card (L7-5).

**D2 · Borrar una cuenta: ¿qué dice la confirmación?** → Alerta con el número de registros y su destino real, medido: «no se borran, quedan en Registros, sin cuenta» + «si solo quieres dejar de verla, archívala» + «no se puede deshacer».
Por qué: es el «hecha cuando» del ticket `deleting-an-account-asks-nothing`. Alternativa descartada: un botón «Archivar en su lugar» — es producto, se propone aparte.

**D3 · Diálogos de Categorías sin «Cancelar»** → Pasan de `confirmationDialog` a `.alert`, que pinta los dos botones (medido: la de Etiquetas ya es alerta y sí lo enseña). El descarte reutiliza los textos ya traducidos de la Bandeja («¿Descartar cambios?» / «Seguir editando»).
Por qué: cero texto nuevo en 16 idiomas. Alternativa descartada: botón sin rol dentro del diálogo — sigue siendo un popover anclado.

**D4 · Plantilla CSV que no se importa: ¿se arregla la plantilla o el importador?** → El importador: parte los campos respetando comillas (RFC 4180) en los 5 sitios.
Por qué: un CSV exportado de Excel o Sheets con comas dentro lleva comillas igual; quitar las comillas de la plantilla dejaría roto a cualquier nombre con coma. Alternativa descartada: plantilla sin comillas.

**D5 · Selector de moneda titulado «Divisa preferida»** → Título «Moneda» (clave ya traducida) en el componente compartido; arregla también los 4 usos de Grupos, que tampoco eligen la divisa preferida.
Por qué: todas las instancias del patrón. Alternativa descartada: parámetro de título por llamador — más código para el mismo texto.

**D6 · Textos (B10, B12)** → Plurales de «N transacciones» en las tres alertas del lote (B10); mayúsculas inglesas en español («Cuenta Corriente», «Tarjeta de Crédito», «Importar Transacciones», «Divisa y Cambio»); «Perfil > Divisa» apunta a la fila real (B12). Y B11, salido por el camino: en polaco, japonés y chino el aviso de transferir registros ponía el nombre antes que el número sin posiciones; se arregla con argumentos posicionales y un test de orden de argumentos en todo el catálogo. «transacciones» frente a «registros» NO se cambia aquí: va a card (L7-18).

**D7 · Elecciones visuales** → Dos: la ayuda para calcular el saldo y el tipo de cuenta, con el criterio del onboarding (L1UI ya mergeado). 3 variantes + antes cada una, maquetas reales en el simulador, en `variantes-L7.html`. La sesión se queda viva esperando la elección; el PR de bugs queda abierto.
Por qué: el encargo lo pide así cuando hay elección visual.

**D8 · 7.16 cuenta por defecto** → Sin card nueva: ya es L2-1 (cuenta preelegida).
