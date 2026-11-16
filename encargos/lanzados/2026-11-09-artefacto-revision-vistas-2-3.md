---
esfuerzo: high
toca: docs/ux/revision-2-3-artefacto/
release: no
---

# Armar un artefacto visual único con toda la revisión por vistas 2.3 y su consolidación

## Contexto
Entre el 7 y el 9 de noviembre de 2026 se revisó la app vista por vista para 2.3, y luego se consolidó todo en lotes de mejoras. Todo ya está mergeado en el repo `jur211296/Yala`. Jürgen quiere revisarlo TODO en un solo lugar.

PR de origen, todos mergeados. Lee cada uno y los documentos que agregó:
- Revisión de Panel: #846
- Revisión de Registros, filtros, calendario y búsqueda: #847
- Revisión de Nuevo registro, favoritos, voz y foto: #848
- Revisión de Planificación: #852
- Revisión de Estadísticas: #853
- Revisión de Grupos: #856, y sus tickets en #857
- Revisión de Reportes y Flujo de caja: #859
- Revisión de Bandeja, Yala IA, correo del banco, Apple Pay y Siri: #860
- Revisión de Cuentas, tarjetas, categorías, etiquetas y divisas: #862
- Revisión de Perfil, Más, Ajustes, Pro y ayuda: #864
- Revisión de Nube, iCloud y cierre de sesión: #865
- Índices de la revisión: #850 y #851
- Consolidación final, con once lotes de mejoras necesarias: #866 (es la columna vertebral)

## Qué se pide
Un ARTEFACTO NATIVO DE CLAUDE (claude.ai/artifact, privado; no HTML suelto ni PDF) que Jürgen pueda abrir y recorrer.
- MUY VISUAL y con poco texto: tarjetas, chips de prioridad, íconos, colores, contadores y, donde ayude, capturas o miniaturas de la vista. Frases cortas, nada de párrafos largos.
- BIEN DIVIDIDO: una navegación por vista o zona (Panel, Registros, Nuevo registro, Planificación, Estadísticas, Grupos, Reportes y Flujo, Bandeja e IA, Cuentas y categorías, Perfil y Ajustes, Nube) y una portada con el resumen general.
- CLARO QUÉ IMPORTA Y QUÉ NO: separa visualmente lo necesario (lo que entra a los once lotes de la consolidación) de lo deseable o menor y de lo descartado. Usa la clasificación que ya traen las revisiones y la consolidación, sin inventar una nueva. En la portada, que se vea de un vistazo cuántos hallazgos hay por nivel y por vista, y los lotes con lo que incluye cada uno.
- Cada hallazgo, en una línea corta: la vista, qué pasa, la prioridad, el lote en que quedó (si aplica) y el enlace al documento o PR de origen.
- Cómo publicar el artefacto: sigue el mismo método que la sesión de bienvenida del 7 de noviembre (en la Max lo documenta `/Users/max-jur/Claude/entregas/onboarding-yala-20261107/prototipo/README.md`; si no lo puedes leer desde la Mini, publica con el método nativo que tengas). Guarda la fuente en `docs/ux/revision-2-3-artefacto/` (fuente y README con el enlace), para poder actualizarlo después.
- Si una captura de la app aporta y no está en los documentos, puedes usar el simulador (en la Mini, el tope es uno) o el iPhone 14 conectado por DeviceMCP. No es obligatorio.

## Qué NO hay que tocar
- El código de la app ni sus tests.
- Los documentos de revisión existentes: solo se leen.
- `marketing/`.
- Tampoco hay que reclasificar ni decidir prioridades nuevas. Si dos documentos se contradicen, muéstralo en el artefacto como «a decidir», no lo resuelvas.
- Commits y PR sin firma de IA.

## Cómo se sabe que está bien
- El artefacto abre y tiene portada más una sección por cada vista de la lista.
- Todos los hallazgos de la consolidación y de las revisiones aparecen, sin duplicados, y cada uno tiene su prioridad y su enlace de origen.
- En la portada, lo importante se distingue de lo menor a simple vista.
- El enlace al artefacto va en el README, en el cuerpo del PR y en el cierre.

## Cierre
La sesión corre en modo semi. Al terminar, mergea el PR con la fuente y cierra con `/cerrar-total`, dejando arriba del cierre el enlace al artefacto. Si algo vital la frena, pregúntale a Jürgen y espera con la sesión viva.

## Paso 0 — decisiones

> Resueltas en autónomo (modo semi, sin nadie delante): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Sobre qué rama?** → `origin/2.3`, y el PR va contra `2.3`.
Por qué: los trece PR de origen se mergearon en `2.3`; en `2.2` no existe `docs/ux/revision-vistas-2.3/`. La rama nació de `2.2` sin trabajo propio y se recreó sobre `2.3` antes del primer cambio. Alternativa descartada: PR contra `2.2` (la fuente apuntaría a documentos que esa rama no tiene).

**D2 · ¿Qué cuenta como hallazgo?** → los problemas priorizados y los hallazgos secundarios (en Panel, «Hallazgos menores») de cada ficha, más lo que los lotes y tickets nombran. No entran perfiles, eficiencia, terminología ni «lo que ya está bien».
Por qué: es el mismo corte que usó la consolidación (PR 866). Alternativa descartada: meter las tablas de eficiencia y terminología (son análisis, no hallazgos, y duplicarían los problemas).

**D3 · ¿Qué clase lleva cada hallazgo?** → la de la consolidación en las zonas 34 a 41. En 30 y 32, «Necesaria» para lo que entró en su lote (PR 854 y 855) y «Decisión» para el resto de problemas, porque su ficha los pone en «Decisiones para Jürgen». Lo que la ficha dice que 2.2 ya arregló va como «Ya en 2.2». Los secundarios de Panel son «Menor» (así los titula su ficha; sus dos hipótesis, «Por verificar»). Los secundarios de Registros y Nuevo registro no los clasificó nadie: van como «Sin clasificar» con su severidad.
Por qué: el encargo prohíbe reclasificar; «Sin clasificar» dice el estado real sin inventar una clase. Alternativa descartada: asignarles clase por su severidad.

**D4 · ¿Un hallazgo partido en dos destinos?** → dos filas, cada una con su clase (como hace la consolidación con P5 de Planificación o P8 de Cuentas). «Beto paga a Tú» sale como fila propia del lote 6.
Por qué: evita que un mismo renglón diga «necesaria» y «decisión» a la vez. No duplica: cada fila es una parte distinta.

**D5 · Contradicciones** → no hay clases contradictorias entre fichas y consolidación. Se muestran en una caja «Lo que no cuadra entre documentos»: índice desactualizado, Registros sin lote y lo del lote 6.

**D6 · Publicación** → artefacto privado de Claude con la herramienta Artifact (mismo método que la bienvenida del 7-nov, que publicó así). La guía de la Max no se lee desde la Mini. Capturas: una por problema, sacadas de las que ya hay en la revisión; no hace falta simulador.

**D7 · Fuente** → `docs/ux/revision-2-3-artefacto/`: `fuente/hallazgos.tsv` (los datos, una fila por hallazgo), `fuente/plantilla.html`, `fuente/build.py` (genera `index.html` e `img/`) y `README.md` con el enlace y cómo republicar.
