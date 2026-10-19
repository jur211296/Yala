# Auditoría UX 2.2 · decidido por Jürgen · 06 · Yala Pro: paywall, prueba gratis, fin de la prueba y Pro activo

Base y PR: **2.2** (no 2.1). `lanzar-sesion` te deja sobre origin/2.1: antes del primer commit haz `git fetch origin && git switch -C encargo-tmp origin/2.2` (o rebasa tu rama sobre origin/2.2) y comprueba que `git log origin/2.2..HEAD` sale vacío. El PR va contra **2.2**.

## Contexto
Jürgen respondió el 18-oct (18:41–21:18 Lima, sesión «preguntas-auditoria-ux-2-2») todas las cards de la auditoría UX 2.2 que esperaban decisión. Resumen completo: `~/Claude/entregas/Yala--preguntas-auditoria-ux-2-2/decisiones.md`. Esta sesión implementa las de abajo, que están en «ready to launch» asignadas a frank, con la decisión en la nota de cada card.
Fuentes: la card (nota = decisión; contexto con capturas), el informe del lote en `~/Claude/entregas/Yala--auditoria-ux-2-2-lote-16-ajustes/informe.md`, `~/Claude/entregas/Yala--auditoria-ux-2-2-lote-17-yala-pro/informe.md`, el HTML `~/Claude/propuestas/auditoria-ux-2.2/auditoria-ux-2.2.html` (opciones A/B/C/D y variantes) y los «Criterios UX/UI permanentes de Jürgen» del brief madre `~/Claude/tmp-frank/auditoria-ux-flujos-2-2.md` (léelos: sin degradados, etc.). Las variantes elegidas (p. ej. «L17-2-B.png») están en `capturas/` de esa misma carpeta del lote.

## Cards de esta sesión (10)
- **L17-1** · `tablero-ux-2-2-l17-1-yala-pro-se-esconde-en-admi-yqfr`
  UX 2.2 · L17-1 · Yala Pro se esconde en «Administrar suscripciones», dentro de Seguridad
  Decisión de Jürgen: opción B (recomendada). Fila «Yala Pro» en la primera sección de Ajustes con el estado del plan.
- **L17-2** · `tablero-ui-2-2-l17-2-el-paywall-esconde-el-preci-hw80`
  UI 2.2 · L17-2 · El paywall esconde el precio y no explica cuándo se cobra la prueba
  Decisión de Jürgen: opción C, variante 2 (recomendada): cabecera corta sin degradado, planes arriba, fichas debajo y «Así funciona la prueba» (L17-2-B.png).
- **L17-3** · `tablero-ui-2-2-l17-3-funcion-pro-no-dice-que-pas-etf0`
  UI 2.2 · L17-3 · «Función Pro» no dice qué pasa con lo que ya tienes y manda a otra hoja
  Decisión de Jürgen: opción C, variante 2 (recomendada): título que dice lo que pasa, línea de tranquilidad y los planes dentro de la hoja; al terminar vuelve a lo que se hacía (L17-3-B.png).
- **L17-4** · `tablero-ux-2-2-l17-4-actualizar-a-pro-suena-a-ac-2l1g`
  UX 2.2 · L17-4 · «Actualizar a Pro» suena a actualizar la app
  Decisión de Jürgen: opción C (recomendada). «Probar Pro gratis» con prueba disponible y «Pasarme a Pro» si ya la usó.
- **L17-5** · `tablero-ux-2-2-l17-5-la-oferta-de-prueba-no-tien-e18w`
  UX 2.2 · L17-5 · La oferta de prueba no tiene salida a la vista
  Decisión de Jürgen: opción C (recomendada). X arriba y «Quizás después» a la vista; no mostrar la oferta a quien ya usó la prueba.
- **L17-6** · `tablero-ui-2-2-l17-6-al-terminar-la-prueba-salen-u5pi`
  UI 2.2 · L17-6 · Al terminar la prueba salen dos hojas seguidas y la primera alarma
  Decisión de Jürgen: opción C, variante 2 (recomendada): una sola hoja «Tu prueba de Pro terminó», «Elegidos 3 de 3», «Conservar estos 3» y aviso al tocar un cuarto (L17-6-B.png).
