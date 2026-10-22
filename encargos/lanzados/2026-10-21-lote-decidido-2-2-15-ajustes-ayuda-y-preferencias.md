# Auditoría UX 2.2 · decidido por Jürgen · 15 · Ajustes, perfil, personalización, permisos, ayuda y soporte

Base y PR: **2.2** (no 2.1). `lanzar-sesion` te deja sobre origin/2.1: antes del primer commit haz `git fetch origin && git switch -C encargo-tmp origin/2.2` (o rebasa tu rama sobre origin/2.2) y comprueba que `git log origin/2.2..HEAD` sale vacío. El PR va contra **2.2**.

## Contexto
Jürgen respondió el 18-oct (18:41–21:18 Lima, sesión «preguntas-auditoria-ux-2-2») todas las cards de la auditoría UX 2.2 que esperaban decisión. Resumen completo: `~/Claude/entregas/Yala--preguntas-auditoria-ux-2-2/decisiones.md`. Esta sesión implementa las de abajo, que están en «ready to launch» asignadas a frank, con la decisión en la nota de cada card.
Fuentes: la card (nota = decisión; contexto con capturas), el informe del lote en `~/Claude/entregas/Yala--auditoria-ux-2-2-lote-16-ajustes/informe.md`, el HTML `~/Claude/propuestas/auditoria-ux-2.2/auditoria-ux-2.2.html` (opciones A/B/C/D y variantes) y los «Criterios UX/UI permanentes de Jürgen» del brief madre `~/Claude/tmp-frank/auditoria-ux-flujos-2-2.md` (léelos: sin degradados, etc.). Las variantes elegidas (p. ej. «L17-2-B.png») están en `capturas/` de esa misma carpeta del lote.

## Cards de esta sesión (14)
- **L16-1** · `tablero-ux-2-2-l16-1-ajustes-no-se-llama-ajustes-wuhp`
  UX 2.2 · L16-1 · Ajustes no se llama «Ajustes» en ningún sitio
  Decisión de Jürgen: opción B (recomendada). Hoja «Ajustes» y tarjeta de Más «Ajustes · Tu perfil y tus preferencias».
- **L16-2** · `tablero-ux-2-2-l16-2-editar-el-nombre-obliga-a-b-9ht5`
  UX 2.2 · L16-2 · Editar el nombre obliga a borrar «Usuario» y la hoja no dice cómo se guarda
  Decisión de Jürgen: opción B (recomendada). Campo vacío con pista «Tu nombre», «Listo» arriba a la derecha y el párrafo en dos líneas con «Más sobre tus datos».
- **L16-4** · `tablero-ux-2-2-l16-4-los-tipos-de-cambio-de-divi-36fw`
  UX 2.2 · L16-4 · Los tipos de cambio de divisas débiles no se pueden leer
  Decisión de Jürgen: opción C (recomendada). Invertir tasas < 0,01, buscador arriba y fecha de actualización al pie.
- **L16-5** · `tablero-ux-2-2-l16-5-el-idioma-de-la-app-solo-se-qb1r`
  UX 2.2 · L16-5 · El idioma de la app solo se cambia si lo elegiste en el onboarding, y cambiarlo te saca de Ajustes
  Decisión de Jürgen: opción C (recomendada). Fila siempre visible que lleva al idioma por app de los Ajustes de iOS.
- **L16-6** · `tablero-ux-2-2-l16-6-activar-solo-gastos-parece-umen`
  UX 2.2 · L16-6 · Activar «Solo gastos» parece borrar algo
  Decisión de Jürgen: opción B (recomendada). Botón «Activar» normal (no rojo) y «Cancelar» visible.
- **L16-7** · `tablero-ux-2-2-l16-7-personalizacion-habla-en-je-xhe4`
  UX 2.2 · L16-7 · Personalización habla en jerga y no dice dónde se ve cada ajuste
  Decisión de Jürgen: opción B (recomendada). Renombrar en lenguaje de usuario y que cada pie diga dónde se ve.
- **L16-10** · `tablero-ux-2-2-l16-10-elegir-un-tema-o-un-idioma-ylnv`
  UX 2.2 · L16-10 · Elegir un tema (o un idioma) te saca de Ajustes
  Decisión de Jürgen: opción B (recomendada). Tema aplicado en vivo y la pantalla de Temas se queda abierta.
- **L16-13** · `tablero-ux-2-2-l16-13-la-barra-de-pestanas-habla-wt0i`
  UX 2.2 · L16-13 · La barra de pestañas habla de «Tabs» y no explica sus límites
  Decisión de Jürgen: opción B (recomendada). «Pestañas de abajo» y pie con las dos reglas.
