# Editar con HyperFrames 4 reels verticales de lanzamiento de Yala a partir de las grabaciones S/ 1,500 (REEL 1 urgente, hoy)

> Segundo intento. El primero arrancó el 20-oct a las 06:05 y Jürgen lo canceló a las 06:13 porque corría en paralelo con otra sesión de código. En `~/Claude/propuestas/marketing-lanzamiento/reels/_fuente/` (footage, plantilla, reels, tiras) quedó lo que preparó ese intento: revísalo y reutiliza lo que sirva en vez de empezar de cero. Ahora no hay otra sesión de código, render ni marketing en la Mini. La única viva es `Yala--qa-guiado-2-1-tf17`, un QA guiado con Jürgen en sus dispositivos que no usa simulador: no la toques.
## Contexto
Pedido de Lola (marketing), aprobado por Jürgen. Ya existen grabaciones terminadas de la persona con sueldo de S/ 1,500 (cifras del 20-oct-2026) y hubo pruebas previas con HyperFrames el 13-oct cuyo estilo gustó. Hay que convertir las grabaciones en reels con ese mismo estilo.

Fuentes (rutas reales en la Mini):
- Grabaciones S/ 1,500 (claro y oscuro): `~/Claude/propuestas/marketing-lanzamiento/grabaciones/`
  - `04-panel-presupuestos-planificado-{claro,oscuro}.mp4` → REEL 1 (Panel, presupuestos, pagos planificados)
  - `01-yala-ia-{claro,oscuro}.mp4` → REEL 2
  - `02-grupos-{claro,oscuro}.mp4` → REEL 3
  - `03-voz-{claro,oscuro}.mp4` → REEL 4
  - Descripción de cada grabación: `~/Claude/propuestas/marketing-lanzamiento/README.md`
- Pruebas HyperFrames de referencia (estilo a copiar):
  - `~/Claude/propuestas/reels-hyperframes-v3-2026-10-13/` (README, `plantilla/base/` con hyperframes.json, `reels/{ia,voz,foto}/` con `*.mp4`, `*-pop.mp4`, `*-walking.mp4` y sus `_build/`)
  - `~/Claude/propuestas/reels-hyperframes-v2-2026-10-13/_fuente/hyperframes/{base,ia,voz,foto}/`
  - `~/Claude/propuestas/reels-hibrido-2026-10-13/{ia,voz,foto}/hyperframes.mp4` y `_fuente/hyperframes/`
  - `~/Claude/propuestas/hyperframes-2026-10-13/proyecto/yala-lanzamiento/` (proyecto original)
  - `~/Claude/propuestas/marketing-yala-general-2026-10-13/04-reel-por-funcion/hyperframes/reel-voz/` y `salida/reel-voz-hyperframes.mp4`
  - Encargo del piloto: `~/Claude/tmp-frank/marketing-piloto-hyperframes-4m2k.md`

## Qué se pide
Editar con HyperFrames, mismo estilo que las pruebas: teléfono que gira y se mueve, animaciones, textos que entran desde distintos lados, y SIEMPRE cierre con la marca Yala.
- Vertical 1080×1920, entre 15 y 25 s, SIN música ni audio (pista de audio ausente o muda).
- Solo las grabaciones S/ 1,500 de arriba (elige claro u oscuro según se vea mejor; coherente entre reels).
- Salida en `~/Claude/propuestas/marketing-lanzamiento/reels/`: un mp4 y un póster (frame jpg/png) por reel. Fuente del proyecto HyperFrames en `reels/_fuente/`.

Orden:
1. REEL 1 — URGENTE, se entrega primero. Tema general Yala: panel, presupuestos y pagos planificados (`04-panel-presupuestos-planificado`). Textos en pantalla, literales y en este orden:
   «Cobras S/ 1,500 al mes.»
   «Llega el 20 y te preguntas: ¿y la plata?»
   «No es que no alcance. Es que no la estabas viendo.»
   «Ponle un tope a cada gasto.»
   «Y mira qué pagos vienen antes de que lleguen.»
   Luego cierre de marca Yala.
2. REEL 2 — `01-yala-ia`: Yala IA. Nunca escribir «OpenAI».
3. REEL 3 — `02-grupos`: sin «gratis» y sin viajes/paseos.
4. REEL 4 — `03-voz`.
Para los reels 2 a 4, elige textos cortos coherentes con el tono de Yala (cercano, español neutro peruano, tuteo, sin jerga técnica).

En cuanto el REEL 1 esté renderizado y verificado (duración 15–25 s, 1080×1920 con ffprobe, sin audio, textos legibles revisando frames, cierre de marca presente), escribe `~/Claude/propuestas/marketing-lanzamiento/reels/REEL1-LISTO.txt` (ruta del mp4, póster, duración) y manda el aviso/cierre habitual de Claude para que Frank se entere. Luego sigue con los otros tres.