- **L17-7** · `tablero-ux-2-2-l17-7-el-banner-de-prueba-invita-ou7o`
  UX 2.2 · L17-7 · El banner de prueba invita a «Suscribirse» a quien ya está suscrito
  Decisión de Jürgen: opción C (recomendada). Línea con días restantes, precio y «Gestionar», solo los últimos 5 días.
- **L17-8** · `tablero-ux-2-2-l17-8-la-pantalla-de-pro-activo-e-e0bd`
  UX 2.2 · L17-8 · La pantalla de Pro activo está casi vacía
  Decisión de Jürgen: opción C (recomendada). Tarjeta del plan con fecha y precio, lo que incluye, «Gestionar o cancelar» y qué pasa si cancelas.
- **L17-9** · `tablero-ux-2-2-l17-9-tras-comprar-yala-no-te-dev-fleb`
  UX 2.2 · L17-9 · Tras comprar, Yala no te devuelve a lo que querías hacer
  Decisión de Jürgen: opción C (recomendada). «Comenzar» cierra todo lo de Pro y abre la función de la que venía.
- **L16-11** · `tablero-ux-2-2-l16-11-un-tema-o-un-icono-pro-no-pfur`
  UX 2.2 · L16-11 · Un tema o un icono Pro no se puede ver antes de pagar
  Decisión de Jürgen: opción C (recomendada). Vista previa del tema/icono en el muro y aviso único al perder Pro antes de volver al icono original.

## Avisos de esta sesión
- No cambies precios, productos de StoreKit ni la duración de la prueba: solo cómo se enseñan. Prueba con el StoreKit de pruebas del proyecto.
- L17-6 (conservar 3 de 3) toca qué datos quedan activos al perder Pro: review adversarial antes del PR (nada se borra, solo se elige).
- L16-11: el aviso único al perder Pro antes de volver al icono original.

## Cómo mover las cards
- Al empezar con cada una: `tablero mover <id> --a "in progress" --agente frank`. No uses `--nota` en `tablero editar` salvo para AÑADIR: `--nota` reemplaza la nota entera, así que copia la decisión de Jürgen que ya está y añade debajo lo tuyo.
- Al cerrar: a `done` (`--agente frank`) las que queden hechas y mergeadas sin nada que probar en el teléfono; a `in qa` asignadas a `jurgen` con un guion corto de iPhone en la nota si hay algo que él deba probar en el teléfono.
- Todo ticket nuevo lleva su card.

## La UI sigue la decisión al pie de la letra
- Implementa exactamente lo que dice la decisión de cada card (y la variante con captura si la hay). No inventes UI ni «mejores» la opción elegida. Los detalles que la decisión no fija y que el sistema de diseño ya resuelve (márgenes, tipografía, componentes existentes) se toman de lo que ya hay en la app.
- Si al implementar aparece algo de verdad sin decidir (dos caminos que cambian lo que ve el usuario y ninguno sale de la decisión), NO elijas tú: deja 2–3 propuestas con capturas o mock y tu recomendación en la nota de esa card, muévela a «espera decisión» asignada a `jurgen` con `--pregunta`, y sigue con las demás. Solo se para ese ítem, no la sesión.
- Ningún texto de la app escribe «OpenAI»: se dice «un servicio de IA» (con enlace a la política de privacidad, que es el único sitio que nombra al proveedor).
- Todo texto nuevo o cambiado, en los **16 idiomas**, y `/l10n-check` limpio.

