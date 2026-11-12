# Auditoría UX 2.2 · decidido por Jürgen · 05 · Activar la nube, migración y avisos de iCloud

Base y PR: **2.2** (no 2.1). `lanzar-sesion` te deja sobre origin/2.1: antes del primer commit haz `git fetch origin && git switch -C encargo-tmp origin/2.2` (o rebasa tu rama sobre origin/2.2) y comprueba que `git log origin/2.2..HEAD` sale vacío. El PR va contra **2.2**.

## Contexto
Jürgen respondió el 18-oct (18:41–21:18 Lima, sesión «preguntas-auditoria-ux-2-2») todas las cards de la auditoría UX 2.2 que esperaban decisión. Resumen completo: `~/Claude/entregas/Yala--preguntas-auditoria-ux-2-2/decisiones.md`. Esta sesión implementa las de abajo, que están en «ready to launch» asignadas a frank, con la decisión en la nota de cada card.
Fuentes: la card (nota = decisión; contexto con capturas), el informe del lote en `~/Claude/entregas/Yala--auditoria-ux-2-2-lote-20-tus-datos/informe.md`, el HTML `~/Claude/propuestas/auditoria-ux-2.2/auditoria-ux-2.2.html` (opciones A/B/C/D y variantes) y los «Criterios UX/UI permanentes de Jürgen» del brief madre `~/Claude/tmp-frank/auditoria-ux-flujos-2-2.md` (léelos: sin degradados, etc.). Las variantes elegidas (p. ej. «L17-2-B.png») están en `capturas/` de esa misma carpeta del lote.

## Cards de esta sesión (8)
- **L20-11** · `tablero-ui-2-2-l20-11-activar-la-nube-cuatro-pas-q680`
  UI 2.2 · L20-11 · Activar la nube: cuatro pasos antes de entrar, «Migrar» y «Activar», y la vista previa parece código
  Decisión de Jürgen: opción C, variante 2 (recomendada): consentimiento y entrada en una sola hoja con «Continuar con Apple/Google» (L20-11-B.png).
- **L20-12** · `tablero-ux-2-2-l20-12-el-consentimiento-de-la-nu-q33i`
  UX 2.2 · L20-12 · El consentimiento de la nube es un muro de texto con jerga
  Decisión de Jürgen: opción B (recomendada). Tres líneas con icono sin jerga, «Ver los detalles» y botón «Exportar una copia antes»; dentro de la hoja única de L20-11.
- **L20-13** · `tablero-ux-2-2-l20-13-los-avisos-de-la-migracion-0d7y`
  UX 2.2 · L20-13 · Los avisos de la migración: un título pegado a los bordes y un globo de ocho líneas
  Decisión de Jürgen: opción B (recomendada). Título con margen y el borrado en dos frases con «Activar sin borrar» / «Ahora no».
- **L20-14** · `tablero-ux-2-2-l20-14-la-pantalla-de-icloud-se-c-dvig`
  UX 2.2 · L20-14 · La pantalla de iCloud se contradice sin cuenta, promete revisar sin botón y enseña códigos técnicos
  Decisión de Jürgen: opción B (recomendada). Textos coherentes, «Abrir Ajustes del iPhone», sin «Revisemos…» mientras no haya botones, código solo en «Contacta con nosotros» y lista agrupada.
- **L20-15** · `tablero-ux-2-2-l20-15-datos-no-disponibles-el-bo-pm2w`
  UX 2.2 · L20-15 · «Datos no disponibles»: el botón que borra va primero en un aviso que nadie pidió
  Decisión de Jürgen: opción B (recomendada). «Seguir esperando» primero y texto que dice que se vació en otro dispositivo.
- **L20-16** · `tablero-ux-2-2-l20-16-cambiaste-de-cuenta-de-icl-aq9h`
  UX 2.2 · L20-16 · «Cambiaste de cuenta de iCloud» no ofrece exportar lo que se va a perder
  Decisión de Jürgen: opción B (recomendada). «Exportar mis movimientos» antes de «Cerrar sesión y quitarlos» y texto en dos frases.
- **L20-17** · `tablero-ux-2-2-l20-17-volver-a-icloud-pide-dos-c-gulp`
  UX 2.2 · L20-17 · «Volver a iCloud» pide dos confirmaciones que dicen lo mismo
  Decisión de Jürgen: opción B (recomendada). Una sola confirmación con lo que pasa y «No pierdes nada».
- **L20-18** · `tablero-ui-2-2-l20-18-reabrir-yala-dos-instrucci-glj5`
  UI 2.2 · L20-18 · Reabrir Yala: dos instrucciones distintas, ningún paso a paso y ningún botón
  Decisión de Jürgen: opción D, variante 3 (recomendada): lo hecho con check y el último paso destacado con el gesto en tres pasos; una sola instrucción para los tres casos (L20-18-C.png).

## Avisos de esta sesión
- L20-11 y L20-12 son una sola hoja (consentimiento + entrada con «Continuar con Apple/Google»): hazlas juntas.
- Toca sync y borrado de datos: review adversarial antes del PR (que ningún botón borre datos sin la confirmación decidida, y que «Seguir esperando» de L20-15 no deje la app en un estado sin salida).
- Nada de despliegues a producción ni cambios de esquema de CloudKit.

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

