# Lote marketing Lola (OK Jürgen): portadas, reels en inglés y reel 4 más corto — UNA sesión corta, SOLA en la Mini
Fuentes y salidas en ~/Claude/propuestas/marketing-lanzamiento/reels/ (montajes HyperFrames del cierre PR #572). Sin «gratis», «Beta», «OpenAI» ni viajes. Sin build. Simulador solo para el punto 4 si hace falta. /cerrar-total.

1) Portadas de grid 3:4 para los 4 reels: 1080×1440, gancho y teléfono dentro de la zona segura que IG no recorta (hoy se corta arriba «Cobras S/ 1,500»). Guardar reels/reel1-portada.jpg … reel4-portada.jpg.
2) Versiones en INGLÉS de los 4 reels para X: mismo montaje y cierre, textos en pantalla en inglés natural y vendedor; cierre «Your finances, effortlessly.»; se mantienen los soles (S/); insignia de App Store en inglés. Sin audio (Lola pone la música). Guardar reels/en/reel1-en.mp4 … reel4-en.mp4.
3) Reel 4 (Voz): la pantalla «Y queda anotado» va del s 13,6 al 21 y se siente lenta. Acortarla para que el reel quede en 18-20 s, en español (re-render reel4) y en inglés. Lola montará la voz encima.
Al cerrar: avisar a Lola con una sola línea.
4) (Lola 11:21) Vista previa de App Store HORIZONTAL: 1920×886 (6.9" landscape), 15-30 s, gancho en los primeros 2 s, pista AAC estéreo en silencio, datos demo de la ficha (no S/ 1,500). Parte de yala-vista-previa-6.9 (PR #573). Grupos animado si se puede: si no hay grabación de Grupos con datos de la ficha, se puede grabar en el simulador (esta sesión corre sola); si no sale, pantalla fija y anótalo. Ref horizontal: https://x.com/zzwitz/status/2112205129231560758. Guardar reels/yala-vista-previa-6.9-horizontal.mp4.

## 5. Guía de estilo final de video (pedido de Jürgen vía Lola, 20-oct 13:06)
No copiar a nadie: tomar lo mejor de las referencias y llevarlo a la voz de Yala (vende, pero no suena genérica). Usa la función nueva de HyperFrames para dar videos de referencia: https://x.com/hyperframes_/status/2112591698476077345
Referencias:
- https://www.threads.com/share/BAJ0yaoi7d/ (bento de Basil)
- https://www.threads.com/share/BATfA6nYc_/ (Expensa)
- https://www.threads.com/share/BAlYdV4XAw/ (MyExpenz)
- https://www.threads.com/share/BAUIWkkerW/ (Tap to pay: fondo oscuro, teléfono al centro, texto con degradado)
- https://www.threads.com/share/BAggpZkifW/ (Koino: gancho con la pregunta real del usuario y respuesta con número)
- https://www.threads.com/share/_gm2CV2C3/ (varios gastos en una sola línea)
- https://www.threads.com/share/BAWZaJXTZ4/
Entregable: ~/Claude/propuestas/marketing-lanzamiento/estilo/guia-estilo-yala.md, corta. Define entrada y animación de textos, paleta y degradados llamativos, tipografía, ritmo, giros del teléfono, transiciones y cómo construir el gancho en los primeros 2 s. Siempre con el cierre estándar de Yala.

## 6. Prueba aplicada: reel 2 (Yala IA) rehecho con ese estilo
Gancho = pregunta real con respuesta en número (p. ej. «¿Cuánto gasté en delivery este mes?» y luego la cifra). Sin audio. Guardar en ~/Claude/propuestas/marketing-lanzamiento/estilo/reel2-estilo-final.mp4.

Aclaración de Jürgen (vía Lola) para los puntos 5 y 6: de las referencias se toma CÓMO muestran y promocionan las funciones, no las funciones en sí. Aplícalo solo a funciones que Yala ya tiene. No inventes funciones nuevas (por ejemplo, la de varios gastos en una sola línea).

## Paso 0 (decisiones de la sesión)

Auto-contestadas, MODO AUTÓNOMO (encargo de cola), de día:

- **Territorio.** Todo sale en `~/Claude/propuestas/marketing-lanzamiento/`, fuera del repo; no se toca `marketing/` ni la ficha publicada. Del repo solo cambia este fichero: PR con auto-merge.
- **Portadas.** Se entregan a 1080×1440 como pide el encargo y, al lado, una versión 1080×1920 con todo dentro de la franja 3:4 central (y=240-1680), por si Instagram pide la portada a 9:16 al subir el reel.
- **Inglés.** Insignia oficial «Download on the App Store» (US-UK, de developer.apple.com). «Yala AI» y «Food», como en la localización `en` de la app. Lema «Your finances, effortlessly.», literal del encargo (la ficha EN dice «effortless»: se anota).
- **Reel 4 corto.** Se acelera la toma, no se corta: «Escuchando» a 2×, «Esto entendí» a 1,25×, «Registrado → Listo» a 3× y el salto al Panel a 8×; «Últimos registros» con el Almuerzo queda a 1×.
- **Plantilla.** `reel.mjs` gana campos opcionales (`badge`, `idioma`, modo apaisado). Sin ellos, un `reel.json` sale igual que antes.
- **Vista previa horizontal.** Misma toma de la ficha que la vertical (PR #573), en composición apaisada: teléfono a un lado, frase al otro.

## Resultado

Todo en `~/Claude/propuestas/marketing-lanzamiento/`, medido con ffprobe y revisado en tiras de contacto.

1. **Portadas** — `reels/reel1-portada.jpg` … `reel4-portada.jpg` (1080×1440) + `reelN-portada-9x16.jpg` (1080×1920, mismo bloque en la franja 3:4). «Cobras S/ 1,500» ya no se corta.
2. **Inglés** — `reels/en/reel1-en.mp4` (24,4 s), `reel2-en` (18,3 s), `reel3-en` (20,5 s), `reel4-en` (18,8 s). 1080×1920, sin audio, cierre «Your finances, effortlessly.» e insignia «Download on the App Store».
3. **Reel 4** — `reels/reel4-voz.mp4` y su póster, ahora de 18,8 s (antes 24,0). «Y queda anotado» dura ~4 s.
4. **Vista previa horizontal** — `reels/yala-vista-previa-6.9-horizontal.mp4`: 1920×886, 15,2 s, H.264 High a ~11 Mbps, AAC estéreo 48 kHz en silencio. Datos de la ficha. **Grupos va como pantalla fija**: la app no tiene semilla del grupo «Depa compartido» y grabarlo pedía un build. La referencia de X no se pudo abrir (X devuelve 402 sin sesión).
5. **Guía de estilo** — `estilo/guia-estilo-yala.md`. Referencias bajadas con `hyperframes capture` (la función de vídeos de referencia de la 0.8.18x).
6. **Prueba aplicada** — `estilo/reel2-estilo-final.mp4` (17 s, sin audio): «¿Cuánto gasté en comida este mes?» se teclea y «S/ 342» entra con contador al 1,1 s; es la pregunta y la cifra reales de la toma.

Encontrado y no tocado: la ficha EN usa «Your finances, effortless.» y los reels dicen «effortlessly.» (literal del encargo); conviene unificar. La guía nueva permite degradados y halo, que la serie del 13-oct prohibía: es un cambio de criterio que decide Jürgen.