- **L16-14** · `tablero-ux-2-2-l16-14-permisos-te-saca-de-yala-s-5l7h`
  UX 2.2 · L16-14 · Permisos te saca de Yala sin avisar
  Decisión de Jürgen: opción B (recomendada). Pantalla «Permisos de Yala» con el estado de cada permiso y un botón por permiso a Configuración.
- **L16-15** · `tablero-ux-2-2-l16-15-calificar-y-recomendar-sol-xj9h`
  UX 2.2 · L16-15 · «Calificar y recomendar» solo califica, y a veces no hace nada
  Decisión de Jürgen: opción C (recomendada). «Valorar Yala» abre la reseña en la App Store y fila «Recomendar Yala» que comparte el enlace.
- **L16-16** · `tablero-ux-2-2-l16-16-los-tutoriales-felicitan-p-gsgk`
  UX 2.2 · L16-16 · Los tutoriales felicitan por algo que no se hizo y enseñan una versión vieja
  Decisión de Jürgen: opción B (recomendada). Cierre «Ya sabes cómo…» con «Hacerlo ahora», vídeos y textos regrabados y ✓ en los hechos.
- **L16-17** · `tablero-ux-2-2-l16-17-las-preguntas-frecuentes-n-5idg`
  UX 2.2 · L16-17 · Las preguntas frecuentes no cubren lo nuevo y no tienen salida
  Decisión de Jürgen: opción B (recomendada). Preguntas nuevas (Grupos, Yala IA, nube/iCloud, divisas, Face ID, widgets) y pie «¿No está tu pregunta? Escríbenos».
- **L16-18** · `tablero-ux-2-2-l16-18-el-formulario-de-soporte-n-6rmx`
  UX 2.2 · L16-18 · El formulario de soporte no dice qué pasa al enviar
  Decisión de Jürgen: opción B (recomendada). Pie bajo «Enviar» que dice que se abre el correo, a qué dirección y qué se adjunta.
- **L16-19** · `tablero-ux-2-2-l16-19-privacidad-y-terminos-te-s-xael`
  UX 2.2 · L16-19 · Privacidad y términos te sacan de Yala
  Decisión de Jürgen: opción B (recomendada). Privacidad y términos dentro de Yala, en la hoja de Safari con «Listo».

## Avisos de esta sesión
- Sesión casi toda de textos y navegación: va al final de la cola.
- L16-16 pide vídeos y textos de los tutoriales regrabados: grábalos en el simulador con la app de 2.2; si algún vídeo no se puede grabar bien en el simulador, déjalo anotado en la card y sigue.
- L16-17: preguntas nuevas (Grupos, Yala IA, nube/iCloud, divisas, Face ID, widgets) en los 16 idiomas; sin nombrar al proveedor de IA.
- L16-14: una pantalla «Permisos de Yala» con el estado de cada permiso y un botón por permiso a Configuración.

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

## Añadidas 19-oct (Jürgen: las tres en A)
- tablero-las-notas-de-entrar-del-welcome-dicen-qu-zrfg: las dos notas del Welcome usan la misma frase y key que Ajustes («Si usas el mismo correo, Apple y Google abren esta misma cuenta»).
- tablero-diez-avisos-de-app-attest-siguen-diciend-oex8: reescribir los otros avisos de App Attest (cerrar sesión, desasociar, empezar de cero, aviso de la nube) con el molde de L19-18.
- tablero-quitar-mis-datos-de-este-iphone-lleva-a-dxow: en la celda sin cuenta, los avisos de después dicen «Quitar mis datos igualmente» / «Quitar y borrar».
En los 16 idiomas.
- Nueva 19-oct (para revisar, no decidida): «Revisar si «Seguridad y cuenta» en Ajustes se divide en dos subsecciones». Inventario + recomendación con capturas y maqueta; dejar en espera decisión para Jürgen, no implementar sin su sí.