**D1 · ¿Qué hoja cambia con L20-11/12?** → Solo la de Ajustes › Dónde viven tus datos (migrar y «activar en este dispositivo»). El consentimiento del Welcome y el de Yala completo siguen con su L6-4.
Por qué: las dos cards hablan de los flujos 20.7/20.8. Alternativa descartada: tocar `CloudConsentView`, que sirve a tres contextos ya decididos.

**D2 · ¿Qué se funde?** → La hoja única sustituye consentimiento + «¿Activar la nube?» + «¿Seguro?» + «Elige cómo iniciar sesión». Tocar «Continuar con Apple/Google» registra el consentimiento (GDPR + métrica) y arranca la migración al bajar la hoja.
Por qué: es la opción C elegida («dos toques en vez de cuatro»). Alternativa descartada: conservar una confirmación detrás.

**D3 · ¿Con sesión de nube viva?** → Un solo botón, el de su proveedor («Continuar con Apple» o «con Google»), o «Continuar con tu cuenta actual» si no se sabe; nunca los dos. La nota de la tarjeta («Usarás tu cuenta de Yala actual…») se queda.
Por qué: C-7, con sesión viva no se elige método; ofrecer los dos mentiría.

**D4 · Botones de Apple y Google** → Los nativos (`ASAuthorizationAppleIDButton` tipo `.continue`, `GoogleSignInButton(purpose: .continue)`), con la misma prominencia.
Por qué: dicen «Continuar con…» como la maqueta y cumplen la 4.8. Alternativa descartada: cápsulas dibujadas a mano.

**D5 · Las tres líneas** → Las de la variante elegida (entrar desde cualquier teléfono · Yala puede ver tus datos · tu entrada es Apple o Google), sin «cifrado de extremo a extremo» (L20-12 pide sin jerga); el texto legal entero (incluidas las fotos) va en «Ver los detalles». `CloudConsentText.version` no sube: el contrato es el mismo y está a un toque.

**D6 · «Exportar una copia antes»** → Botón en la hoja, junto a la línea de la entrada: exporta todos los registros a Excel sin asistente y abre la hoja de compartir (el molde de L20-8).

**D7 · «movimientos» de las decisiones** → «registros» (L7-18, como el lote 03): «Pasarán 32 registros, 2 cuentas y 6 presupuestos», «Exportar mis registros».

**D8 · «Ver qué migraría» de la tarjeta** → Sale: su cifra vive ahora en la hoja, en letra normal. El título «Migrar a la nube» no lo toca ninguna decisión y se queda (anotado en el PR).

**D9 · L20-13** → Título «Esta cuenta ya tiene sus propios datos» con margen; el diálogo del borrado pendiente, en dos frases con «Activar sin borrar» / «Ahora no». El resto del bloqueo no cambia.

**D10 · L20-14 «Abrir Ajustes del iPhone»** → `UIApplication.openSettingsURLString` (la única vía pública: abre Ajustes, en la página de Yala) y el texto dice dónde iniciar sesión. Código técnico solo dentro del correo de «Contacta con nosotros» (en fallo y atasco); fuera «Ver detalle técnico». La pantalla pasa a `YalaSettingsList`. Sin cuenta no se pintan las dos frases que prometen iCloud.

**D11 · L20-15** → «Seguir esperando» primero y sin rol `.cancel` (con él iOS lo baja al final); mismo manejador de siempre, así que no hay estado nuevo sin salida.

**D12 · L20-16** → «Exportar mis registros» entre «Ahora no» y «Cerrar sesión y quitarlos», dentro de la misma hoja (Excel de todo, hoja de compartir); el texto, en dos frases.

**D13 · L20-17** → Una sola confirmación para «Volver a iCloud»; «Sumarlos a mis datos» lleva a esa misma confirmación (era el «¿Seguro?»). «Empezar sin ellos» conserva su «¿Borrarlos de tu iCloud?», que es otra decisión.

**D14 · L20-18, tres pantallas** → Cover del cierre de sesión, tarjeta de relanzamiento de Ajustes (ida, vuelta y vuelta cancelada) y aviso «iCloud ya disponible». Los checks dicen solo lo que es verdad en cada caso; el aviso es un `.alert` y lleva los mismos tres pasos en texto (no se convierte en hoja: tocaría la matriz de presentaciones). El relanzamiento del Welcome (L6-7) queda como está.

**D15 · Review adversarial** → Sí, antes del PR: toca el arranque de la migración, el consentimiento y dos avisos que borran.

**D16 · L20-15 «Seguir esperando» primero no cabe en una alerta** (salió al medir) → No se elige: el texto nuevo sí va, el orden queda como estaba y la card pasa a «espera decisión» con tres propuestas y capturas (A tres botones · B «Seguir esperando» abajo pero destacado, recomendada · C hoja propia).
Por qué: con `role: .cancel` iOS lo baja al final y sin él SwiftUI añade un «Cancelar» que repite al primero (medido en el simulador). Es una decisión que cambia lo que ve la persona y ninguna opción sale de la decidida.

**D17 · L20-17, el texto decidido no es verdad** → «Tus datos vuelven a vivir en este iPhone y en tu iCloud. No pierdes nada.» en vez de «Tus datos salen de la nube de Yala…»; la card va a Jürgen para que lo confirme.
Por qué: al volver, la cuenta de la nube queda en pausa por si vuelves (`reverse_complete` la congela; lo dice la propia tarjeta). Mantener la frase decidida publicaría una afirmación falsa sobre dónde están los datos.
