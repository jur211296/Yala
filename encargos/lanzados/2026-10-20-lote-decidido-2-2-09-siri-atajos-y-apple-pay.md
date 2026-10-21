# Auditoría UX 2.2 · decidido por Jürgen · 09 · Siri y Atajos, frases en 16 idiomas, borradores de Siri y la guía de Apple Pay

Base y PR: **2.2** (no 2.1). `lanzar-sesion` te deja sobre origin/2.1: antes del primer commit haz `git fetch origin && git switch -C encargo-tmp origin/2.2` (o rebasa tu rama sobre origin/2.2) y comprueba que `git log origin/2.2..HEAD` sale vacío. El PR va contra **2.2**.

## Contexto
Jürgen respondió el 18-oct (18:41–21:18 Lima, sesión «preguntas-auditoria-ux-2-2») todas las cards de la auditoría UX 2.2 que esperaban decisión. Resumen completo: `~/Claude/entregas/Yala--preguntas-auditoria-ux-2-2/decisiones.md`. Esta sesión implementa las de abajo, que están en «ready to launch» asignadas a frank, con la decisión en la nota de cada card.
Fuentes: la card (nota = decisión; contexto con capturas), el informe del lote en `~/Claude/entregas/Yala--auditoria-ux-2-2-lote-15-desde-fuera/informe.md`, el HTML `~/Claude/propuestas/auditoria-ux-2.2/auditoria-ux-2.2.html` (opciones A/B/C/D y variantes) y los «Criterios UX/UI permanentes de Jürgen» del brief madre `~/Claude/tmp-frank/auditoria-ux-flujos-2-2.md` (léelos: sin degradados, etc.). Las variantes elegidas (p. ej. «L17-2-B.png») están en `capturas/` de esa misma carpeta del lote.

## Cards de esta sesión (7)
- **L15-4** · `tablero-ui-2-2-l15-4-siri-y-atajos-ensena-frases-zsx1`
  UI 2.2 · L15-4 · «Siri y Atajos» enseña frases pero no deja hacer nada, y nombra las acciones distinto que Atajos
  Decisión de Jürgen (≠ de la recomendada, respétala tal cual): opción B, variante 1 (NO la recomendada D): los nombres de Atajos y un botón relleno al pie, «Abrir mis atajos de Yala» (captura L15-4-A.png).
- **L15-5** · `tablero-ux-2-2-l15-5-en-10-de-los-16-idiomas-nin-wewa`
  UX 2.2 · L15-5 · En 10 de los 16 idiomas, ninguna frase de Siri funciona
  Decisión de Jürgen: opción B (recomendada). Frases en los 16 idiomas (AppShortcuts.xcstrings). Coordinar con la sesión en curso «integrar-siri-ia-ios-27», que toca las frases de Siri.
- **L15-6** · `tablero-ux-2-2-l15-6-sin-pro-siri-dice-activa-ya-2yze`
  UX 2.2 · L15-6 · Sin Pro, Siri dice «Activa Yala Pro» y no lleva a ningún sitio
  Decisión de Jürgen (≠ de la recomendada, respétala tal cual): opción B con matiz (literal): «Creo que B es la correcta pero igual creo que los usuarios que no son pro deberían poder usar si de alguna manera quizá usando el propio modelo de Siri si lo tienen disponible que no implica gastos para nosotros y así el usuario gratis igual puedo utilizar de alguna manera inteligencia artificial». Es decir: sin Pro, Siri abre la hoja de Pro; y explorar que el usuario gratis pueda dictar a Siri usando el modelo del propio dispositivo (sin coste de servidor) cuando esté disponible. Cruzar con la sesión «integrar-siri-ia-ios-27».
- **L15-7** · `tablero-ux-2-2-l15-7-un-dictado-de-siri-no-avisa-vhat`
  UX 2.2 · L15-7 · Un dictado de Siri no avisa dentro de la app
  Decisión de Jürgen: opción C (recomendada). Línea propia «Borradores de Siri: N» en el aviso de la Bandeja.