## Añadido 2026-10-19 08:35 · card del QA (hacerla junto con las notas de entrar del Welcome)
Card: «UX 2.2 · Entrar con Google en un iPhone que usó Apple: «Esa cuenta usa otro método» confunde y el consentimiento se pide dos veces» (medium, 2.2).
- Texto: reescribir el aviso «Esa cuenta usa otro método» (es.lproj/Localizable.strings ~4901 y providerMismatchBody en WelcomeCloudSignInView.swift ~693-748) para que diga claro que este iPhone ya se usó con otra cuenta; 16 idiomas. Coherente con las notas welcome.cloud.providerNote / welcome.bornCloud.providerNote de este mismo lote.
- Consentimiento: que salga una sola vez en el Welcome cuando se pasa de reentrada a alta, respetando CloudConsentRegistrationLogic (ver vb1f / PR #501, WelcomeCloudSignInView.swift:31-34 y :82). No romper lo de Ajustes del lote 05 (StorageSignInChooserView, CloudActivationSheet).
- Tests unitarios + XCUITest; mover la card a in qa al cerrar.

## Añadidas 2026-10-21 (decididas por Jürgen en la sesión del roadmap) · mismas reglas, 16 idiomas
- `tablero-ux-2-2-el-tema-de-pro-vuelve-al-de-siemp-5f3p` · El tema de Pro vuelve al de siempre en silencio al perder Pro. Decisión B: una línea más en la hoja de fin de Pro («Tu tema vuelve a Liquid Glass») y el tema vuelve al confirmar, igual que el icono.
- `tablero-ux-2-2-la-bienvenida-a-pro-sigue-con-los-cxm1` · La bienvenida a Pro sigue con los nombres viejos. Decisión B: la bienvenida a Pro usa las mismas fichas de «Qué incluye Pro» que el paywall.
- `tablero-ux-2-2-la-prueba-se-anuncia-como-30-dias-k8qc` · La prueba se anuncia como «30 días». Decisión B: «1 mes gratis» cuando la oferta es de un mes. La ficha de la App Store NO es de esta sesión (card de Lola).
- `tablero-ux-2-2-l20-15-datos-no-disponibles-el-bo-pm2w` · «Datos no disponibles». Decisión B: dos botones, «Seguir esperando» abajo pero destacado (relleno de color) y «Empezar de cero» arriba en rojo; el texto dice que se vació desde otro dispositivo (el texto ya está, revisa la nota de la card y las capturas L20-15-*.png en ~/Claude/entregas/Yala--lote-decidido-2-2-05-nube-e-icloud/capturas/).
- `tablero-revisar-si-seguridad-y-cuenta-en-ajustes-2745` · sigue SIN decidir: solo inventario + recomendación con capturas y maqueta, card a «espera decisión» a `jurgen`. No se implementa.

## Ojo con la base (aviso de la sesión anterior, 21-oct 23:34)
`lanzar-sesion` arranca sobre 2.1 aunque este encargo es de 2.2. Antes de tocar nada cambia a origin/2.2 como dice arriba y confirma con `git log origin/2.2..HEAD` vacío. El PR va contra 2.2. La sesión anterior (PR #594, nube y primera foto) está en cola de merge a 2.2: si aún no entró, no la esperes.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · L16-1, ¿qué más cambia al llamar «Ajustes» a la hoja?** → La hoja se titula «Ajustes», la tarjeta de Más dice «Ajustes · Tu perfil y tus preferencias», y los textos que mandan a «Perfil › X» pasan a «Ajustes › X».
Por qué: un texto que manda a una pantalla que ya no se llama así es una instrucción falsa. Alternativa descartada: dejar «Perfil ›» (contradice la propia decisión).

**D2 · L16-2, ¿a dónde lleva «Más sobre tus datos»?** → A la política de privacidad, en la hoja de Safari dentro de Yala (el molde de L16-19). El nombre por defecto («Usuario») se enseña como campo vacío y, si se deja vacío, se guarda igual que hoy.
Por qué: el párrafo largo hablaba de lo que dice la política. Alternativa descartada: llevar a «Dónde viven tus datos» (es otra hoja dentro de otra; empujarla desde una hoja presentada no tiene camino).

**D3 · L16-4, ¿cómo se pinta una tasa invertida?** → A la derecha de la fila, «1 PEN = 2,345.67 PYG» (el formato de la decisión); las demás siguen como hoy. Buscador siempre visible arriba; el pie con la fecha ya existe y se comprueba que se ve.

**D4 · L16-5, ¿qué pasa con quien eligió idioma en el onboarding?** *(Revisado al implementar, medido el 2026-10-22: iOS solo ofrece «Idioma» en la página de Yala si el iPhone tiene más de un idioma. La C deja sin salida al caso normal; no se implementa y la card vuelve a Jürgen con propuestas.)* → La fila «Idioma de la app» sale siempre y abre la página de Yala en los Ajustes de iOS. Si en iOS se cambia el idioma de Yala, el idioma elegido dentro de la app se retira solo al volver, para que mande el de iOS. El selector propio sale de Ajustes (el del onboarding se queda).
Por qué: con el idioma de dentro puesto, el de iOS no haría nada. Se mide en el simulador que la página de iOS ofrece el idioma.

**D5 · L16-6** → Aviso del sistema (`.alert`) con «Activar» normal y «Cancelar» visible; igual al desactivar. Un `confirmationDialog` anclado no pinta «Cancelar» (regla medida en `swiftui-ds.md`).

**D6 · L16-7, ¿qué filas se renombran?** → Las tres que señaló la auditoría: «Línea de promedio en las gráficas: Ninguna / Una / Por tramos», «Abrir el teclado en: Monto / Descripción / No abrir» y «Comparar con el período anterior». Cada bloque lleva un pie que dice dónde se ve (separando en bloques las filas que hoy comparten pie).

**D7 · L16-10** → Elegir un tema (o la variante de Traslúcido) lo aplica y la pantalla de Temas se queda abierta. El idioma ya no se elige dentro (D4).

**D8 · L16-13** → Título «Pestañas de abajo», bloque «En la barra» y pie «Panel va siempre primero. Caben 3 más Más y Buscar.»

**D9 · L16-14, ¿qué estado se enseña de Face ID?** → Pantalla «Permisos de Yala» con notificaciones, cámara, micrófono y fotos, cada uno con su estado y su botón a Configuración. **Face ID NO entra todavía**: Yala no pide permiso de Face ID (la protección es «Requerir Face ID» de iOS, que no le dice a la app si está puesta), así que no hay estado que leer ni ajuste en Configuración. Va a una card en espera de decisión con propuestas.

**D10 · L16-15** → «Valorar Yala» abre «Escribir una reseña» en la App Store (id 6758253109) y «Recomendar Yala» abre la hoja de compartir con el enlace de la App Store.

**D11 · L16-16, ¿a dónde lleva «Hacerlo ahora»?** → A la pantalla de cada tutorial (Cuentas, Categorías, Etiquetas y Favoritos dentro de Ajustes; nuevo registro, Presupuestos, Pagos planificados, Panel y Bandeja fuera, cerrando Ajustes). «Entendido» se queda como salida secundaria. Los cierres y los textos se reescriben; los vídeos se regraban en el simulador con 2.2 los que se puedan, y los que no quedan anotados en la card.

**D12 · L16-17** → Preguntas nuevas: Grupos, Yala IA, nube o iCloud, tipo de cambio, Face ID y widgets; la de «varias monedas» decía «7 monedas» (son 54) y se corrige. Pie «¿No está tu pregunta? Escríbenos» que abre el formulario de soporte.

**D13 · L16-18** → Pie bajo «Enviar» con la dirección y lo que se adjunta (versión de Yala y de iOS, modelo, tema e idioma: lo que de verdad lleva el correo).

**D14 · L16-19** → Privacidad y términos de Ajustes en la hoja de Safari dentro de Yala. Los enlaces a la privacidad de otras pantallas (consentimientos) no son de esta card.

**D15 · Notas del Welcome (A)** → Las dos notas usan la key de Ajustes (`settings.yalaAccountLinkingNote`); las dos keys viejas se retiran.

**D16 · App Attest (A)** → Los once avisos con el molde de L19-18: «Este teléfono no puede enviar cambios a … desde hace un día» + qué pasa + qué hacer.

**D17 · Quitar mis datos (A)** → En la celda sin cuenta, el aviso de los 45 s y el segundo gesto sin copia hablan de quitar («Quitar mis datos igualmente», «Si los quitas ahora…», «Quitar y borrar»). Son alertas aparte con botones literales (un botón de alerta con texto según el estado rompe la app: `swiftui-ds.md`).

**D18 · «Esa cuenta usa otro método» y consentimiento doble** → El aviso dice que este iPhone ya se usó con otra cuenta de Yala y con qué método. Al pasar de «Entrar» a «Crear cuenta» en la misma pasada, si el consentimiento ya se aceptó en esta pantalla, no se vuelve a pedir: se registra para el alta en ese momento (el alta ya escribía al aceptar) y sigue el alta. La regla vive en `CloudConsentRegistrationLogic` con test. Toca consentimiento: review adversarial.

**D19 · Tema de Pro (B)** → El tema ya no vuelve al arrancar: la hoja de fin de Pro dice «Tu tema vuelve a Liquid Glass» y vuelve al confirmar, como el icono.

**D20 · Bienvenida a Pro (B)** → Las mismas fichas de «Qué incluye Pro» del paywall.

**D21 · «1 mes gratis» (B)** → Cuando la oferta es de un mes, todo texto que hoy dice «30 días» lo dice como «1 mes» (planes, botones, Ajustes y el paso de «Primeros pasos»). Otras duraciones siguen en días.

**D22 · L20-15 (B)** → «Empezar de cero» arriba en rojo y «Seguir esperando» abajo, relleno; la alerta se presenta desde un ancla con su propio tinte para que el texto del relleno se lea (molde `AIConsentAlertModifier`).
*Revisado al implementar (2026-10-22, medido):* con el ancla de siempre el relleno sale con el texto ilegible, y con un ancla propia (`.background`, `.overlay` o un hermano 1×1) el aviso deja de presentarse (`RemoteWipeNoticeRoutingUITests` en rojo). No se cambia; la card vuelve a Jürgen con propuestas.

**D23 · «Seguridad y cuenta», ¿dividir?** → Solo inventario y recomendación con capturas y maqueta en la card, a espera de decisión. No se implementa.
