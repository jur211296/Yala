# Brief: Reels Yala, versión híbrida (HyperFrames + animaciones snapcn)

Sesión autónoma, sin revisión antes de cerrar. Salida en ~/Claude/propuestas/reels-hibrido-2026-10-13/ con un README.

## Contexto
Partir de ~/Claude/propuestas/marketing-yala-general-2026-10-13/ (README, 03-reel-problema-solucion.md, 04-reel-por-funcion/). A Jürgen le gustaron los posts. En los reels le gustan más las animaciones de texto y las transiciones de snapcn, pero quiere el iPhone continuo de HyperFrames.

## Qué hacer
1. Reel por función de registro por voz, versión híbrida: el iPhone continuo con las cámaras de HyperFrames, más el estilo de animación de snapcn (text reveal, transiciones, ritmo) reimplementado en la composición de HyperFrames con GSAP, o bien con un iPhone persistente en Remotion usando los componentes free de snapcn, lo que salga mejor. Debe mantener la palabra subrayada de la marca y titulares de dos líneas.
2. Reel de problema a solución, «¿A dónde se fue tu plata este mes?», de 30 s en 1080×1920, renderizado completo según 03-reel-problema-solucion.md, con el mismo estilo híbrido.
3. Un segundo reel por función: foto a la boleta.
Todo con capturas dark, en soles, con escenas peruanas, siguiendo el brand voice, sin repetir entradas del iPhone entre reels y sin audio (la voz va después con ElevenLabs; dejar el texto de la voz en off con sus tiempos).
Usar solo los componentes gratis de snapcn (no hay Pro comprado).

## Restricciones
Un solo simulador, y nada de simulador entre las 9 y las 11 (hora de Lima). No publicar nada. Sin deploy y sin secretos.

## Prueba de snapcn Pro (añadido 2026-10-13 11:14)
Jürgen decide si compra snapcn Pro (anual, $129) según esta prueba. snapcn regala un componente Pro, Manifesto, a cambio de un correo confirmado (https://snapcn.dev/docs/pricing#free). Si para conseguirlo hace falta registrarse o confirmar un correo, NO lo hagas: déjalo anotado en el README y sigue. Si se puede instalar sin cuenta, úsalo en uno de los reels. En todo caso, mira los demos públicos de los componentes Pro de dispositivos (https://snapcn.dev/docs/screens: Phone Pitch, tap-through, focus-pull, etc.). En el README, deja un veredicto concreto: qué mejoraría Pro frente a lo gratis y frente al híbrido con HyperFrames, con capturas de esos demos.

## Manifesto ya conseguido (añadido 11:15)
El componente Pro gratis Manifesto ya está confirmado. Se instala en el proyecto Remotion con:
npx shadcn@latest add https://snapcn.dev/api/pro-sample/62988728-d4a7-4d8b-baab-b16a2b8ceb05.DYlmdrbM5hT84BABObNYAvhUqgJsLH12
(es un enlace personal: no lo pongas en el repo ni en commits). Úsalo en uno de los reels, por ejemplo en el gancho o el cierre del de problema a solución, y compáralo en el README.

## CAMBIO DE ALCANCE (Jürgen 2026-10-13 11:16 Lima) — reemplaza la lista de 3 reels
Hacer 3 dolores, y CADA uno en DOS versiones para comparar lado a lado (6 reels en total):
1. IA de Yala (preguntarle a Yala por tu plata / insights).
2. Registro por imagen (foto de boleta peruana).
3. Registro por voz.
Versión A: HyperFrames (iPhone continuo). Versión B: snapcn con el componente Pro Manifesto + componentes free (lo más cercano a Pro posible).
Mismo guion, voz y música por par; solo cambia el motor. Reglas de siempre: navy, pantallas dark/liquid glass, soles y todo peruano, 1080×1920, texto arriba estilo Ciro, sin repetir ángulos ni entradas.
Salida: ~/Claude/propuestas/reels-hibrido-2026-10-13/{ia,foto,voz}/{hyperframes,snapcn-pro}.mp4 + hoja comparativa y veredicto Pro en el README.


## Reglas de esta sesión (2026-10-13 13:55 Lima)
Card: tablero-reels-yala-hibridos-hyperframes-snapcn-02o8 (Yala/marketing). Totalmente autónoma: nunca AskUserQuestion ni preguntas, sin revisión antes de cerrar; decide tú. Como máximo 1 simulador y `xcrun simctl shutdown all` al terminar. Nada publicado ni subido a redes ni a App Store Connect. PR a 2.1 solo si cambian ficheros del repo. Cierra con /cerrar-total.

## Paso 0 — decisiones (resueltas en autónomo, bypass)

1. **Manda el cambio de alcance de las 11:16:** seis reels, tres dolores (IA, foto, voz) × dos motores. El reel «problema a solución» deja de ser entregable; su gancho y su lenguaje alimentan el reel de IA («¿A dónde se fue tu plata?» es justo la pregunta que se le hace a Yala IA).
2. **Mismo guion por par, motor distinto.** Un `guion.json` por dolor lo leen los dos motores: mismas frases, tiempos, cámaras y toma. Así lo que cambia es solo el motor. Entre dolores, ninguna cámara ni entrada del iPhone se repite.
3. **Versión A (HyperFrames 0.8.138):** iPhone continuo de la plantilla anterior + el lenguaje de snapcn reimplementado en GSAP (revelado por palabra con desenfoque, golpe de palabra, subrayado que se dibuja, transiciones de barrido). **Versión B (Remotion 4.0.523 + snapcn):** componentes free + Manifesto (Pro) en gancho y cierre, con el teléfono de snapcn **persistente** (una sola instancia movida por una cámara propia), que es lo más cercano a Phone Pitch sin comprarlo.
4. **Tomas:** voz = la de esta mañana (`demo-voz.mp4`, mismo hook); foto = `-uitest-image-result one` (recibo de ejemplo de la app); IA = Yala IA no contesta en el simulador (comprobado), así que la toma enseña lo real sin red: presentación, elección de tono con su vista previa, preguntas sugeridas y Estadísticas; ninguna frase promete una respuesta que no se ve. Yala Dev compilado tal cual en el simulador, sin tocar código ni esquema. Si una toma enseña datos que parecen reales, se repite o se encuadra fuera; no se retoca.
5. **Sin audio.** Voz en off por escena con sus tiempos en cada `guion.md`; la música se elige con la voz (una por par).
6. **Manifesto** se instala desde el enlace personal en la copia del estudio fuera del repo; el enlace no se escribe en ningún fichero.
7. **Repo:** solo entra este encargo con su Paso 0. Todo lo demás vive en `~/Claude/propuestas/reels-hibrido-2026-10-13/`.