- **L15-8** · `tablero-ux-2-2-l15-8-la-notificacion-de-apple-pa-h65m`
  UX 2.2 · L15-8 · La notificación de Apple Pay dice «Se ha registrado» algo que aún no está registrado
  Decisión de Jürgen: opción C (recomendada). «Pago de S/ X en Y por revisar · Tócalo para aprobarlo» y moneda de la última cuenta usada si llega sin símbolo.
- **L15-9** · `tablero-ux-2-2-l15-9-la-guia-de-apple-pay-descri-yu7c`
  UX 2.2 · L15-9 · La guía de Apple Pay describe el Atajos de iOS 26
  Decisión de Jürgen: opción C (recomendada). Texto único válido en iOS 26 y 27 y capturas de iOS 27.
- **L15-10** · `tablero-ui-2-2-l15-10-en-la-guia-listo-compite-c-f6g6`
  UI 2.2 · L15-10 · En la guía, «Listo» compite con «Hecho» y deja terminar sin hacer los pasos
  Decisión de Jürgen: opción C, variante 2 (recomendada): sin botón de terminar hasta el paso 4; «Te faltan N pasos · tu avance se guarda» (L15-10-B.png).

## Avisos de esta sesión
- La sesión «integrar-siri-ia-ios-27» ya cerró (PR #552 en 2.2): parte de lo que dejó (frases, intents, modelo del dispositivo) y no rehagas su trabajo. La card «Siri con IA: ¿tus cuentas y movimientos en Spotlight?…» va en su propia sesión al final de la cola: no la toques.
- **L15-4**: es la variante 1 de la opción B, NO la recomendada D: nombres de Atajos y botón relleno al pie «Abrir mis atajos de Yala» (captura L15-4-A.png del lote 15).
- **L15-6**: sin Pro, Siri abre la hoja de Pro (eso se implementa). La segunda parte es una exploración: que el usuario gratis pueda dictar a Siri con el modelo del propio dispositivo, sin coste de servidor. Mide qué permite el SDK de iOS 27; si es viable y no cambia la UI decidida, impleméntalo detrás de un flag apagado; si cambia lo que ve el usuario, deja la propuesta en una card a `jurgen` en «espera decisión» y sigue con lo demás.
- L15-5: frases en los 16 idiomas en AppShortcuts.xcstrings; comprueba en el simulador al menos en es, en, pt y de que Siri/Atajos las reconoce.
- L15-9: capturas de iOS 27 para la guía de Apple Pay (del simulador).

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
> Hechos medidos antes de decidir: `origin/2.2` en `e70e1e05b`; #552 dejó frases en pt/pt-BR/pt-PT en
> `AppShortcuts.xcstrings` y dos acciones nuevas («Cuánto gasté», «Mi saldo»); faltan de, fr, it, nl, pl, ja, zh-Hans
> (7, no 10). Un idioma con `AppShortcuts.strings` entrena SOLO lo traducido (medido por #552).

**D1 · L15-4: ¿de dónde salen los nombres?** → de las mismas claves que pinta Atajos (`shortcut.*.shortTitle`), así
casan por construcción en los 16 idiomas. Descripciones, la línea «También: «A» · «B»» y el botón relleno «Abrir mis
atajos de Yala» al pie de «Otros atajos», como en `L15-4-A.png`. Cabecera, iconos de sección, nota Pro y preguntas
frecuentes se quedan como están. Por qué: la decisión fija nombres y botón; lo demás lo resuelve lo que ya hay.
Descartado: añadir las dos preguntas de #552 a la pantalla — no está en la captura elegida; va en card aparte a Jürgen.

**D2 · L15-4: ¿adónde lleva el botón?** → a la página de Yala en Atajos si una URL lo consigue (se mide en el
simulador); si no, a Atajos (`shortcuts://`), donde Yala sale en Biblioteca › Apps. Descartado: `ShortcutsLink`, que no
admite el estilo relleno decidido.

**D3 · L15-5: ¿qué frase enseña la pantalla en cada idioma?** → la traducción de las tres claves de «Anotar con Siri»
en el mismo orden que en español (principal «Anota un gasto», alternativas «Apunta un gasto» y «Registra con Siri»), y
las de las otras filas como hoy. Cada frase enseñada está en lo que entrena Siri, con test por idioma (molde
`SiriPhrasesPortugueseTests`). Sin frases repetidas en un idioma.

**D4 · L15-6: ¿cuándo se mira Pro?** → antes de pedir el texto: sin Pro, Siri lo dice y abre Yala en la hoja de Pro de
voz (`.voice`, la que ya existe) con `continueInForeground`. Por qué: preguntar y luego tirarlo era perder lo dictado.
Descartado: una hoja de Pro nueva «de Siri» (UI no decidida).

**D5 · L15-6: el modelo del dispositivo** → se implementa detrás de un flag APAGADO (`FoundationModels`, sin servidor):
sin Pro, con el flag y el modelo disponible, Siri lee el texto en el teléfono y deja el borrador. Encenderlo cambia lo
que ve un usuario gratis, así que va en card a Jürgen en «espera decisión». Sin flag, nada cambia.

**D6 · L15-7: ¿qué aviso sale si solo hay borradores de Siri?** → el título genérico de la Bandeja («¡Nuevos registros
en tu bandeja!») y la línea «Borradores de Siri: N». Con otros tipos, su mensaje de siempre y la línea debajo. Los de
voz y foto de dentro de la app siguen fuera del recuento.

**D7 · L15-8: título y cuerpo** → título «Pago de S/ 25,90 en Tambo por revisar» (sin comercio: «Pago de S/ 25,90 por
revisar»), cuerpo «Tócalo para aprobarlo.». Moneda: la que pondrá el borrador. La app deja escrita en el App Group la
moneda de la última cuenta usada y la que resolvería `$` y `kr` con la misma regla del borrador; el atajo la lee sin
abrir SwiftData. Sin dato, la moneda por defecto del usuario.

**D8 · L15-9: capturas** → imágenes fijas de iOS 27 sacadas del simulador en «Lo que vas a ver», una por paso, en vez
de los vídeos de iOS 26. Si el simulador no deja llegar a un paso (Wallet), se dice en la card y queda para el iPhone.

**D9 · L15-10: ¿cuándo sale «Listo»?** → solo con los cuatro pasos hechos. Antes, «Te faltan N pasos · tu avance se
guarda». Y el avance se guarda de verdad (por guía, en `UserDefaults`), o la frase mentiría; se borra al terminar.
Vale para Apple Pay y Face ID, que comparten `YalaStepGuide`.

**D10 · Review adversarial** → sí, corta (dos lentes) sobre L15-6 y L15-8: tocan una notificación y la puerta de Pro.

### Paso 0 · lo que cambió al implementar

- **D2 resuelto midiendo**: ninguna URL abre la página de Yala en Atajos (cinco formas de `shortcuts://` dan «Todos los
  atajos») y `ShortcutsUIButton` no se dispara por código. El botón relleno de Yala lleva encima el de Apple,
  transparente: el toque abre «Yala» en Atajos con sus siete acciones (medido en el simulador).
- **D3 matizado**: se conservan las frases que la app ya enseñaba en cada idioma (no se reescribe copy que funciona) y
  se registran como lo que entrena Siri; donde el consejo de Siri decía otra (ja, nl), se añadió también.
- **D7 ampliado tras la review**: sin símbolo, el BORRADOR toma también la moneda de la última cuenta usada (antes
  quedaba sin moneda y la Bandeja lo enseñaba en la moneda por defecto: la notificación y la Bandeja habrían dicho
  monedas distintas). La pista guarda la moneda en que la Bandeja enseñará el borrador.
- **D8**: las capturas de iOS 27 cubren los cuatro pasos; el disparador de Wallet se puede añadir en el simulador.

## Resultado

Las siete cards implementadas como las decidió Jürgen. Frases de Siri en los 16 idiomas, textos nuevos en los 16,
`/l10n-check` limpio, review adversarial de dos lentes (L15-6, L15-8) con sus hallazgos aplicados, cuatro mutantes
muertos. Dos tickets nuevos: `siri-free-users-on-device-model-awaits-decision` (encender o no el modelo del iPhone) y
`siri-settings-screen-does-not-show-the-new-questions`.
