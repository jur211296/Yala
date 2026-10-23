# Estilo oficial de video de Yala y regenerar todo el material de lanzamiento de 2.1

## Contexto
La guía de estilo de video (~/Claude/propuestas/marketing-lanzamiento/estilo/guia-estilo-yala.md) y la prueba estilo/reel2-estilo-final.mp4 salieron de la sesión de portadas y reels (PRs #572, #573, #575). Jürgen la aprobó el 20-oct con un cambio, y Lola mandó la lista completa de piezas para la publicación de 2.1. El encargo completo, con la decisión de Jürgen y la lista de Lola, está aquí abajo copiado del brief ~/Claude/tmp-frank/estilo-oficial-regenerar.md (léelo también).

# Encargo: estilo oficial de video Yala y regenerar todo el material
Decisión de Jürgen (20-oct 14:21):
1. Le gusta la última versión (guía estilo/guia-estilo-yala.md + estilo/reel2-estilo-final.mp4) PERO quitar los degradados rosa y morado. Proponer un degradado/acento coherente con la paleta de Yala sin rosa ni morado.
2. Con ese cambio, la guía pasa a ser el ESTILO OFICIAL para todo y reemplaza a la serie del 13-oct. Actualiza la guía (sin rosa/morado) y márcala como oficial.
3. Regenerar TODO el material de marketing de lanzamiento con el estilo oficial: los 4 reels en español e inglés (reel 4 en 18-20 s), portadas 3:4 y 9:16, bento (IG, X, animado), vista previa vertical 886×1920 y horizontal 1920×886 de App Store (15-30 s, pista AAC en silencio). Sin audio en los reels. Cierre estándar de Yala.
4. Copy en inglés: queda «Your finances, effortlessly.» en todos lados (adverbio correcto tras la coma). Corregir la ficha de App Store en inglés donde diga «effortless» para que coincida.
Reglas: de las referencias se toma CÓMO muestran las funciones, solo funciones que Yala ya tiene. Nada de «gratis», «Beta» ni «OpenAI». Ruta: ~/Claude/propuestas/marketing-lanzamiento/. Va SOLA en la Mini. Puede usar simulador. /cerrar-total. Al cerrar avisar a Lola.

5. ANTES DE LANZAR: sumar la lista completa de piezas para la publicación de 2.1 que mande Lola (pedida 20-oct 14:22). No lanzar sin esa lista.

## LISTA COMPLETA DE LOLA (20-oct 14:22) — reemplaza el punto 3; es el alcance definitivo
Común: estilo oficial sin rosa ni morado. Cierre fijo en navy con logo yala centrado, «Tus finanzas, sin esfuerzo.» / «Your finances, effortlessly.» y badge App Store (ES/EN). 15–25 s, poco texto, sin «paso 1/2», sin cortar el iPhone. Reels sin audio (Lola pone música y voz).
REELS 1080×1920 H.264 30 fps, lo importante dentro del recorte 3:4 central:
1. Panel ES+EN 20–24 s. 2. Yala IA ES+EN 18–20 s, gancho pregunta + respuesta con número. 3. Grupos ES+EN 18–22 s, sin «gratis» ni «Beta». 4. Voz ES+EN 18–20 s, huecos de 2–3 s entre beats para voz, sin tramos muertos largos.
8 mp4: reels/reelN-es.mp4 y reels/en/reelN-en.mp4.
PORTADAS: 1080×1440 y 1080×1920 de cada reel, ES y EN = 16 jpg.
BENTO (funciones de 2.1, con «Díselo y listo»): bento-ig.png 1080×1350 ES; bento-x.png 1600×900 ES y EN; bento-animado.mp4 1080×1350 8–12 s ES + versión 1600×900 EN.
APP STORE: vista previa iPhone 6.9" vertical 886×1920 y horizontal 1920×886, 15–30 s, 30 fps, pista AAC silenciosa; un juego ES (es-MX/es-ES) y otro EN (en-US/en-GB). Grupos EN MOVIMIENTO, no pantalla fija (si falta semilla con grupo, créala; esta sesión va sola y puede compilar y usar simulador).
THREADS: reusa reels y bento IG.
Guardar en reels/, bento/ y estilo/ de marketing-lanzamiento, más LISTA-FINAL.txt. Si algo no entra, decir qué quedó fuera.

OK de Jürgen (20-oct 14:23): puede hacer builds nuevos, semillas o casos de test nuevos y simuladores nuevos si hace falta. Lo primordial es que el material de marketing salga lo mejor posible. Prioriza calidad sobre rapidez.

## Qué NO hay que tocar
Solo funciones que Yala ya tiene. Nada de «gratis», «Beta» ni «OpenAI». No toques web/ ni la ficha salvo la corrección de «effortless» del punto 4. Las semillas, casos de test o builds nuevos que hagan falta para grabar van en tu rama y salen en tu PR sobre origin/2.1 (si no tocas código, no hace falta PR).

## Mini y build
Esta sesión va sola en la Mini salvo la sesión de QA guiado de 2.1 (solo QA, con el iPhone de Jürgen): no toques su simulador ni el iPhone 17 Pro compartido, crea el tuyo. Pipeline serial: limpiar, build con xcodebuild -jobs 2 sin sim booteado, bootear 1 sim, grabar o testear, apagar y borrar ese sim. Al lanzar y al cerrar borra tu DerivedData y las cachés de XcodeBuildMCP de worktrees que ya no existen, sin preguntar. No esperes el CI de ningún PR: si abres PR, haz git fetch y rebase sobre origin/2.1 justo antes.

## Cómo se sabe que está bien
Todas las piezas de la lista de Lola en reels/, bento/ y estilo/ de ~/Claude/propuestas/marketing-lanzamiento/, con las medidas, duraciones e idiomas pedidos, más LISTA-FINAL.txt con cada archivo, sus medidas y duración, y lo que haya quedado fuera y por qué. Guía marcada como oficial y sin rosa ni morado. Capturas o fotogramas de antes y después en capturas/ del worktree para el digest. Prioriza calidad sobre rapidez. Al terminar, /cerrar-total.

## Paso 0 (Frank, 2026-10-20, sin nadie delante: decisiones asumidas)

1. **Degradado oficial, uno solo para todo:** teal `#3BD6F0` → azul `#6164EB`, los dos acentos de marca que no son rosa
   ni violeta (el azul es el del post diario y el `AccentColor` de la app; su tono es 239°, azul). El halo usa los
   mismos dos. Se quita «un degradado por función»: con dos colores, la función la cuenta la frase, no el color.
2. **El logo no se toca.** Su barra rosa y el destello son la marca, no un degradado del estilo. Lo mismo el ícono.
3. **Cierre:** placa navy `#0F172A` (Lola), logo centrado, lema palabra a palabra con «esfuerzo» / «effortlessly» en el
   degradado oficial y la insignia del App Store en su idioma.
4. **Recorte 3:4:** en 1080×1920 la frase, el teléfono entero, las tarjetas, el gancho y el cierre caben en y=240-1680.
   El teléfono baja de tamaño para que quepa entero.
5. **Reels en español:** las grabaciones que ya hay (persona de S/ 1,500, 6,9", tema oscuro). Textos reescritos con la
   guía (≤ 6 palabras por frase, gancho pregunta + cifra donde la toma da la cifra). Sin «plata».
6. **Reels en inglés con la app en inglés.** Con la toma española dentro del teléfono el reel inglés enseña la app en
   español. Se graban tomas nuevas en inglés con la semilla de la ficha en dólares (la de la ficha en-US/en-GB), y los
   textos salen de sus cifras.
7. **Vista previa del App Store:** tomas nuevas con los datos de la ficha, ES en soles y EN en dólares, cuatro escenas
   (Yala IA, foto, voz, Grupos), Grupos con toque y pantalla que se mueve. El teléfono está desde el primer fotograma
   (Apple pide que la vista previa enseñe la app); el gancho es la frase sobre el teléfono. Pista AAC estéreo muda.
8. **Semilla:** `-uitest-seed-marketing` sobre la semilla `ficha`: los grupos pasan a «Depa compartido» y «Almuerzos
   de la oficina» (en/pt-BR en su idioma), sin viajes, y el presupuesto de mascota pierde el nombre propio. Va en el PR.
9. **Build:** una sola, Yala Dev (Debug-Dev), para que Yala IA conteste de verdad contra staging. Simulador propio
   «Yala Frank Marketing» (iPhone 17 Pro Max, iOS 27.0), que se borra al cerrar.
10. **Bento** en el estilo oficial: fondo oscuro, pantallas en tema oscuro. Sin Yape (la guía prohíbe su nombre):
    esa tarjeta pasa a otra función que ya está en la app. EN con capturas de la app en inglés.
11. **Ficha:** `ficha-app-store/textos/en.js`, cierre del vídeo a «Your finances, effortlessly.». La app y la web
    también dicen «effortless.»: fuera del encargo, va en Encontrado.

## Resultado

Todo en `~/Claude/propuestas/marketing-lanzamiento/` con `LISTA-FINAL.txt` (medidas, duraciones y textos medidos):
8 reels (ES y EN, 18,8-21,5 s, sin audio, recorte 3:4), 16 portadas, bento IG ES, X ES y EN, animado ES 1080×1350 y
EN 1600×900 (10 s), y 4 vistas previas del App Store (886×1920 y 1920×886, ES y EN, 29,1 s, AAC mudo) con Grupos en
movimiento. Guía en `estilo/guia-estilo-yala.md`, marcada como oficial, degradado teal → azul. Lo anterior, en
`_anterior/`.

- **Reels EN con la app en inglés**: tomas nuevas en dólares (persona de la ficha), Yala IA con respuesta real.
- **Fuera:** la tarjeta de Yape del bento (la guía no deja nombrarlo; pasó a «Tómale foto a la boleta»). El banner de
  Apple Pay en inglés: el simulador no lo entregó; la tarjeta EN enseña el borrador real que deja la acción en la Bandeja.
- **Repo:** semilla `-uitest-seed-marketing` (grupos de casa sin viajes, mascota sin nombre propio) con sus tests;
  `YALA_FICHA_MARKETING=1` en el molde; `textos/en.js` del vídeo de la ficha a «Your finances, effortlessly.».