## Reglas
- **Sin esperar el CI de ningún PR** (tampoco el tuyo): `git fetch origin && git rebase origin/2.2` justo antes de abrir el PR.
- Pipeline serial en la Mini: limpiar, build con `xcodebuild -jobs 2` sin simulador encendido, encender 1 simulador, tests, apagarlo. 1 simulador a la vez. Mira `df -h /` antes de compilar. Usa los simuladores iOS 27.0. Al cerrar, apaga y borra (erase) el simulador que usaste.
- Al lanzar y al cerrar borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen; no toques las de un worktree vivo.
- En `~/Yala` (árbol principal) no toques, commitees ni descartes `Cloudkit Schemas/yala_dev-*.ckdb`, `Yala.xcscheme` ni `encargos/pendientes/`.
- Nada de salud ni de clínicas. No toques tmux `salud--*`, `sat-lab--*`, `ruum--*`, `clinicas-dentales-bi--*`, `Yala--qa-guiado-2-1-tf17` ni otros `Yala--` vivos.
- Nada de despliegues a producción (Worker/gateway, Supabase, CloudKit Production, web). Si algo hace falta, déjalo listo con los pasos en una card a `jurgen` (o a `lola` si es CloudKit) y sigue.
- No cambies cuota, modelo ni proveedor de IA, precios ni productos de StoreKit.
- Prueba la sesión tú misma con **/barrido-qa** en el simulador (tests de lo que cambie, flujos tocados de punta a punta, VoiceOver en lo nuevo). Hay cambio visible: capturas de antes y después en `capturas/` del worktree, copiadas también a `~/Claude/entregas/<sesión>/capturas/`, con sus rutas en el resumen de cierre.
- Cierra sola con **/cerrar-total** (merge incluido). No esperes a nadie.

## Cómo se sabe que está bien
Cada card hecha tal como la decidió Jürgen (o, si algo no estaba decidido, con sus propuestas en la card a `jurgen` y solo ese ítem parado), textos en los 16 idiomas, tests en verde (`/gate`, `YalaTests`), /barrido-qa pasado, capturas de antes y después, cards movidas, y PR mergeado en 2.2 explicando en lenguaje de usuario qué verá la persona.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · Base** → rama sobre `origin/2.2` (b6b76bdb1), PR contra 2.2. Hecho y comprobado (`origin/2.2..HEAD` vacío).

**D2 · Una sola pieza de venta para paywall y oferta (L17-2 + L17-5)** → `SubscriptionView` (sin Pro) y `ProTrialOfferSheet` comparten una vista nueva con el molde L17-2-B: cabecera corta (estrella pequeña sin halo, «Yala Pro» + «Apunta en segundos, sin límites»), planes arriba (el elegido relleno de acento), «Así funciona la prueba» (solo con derecho a prueba), CTA, salida, fichas de cristal «Qué incluye Pro» y el pie legal de siempre. Fondo `.subtle` (sin el degradado premium).
Por qué: la nota de L17-2 dice «vale para el paywall y para la oferta». Alternativa descartada: dos copias divergentes.

**D3 · Textos de las capturas** → se usan los de las variantes elegidas («30 días gratis, luego $29.99 al año», «Sale a $2.50 al mes», «Probar gratis 30 días», «Ya tienes 3 presupuestos», «Probar Pro gratis 30 días», «Ahora no», «Elegidos 3 de 3», «Conservar estos 3»), con los días y precios de StoreKit. Por qué: «la UI sigue la decisión al pie de la letra». El pie legal (cobro, renovación, Términos y Privacidad) se queda en las tres hojas de compra aunque la maqueta no lo pinte: lo exige App Review (3.1.2).

**D4 · Fecha de «Así funciona la prueba»** → hoy + el periodo de la oferta introductoria del plan elegido (StoreKit). El precio del paso 2 es el del plan elegido. Sin derecho a prueba el bloque no sale.

**D5 · L17-3: los planes dentro de «Función Pro»** → la hoja compra sola (sin abrir el paywall encima). Título por función y línea de tranquilidad por función (textos propios, ver PR); el ejemplo de voz y foto (L4-12) se queda; la línea de oferta sobra (los planes ya dicen el precio). Sin X: «Ahora no» como en la captura. El texto de presupuestos sustituye al de L9-9 («Desactiva uno o pásate a Pro») porque L17-3 es la decisión posterior sobre la misma hoja.

**D6 · L17-4: «Probar Pro gratis» / «Pasarme a Pro»** → en todos los botones que llevan a Pro (banner del Panel, tarjeta IA de Estadísticas, hito, banner de límite de cuentas, botón de «Función Pro» cuando el CTA no compra). Elegibilidad desconocida (precios sin cargar) ⇒ «Pasarme a Pro»: no se promete lo que no se midió.

