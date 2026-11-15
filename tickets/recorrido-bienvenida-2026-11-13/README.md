# Recorrido de la bienvenida con Jürgen — iPhone 14, 13-nov-2026

Sesión manual en la Max. Se verifica, no se programa: cada hallazgo es un ticket en esta carpeta y sus
capturas van a `docs/qa/recorrido-bienvenida-2026-11-13/`.

**Build probada:** Yala Dev (Debug-Dev) compilada de `origin/2.3` en `dc13428f5` más las ramas de los dos
arreglos aún en cola de merge: «Usar otra cuenta» (PR 953) y «Tras ¡Tu cuenta está lista!, Empezar lleva al
Panel» (PR 954). Instalada por cable tras desinstalar Yala y Yala Dev, para partir de cero.

## Flujos

| # | Flujo | Estado | Hallazgos |
|---|---|---|---|
| 0a | Tras «Ya está tu cuenta», directo al Panel | pendiente | |
| 0b | Entrar con otra cuenta de Google o Apple | pendiente | |
| 1 | Welcome (pantalla inicial) | pendiente | |
| 2 | Entrar con Google | pendiente | |
| 3 | Entrar con Apple | pendiente | |
| 4 | Entrar con iCloud privado | pendiente | |
| 5 | «Empezar de cero» | pendiente | |
| 6 | «Dividir con amigos» | pendiente | |
| 7 | Pasos iniciales y minitutoriales | pendiente | |
| 8 | Minitutorial del correo | pendiente | |
| 9 | Bandeja | pendiente | |
| 10 | Modo nube | pendiente | |

## Escenarios recorridos (13-nov, 14:26–15:45)

Paso a paso con capturas y el veredicto de Jürgen: artifact «Recorrido de la bienvenida»
(https://claude.ai/artifact/F4TCuVEC91NeiHvyoUJvAm). Capturas ligeras en `docs/qa/recorrido-bienvenida-2026-11-13/eNN/`;
los PNG originales, en `~/Claude/entregas/2026-11-13-recorrido-interactivo-bienvenida-iphone-max/evidencia/`.

| # | Escenario | Resultado |
|---|---|---|
| E01 | iCloud con datos · Entrar con mi iCloud · Quitar datos | Funciona; 7 hallazgos de flujo y texto |
| E02 | iCloud con datos · Empezar de cero · Vaciar datos | Funciona; texto Pro |
| E03 | iCloud «vacío» (62 categorías) · iCloud | Mal: lo trata como «con datos», 34 s + 54 s |
| E03b | iCloud de verdad vacío · iCloud | Bien |
| E04 | iCloud sin datos · Google existente · Cerrar sesión | Arreglo de «Empezar» OK; Panel vacío; 50 s; pide reabrir |
| E05 | iCloud sin datos · Google existente (test) · Eliminar cuenta | Panel vacío otra vez; textos de eliminar |
| E06 | iCloud sin datos · Google nueva | Funciona; textos de cuenta nueva |
| E07 | Volver a tu iCloud con ~2300 registros | Atasco >6 min, «Cancelar» desactivado; causa medida en su card |
| E08 | iCloud con datos · Google existente | Panel y Registros vacíos hasta reabrir (store medido: datos presentes) |
| E10 | iCloud con datos · Apple existente (= cuenta test por correo) | Vacío incluso tras reabrir |
| E11 | iCloud con datos · Apple nueva | Funciona; mensaje contradictorio Apple/Google |
| E12 | Usar otra cuenta (Google y Apple) | Arreglo de «otra cuenta» OK, sin bucle |
| E13 | Dividir con amigos | Entra, pero aterriza en el Panel; layout en iPhone 14 |
| E14 | Tutoriales, Bandeja, 7 primeros pasos y correo | Funciona; problemas de layout en iPhone 14 |

No recorridos: iCloud sin datos con Apple (las pantallas de Google con y sin datos de iCloud fueron idénticas) e iCloud con
datos + Google nueva (la cuenta test se gastó en E07). Se dice en el cierre.

## Decisiones de Jürgen en el recorrido (13-nov)

- Cerrar sesión, Quitar datos y Eliminar cuenta tienen pantalla propia con progreso; no se pide reabrir Yala salvo que
  haya iCloud de por medio (y aun así, mejor evitarlo).
- En el camino de cuenta (Google o Apple) no se menciona iCloud.
- Si la cuenta ya tiene grupos, ni la intro ni el consentimiento de Grupos vuelven a salir.
- Quien recupera sus datos no responde las tres preguntas; si se pregunta, se pregunta todo.
- El mismo correo abre la misma cuenta con Apple o con Google; los textos lo dicen así.
- En «Ver los 7 pasos» se puede abrir cualquier paso y la hoja se ve entera.
- En modo iCloud la salida se llama «Cerrar sesión».
- «¡Primeros pasos completos!» aunque se omitan pasos: se queda así, para no abrumar.
- Los tutoriales de Ajustes se actualizan con urgencia.

## Cards creadas (tablero Yala, versión 2.3)

Muy alta: Panel vacío tras «¡Tu cuenta está lista!» · iCloud vaciado tratado como «con datos».
Alta: «Volver a tu iCloud» atascado · Conectar tarda 22–50 s · Cerrar sesión con vista propia y sin reabrir.
Media: un solo «Continuar» al recuperar · sin tres preguntas a quien recupera · guías que se repiten · «Cerrar sesión» en
modo iCloud · Dividir con amigos empuja iCloud · aterrizar en Grupos · Apple/Google mismo correo · textos de entrada y
salida · pregunta de los datos de iCloud al entrar con cuenta.
Baja: 63/65 categorías · destacar Más · intro de Grupos con grupos · guía bajo la barra · hoja de la puerta de Grupos ·
primeros pasos en el iPhone 14.

## Matriz de escenarios (pedida por Jürgen, 13-nov 14:05)

Cuentas: Google «antigua» = la de staging con grupos; Google «nueva» = una 2.ª cuenta suya, nunca usada en Yala Dev.
Apple «nueva» = su Apple tras «Eliminar cuenta» en Yala. El iCloud del iPhone 14 se puede vaciar (lo aprobó).

| # | iCloud del teléfono | Entrada | Después | Estado |
|---|---|---|---|---|
| E01 | con datos | iCloud privado | Cerrar sesión | pendiente |
| E02 | sin datos | iCloud privado | Vaciar datos | pendiente |
| E03 | con datos | Google antigua | Cerrar sesión | pendiente |
| E04 | con datos | Google nueva | Vaciar datos | pendiente |
| E05 | sin datos | Google antigua | — | pendiente |
| E06 | sin datos | Google nueva | Eliminar cuenta | pendiente |
| E07 | con datos | Apple antigua | Cerrar sesión | pendiente |
| E08 | con datos | Apple nueva (tras eliminar) | Vaciar datos | pendiente |
| E09 | sin datos | Apple antigua | — | pendiente |
| E10 | sin datos | Apple nueva | Eliminar cuenta | pendiente |
| E11 | — | Otra cuenta de Google / de Apple | — | pendiente |
| E12 | — | Empezar de cero · Dividir con amigos · pasos y minitutoriales · Bandeja | — | pendiente |

**13-nov 14:10 — pausa:** la sesión de la Mini («adopt a medias») usó el mismo iPhone 14 por red: reinstaló su build
y mató un adopt a mitad. Las capturas tomadas sobre ese estado se descartaron. Jürgen: primero la Mini; se retoma
cuando suelte el teléfono.

## Notas de Jürgen, por flujo

_(se llenan en vivo)_