## Qué NO hay que tocar
- NO simulador, NO xcodebuild, NO dispositivos de Jürgen.
- No tocar los ficheros sin commitear de `~/Yala` ni las grabaciones originales (solo leerlas).
- No tocar tmux de otras sesiones (en especial `Yala--lote-decidido-2-2-07-yala-ia`).
- No hace falta PR salvo que el encargo .md vaya a encargos/lanzados según la práctica habitual.

## Cómo se sabe que está bien
4 mp4 + 4 pósters en `marketing-lanzamiento/reels/`, cada uno vertical 1080×1920, 15–25 s, sin audio, textos legibles, cierre Yala; REEL1-LISTO.txt escrito al terminar el primero. Al final, /cerrar-total.

- Esta sesión corre SOLA en la Mini (nunca en paralelo con otra sesión Yala).


## Extra (Lola, con OK de Jürgen): bento Yala estilo Apple — misma sesión, después de los reels
Bento tipo keynote/apple.com: tarjetas redondeadas en cuadrícula, mucho aire, tipografía SF grande, fondos claros con degradados suaves, iPhone en mano o mockup, tarjeta central con logo Yala. Tarjetas (función: título):
- Panel: «Tu mes, de un vistazo»
- Apple Pay automático: «Pagas con Apple Pay. Yala lo anota.» (con la notificación)
- Yape: «¿Yapeaste? Comparte la constancia.»
- Yala AI: «¿Llego a fin de mes?»
- Voz: «Dícelo y listo»
- Grupos: «Cuentas claras en el depa»
- Presupuestos: «Un tope para cada gasto»
Prohibido: «gratis», «Beta», viajes, multimoneda como novedad. Datos en soles, demo S/ 1,500.
Entregables en ~/Claude/propuestas/marketing-lanzamiento/bento/: estático 1080×1350 (IG), 1600×900 (X) y, si alcanza, animado ~10 s en HyperFrames con tarjetas en cascada. Referencia: bento de Basil (si está en ~/Claude/propuestas/marketing-lanzamiento/ úsalo; si no, sigue la descripción).

## Paso 0 (decisiones de la sesión)

Auto-contestadas, MODO AUTÓNOMO, de día:

- **Reutilizar el primer intento.** De `reels/_fuente/` sirvieron las tomas a 30 fps (`footage/cfr-*`) y la plantilla v3 copiada. Se adapta la copia: sin músicas (`reel.sh` quita cualquier pista de audio y saca el póster), frases que entran por lados distintos y una tarjeta «destacado».
- **Claro u oscuro.** Oscuro en los cuatro: casa con el fondo navy de la serie del 13-oct y sale coherente entre reels. El bento, en claro (lo pide «fondos claros»).
- **REEL 1 con 5 frases.** La plantilla avisa a partir de 4 escenas; las frases son literales del encargo, así que se aceptan 5, con el tamaño ajustado para que quepan en 2-3 líneas.
- **«plata».** La guía de la serie dice «dinero», pero la frase del REEL 1 es literal del encargo: se respeta. En los reels 2-4 se escribe «dinero».
- **Tarjetas «destacado».** Solo repiten cifras que ya se ven en la toma (S/ 342 de la respuesta de Yala IA, Te deben S/ 220 del balance, Almuerzo S/ 25.00 de «Esto entendí»).
- **Bento.** «Díselo» y no «Dícelo» (ortografía). «Yala IA», como en la app. Yape: sin logo ni pantalla inventada, solo constancia → icono de Yala. Sin mano: no hay foto libre en el material; va el mockup.
- **Sin simulador, sin xcodebuild, sin tocar las grabaciones.** Todo sale de las grabaciones y capturas ya hechas.
- **Entrega.** Este fichero es lo único del repo que cambia: PR con auto-merge.

## Resultado

- **REEL 1** — `~/Claude/propuestas/marketing-lanzamiento/reels/reel1-panel-presupuestos-planificados.mp4` (24,4 s) + póster. Los 5 textos en orden y cierre yala. `REEL1-LISTO.txt` escrito y aviso enviado a las 10:06.
- **REEL 2 Yala IA** (18,3 s), **REEL 3 Grupos** (20,5 s), **REEL 4 Voz** (24,0 s), cada uno con póster. Sin «OpenAI», sin «gratis», sin viajes.
- Los cuatro, medidos con ffprobe: 1080×1920, 30 fps, solo pista de vídeo. Revisados en tiras de contacto fotograma a fotograma: frases legibles, ninguna se cruza y el cierre está en todos.
- **Bento** — `bento/out/bento-ig.png` (1080×1350), `bento/out/bento-x.png` (1600×900) y `bento/out/bento-animado-1080x1350.mp4` (10 s, HyperFrames, tarjetas en cascada, sin audio).
- Fuentes: `reels/_fuente/` (plantilla, `reel.json` de cada reel, tiras) y `bento/_fuente/` (`gen.py`, `hf/`). README en `reels/` y `bento/`.
