# Vista previa de App Store de Yala 2.1, muda, 15 s, estilo de los reels HyperFrames del 20-oct

## Contexto
Pedido de Lola (marketing), con OK de Jürgen. Es el «Extra 2» del encargo de reels del 20-oct (`~/Claude/tmp-frank/reels-hyperframes-lanzamiento.md`); esa sesión cerró a las 10:15 con los 4 reels y el bento (PR #572) antes de que se sumara este extra, así que va en sesión propia.
Ya existe material de partida en `~/Claude/propuestas/marketing-lanzamiento/`:
- Reels nuevos y su fuente HyperFrames: `reels/` (README, `_fuente/plantilla/reel.mjs`, `reel.sh`, `_fuente/reels/*/reel.json`). Ese es el estilo a seguir: teléfono que gira y se mueve, textos animados que entran desde distintos lados, cierre con la marca Yala.
- Vista previa anterior (de la sesión de marketing de la madrugada): `video-vista-previa/{es,en,pt-BR}/` (`yala-preview-6.9.mp4`). Sirve de referencia de contenido, no de estilo.
- Grabaciones y capturas: `grabaciones/`, `capturas/`, y el README general.
- Referencia de estilo externa: https://x.com/zzwitz/status/2112205129231560758

## Qué se pide
Un app preview para App Store, mudo, con el mismo estilo de giros de teléfono y textos animados de los reels.
- Lo importante en los primeros 2 a 3 s: los banners de iOS 27 lo reproducen solos.
- Formato 886×1920 (preview 6.9"), 30 fps.
- Regla de Apple: los app previews duran entre 15 y 30 s. Hazlo de 15 s (no 10), con el gancho en los primeros 3 s.
- Incluye una pista de audio silenciosa (AAC estéreo) para que App Store Connect lo acepte.
- Datos demo de la ficha de la tienda, NO los de la persona de S/ 1,500.
- Español neutro peruano, tuteo, sin jerga técnica. Prohibido «gratis», «Beta», «OpenAI», viajes y multimoneda como novedad. La función se llama «Yala IA».
- Guárdalo en `~/Claude/propuestas/marketing-lanzamiento/reels/` (mp4 + póster) y deja la fuente HyperFrames en `reels/_fuente/`. Actualiza `reels/README.md` con una fila para la vista previa.

## Qué NO hay que tocar
- NO simulador, NO xcodebuild, NO dispositivos de Jürgen.
- No tocar los 4 reels ni el bento ya entregados, ni las grabaciones originales (solo leerlas).
- No tocar los ficheros sin commitear de `~/Yala` ni tmux de otras sesiones.
- Esta sesión corre SOLA como sesión Yala de render en la Mini (nunca en paralelo con otra sesión Yala de código, render o marketing).

## Cómo se sabe que está bien
Verificado con ffprobe: 886×1920, 30 fps, 15 s (entre 15 y 30), pista de audio AAC estéreo silenciosa presente. Gancho legible en los primeros 3 s revisando fotogramas, textos legibles y sin cruces, cierre Yala presente, datos de la ficha (no S/ 1,500). El encargo .md va a encargos/lanzados con su Paso 0 y su Resultado, según la práctica habitual. Al final, /cerrar-total.

## Paso 0 (decisiones de la sesión)

- **Material: las tomas del 13-oct, no las grabaciones de hoy.** Las grabaciones de `grabaciones/` y el footage de los
  4 reels son de la persona de S/ 1,500. Las tomas de la serie del 13-oct (`reels-hyperframes-v3-2026-10-13/footage/`)
  y la pantalla del grupo «Depa compartido» llevan los datos de la ficha (Disponible S/ 84,524; Pizza S/ 280; boleta
  S/ 251.81; Almuerzo S/ 25; te deben S/ 190). Son las mismas que usó la vista previa de la madrugada.
- **Cuatro escenas, Yala IA primero:** Yala IA (gancho) → foto → voz → Grupos. Grupos es pantalla fija porque no hay
  toma de Grupos con los datos de la ficha (asumido: grabar una pedía simulador, fuera de alcance).
- **Duración 15,23 s**: 11,73 s de toma + 3,5 s del cierre fijo de la serie. Queda por encima del mínimo de 15 s de
  Apple sin recortar el cierre.
- **Misma plantilla, no una copia.** `reel.mjs` gana cuatro campos opcionales (`ancho`, `camDur`, `lema`, `cierreDur`).
  Comprobado: con los `reel.json` de los 4 reels el `index.html` generado es idéntico byte a byte al de antes.
- **El lema del cierre va en dos líneas** («Tus finanzas, / sin esfuerzo.»): en una sola rozaba los bordes a 886 px.
- **Codificación de ASC** copiada de la vista previa de la madrugada (ya aceptada): H.264 High@4.0, ~11 Mbps CBR,
  AAC estéreo 256 kbps 48 kHz en silencio.
- **Referencia de X sin abrir** (asumido): el estilo a seguir son los reels del 20-oct, que el encargo nombra como
  el modelo; abrir X pedía el navegador de Jürgen.

## Resultado

- `~/Claude/propuestas/marketing-lanzamiento/reels/yala-vista-previa-6.9.mp4` y `yala-vista-previa-6.9-poster.jpg`.
- ffprobe: **886×1920, 30/1 fps, 15,23 s (457 fotogramas), H.264 High@4.0 a 10,9 Mbps; AAC estéreo 48 kHz**, con
  volumen medio y máximo de −91 dB (silencio).
- Fotogramas revisados: la frase del gancho «Escríbele a Yala IA y queda anotado.» se lee entera a los 0,8 s y la
  tarjeta «Pizza · S/ 280.00» sale a los 2,5 s. Las frases no se cruzan (cada una se va antes de que entre la
  siguiente), el cierre yala con la insignia del App Store está de 12,3 s al final. Ninguna cifra de S/ 1,500.
- Textos: «Escríbele a Yala IA y queda anotado.» · «O tómale foto a la boleta.» · «O solo dilo como te salga.» ·
  «Las cuentas claras en el depa.» + tarjeta «Te deben S/ 190» · «Tus finanzas, sin esfuerzo.». Sin «gratis», «Beta»,
  «OpenAI», viajes ni multimoneda.
- Fuente: `reels/_fuente/reels/vista-previa/` (`tomas.py`, `reel.json`), `reels/_fuente/plantilla/vista-previa.sh`,
  `reels/_fuente/footage/cfr-05-vista-previa-ficha.mp4`; tira en `reels/_fuente/tiras/vista-previa.jpg`.
  `reels/README.md` lleva su fila y cómo rehacerla.
- **Solo en español.** No se subió nada a App Store Connect.
- **Encontrado:** el chat de Yala IA enseña «HOY, 3:52 p. m.» frente al 9:41 de la barra (ya anotado en el README general).