**D7 · L17-5: no enseñar la oferta a quien ya usó la prueba** → se re-mide al drenar `.presentTrialOffer`: con derecho, se presenta; sin derecho, no se presenta y la oferta se desarma; sin precios cargados, no se presenta y se queda armada (vuelve en el siguiente arranque). X arriba a la derecha y «Quizás después» bajo el CTA, a la vista sin bajar.

**D8 · L17-6: una sola hoja al terminar Pro** → `DowngradeResolutionSheet` rehecha con el molde L17-6-B. Título «Tu prueba de Pro terminó» si lo último activo era la prueba y «Tu suscripción terminó» si pagó (nueva marca persistida: la última suscripción activa vista era introductoria). La hoja quema el aviso «Prueba terminada» al aparecer, y el drenaje de ese aviso re-mide que no haya hoja de fin de Pro pendiente: nunca salen dos. Sin exceso ni icono que devolver, a quien terminó la prueba le sale solo «Prueba terminada» (ya con el molde L17-3). Botón con exceso de un solo tipo: «Conservar estos 3» / «Conservar estas 4»; con los dos: «Conservar lo elegido» (asumido). Se sigue exigiendo elegir exactamente el límite (regla de datos sin cambiar). Aviso al tocar uno de más: «Quita uno para elegir «X»». La línea de la captura «vuelven si reactivas Pro» NO se usa: nada los reactiva solo (medido); se dice dónde quedan y que no se borra nada.

**D9 · L16-11: aviso antes de volver al icono original** → el icono ya no se devuelve en silencio en `checkForDowngrade`: la hoja de fin de Pro sale también si solo hay icono que devolver, lo avisa en una línea y lo devuelve al confirmar. Así es una sola hoja (L17-6) y el aviso es único. «Icono de la app» no devuelve el icono por su cuenta mientras esa hoja esté pendiente. El tema sigue volviendo en silencio (la decisión habla del icono): se anota en Encontrado.

**D10 · L16-11: vista previa en el muro** → la hoja de L17-3 pinta, en lugar del icono de la función, la miniatura del tema tocado (la misma de Temas, más grande) o el icono tocado, con «Así se vería Yala».

**D11 · L17-9: «Comenzar» cierra todo y abre la función** → la compra desde «Función Pro» cierra la bienvenida y la hoja, y quien la abrió hace lo que el usuario quería (grabar voz, foto, chat, cuenta nueva, presupuesto nuevo, aplicar el tema o el icono, reintentar desvincular). Donde la función es la misma pantalla bloqueada (tarjetas de IA en Estadísticas, voz e imagen ya abiertas), volver ES abrirla. La compra desde el paywall (banner, Ajustes, hito, fin de Pro) cierra el paywall y la hoja que lo abrió. La bienvenida pierde el halo y el brillo; si viene de una función, el subtítulo dice «Ya puedes …». El tour de Pro solo arranca si no hay función que abrir.

**D12 · L17-7** → el banner de prueba solo sale con 5 días o menos (incluido el último día): «Te quedan N días de prueba · después $29.99 al año» y «Gestionar» (hoja de suscripciones de Apple). Si la renovación está apagada, sin el «después…». El banner periódico de gratis no cambia salvo su botón (L17-4).

**D13 · L17-8 y L17-1: estado del plan** → `StoreKitManager` expone el plan activo (plan, fecha, prueba, si se renueva). Ajustes: fila «Yala Pro» arriba de Organización con «Gratis · prueba 30 días gratis» / «Gratis» / «Prueba · termina el 15 nov» / «Anual · se renueva el 15 nov» (o «termina el» sin renovación). Pro activo: tarjeta del plan con fecha y precio, «Qué incluye» (las mismas fichas), botón «Gestionar o cancelar» y «Si cancelas: sigues con 4 cuentas y 3 presupuestos; nada se borra.» La fila vieja de Seguridad se retira.

**D14 · Cómo se prueba sin cobrar** → seams de QA solo `-uitest` + DEBUG: compra simulada que activa Pro, prueba en curso con N días, plan pagado, y el aviso de fin de Pro por el escenario de router. Precios: el StoreKit de pruebas del proyecto. Nada de precios, productos ni duración cambia.

**D15 · Review adversarial** → sí, sobre L17-6/L16-11 (qué queda activo al perder Pro) y el encadenado de presentaciones de L17-9, antes del PR.
