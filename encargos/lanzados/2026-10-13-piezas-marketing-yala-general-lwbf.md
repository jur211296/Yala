# Brief: Piezas de marketing Yala (inicio de marketing, Yala en general)

Sesión autónoma, sin pedir revisión antes de cerrar. Guardar todo en ~/Claude/propuestas/marketing-yala-general-2026-10-13/ con un README índice y contact sheets.

## Contexto
Yala no ha hecho marketing desde su lanzamiento. Este es el inicio. El foco es Yala en general: qué dolores ataca, cómo los resuelve y sus funciones (viejas y nuevas). NO enfocarse en 2.1.
Leer antes: brand voice de Yala del repo, ~/Claude/referencias-ui/README, ~/Claude/lola-borradores/2.1/funcionalidades-2.1.md y la carpeta marketing/ del repo.

## Feedback de Jürgen (obligatorio)
- Línea de diseño: fondo navy, brillos rosa/azul/teal, titular blanco con una palabra subrayada, pill tag (FUNCIONALIDAD / TIP YALA, etc.), logo "yala" blanco abajo a la izquierda.
- Sobre el navy, las capturas van SIEMPRE en tema dark o liquid glass. Nunca tema light sobre navy.
- Nada de colores ajenos a Yala (la dirección B "Cada cosa, su color" queda descartada).
- CERO repetición: variar el ángulo del iPhone, cómo entra, el encuadre, el layout y las frases de una pieza a otra.
- Las frases siguen el brand voice de Yala.
- Todo peruano: montos en soles (S/), nombres, lugares, comercios y recibos peruanos (Yape, Plin, bodega, menú, Tottus, Wong, BCP, Interbank, etc.).
- Tamaños fijos: feed de IG 1080×1350 (4:5), reels y stories 1080×1920 (9:16), posts de X 1600×900 (16:9).

## Entregables
1. Mapa de dolores a funciones (md): 6 a 8 dolores reales del usuario peruano y la función de Yala que resuelve cada uno.
2. 8 a 10 posts para el feed de IG (4:5) con su versión para X (16:9), todos distintos entre sí.
3. Guion de un reel de "problema a solución" de 30 s al estilo Hey Ciro: gancho con el dolor ("¿A dónde se fue tu plata este mes?"), "Hasta que llegó Yala", 3 funciones y cierre que responde el gancho. Con texto en pantalla y voz en off escena por escena.
4. Una plantilla de reel por función, también de 30 s: etiqueta, titular, demo real de la función grabada en el simulador (dark) dentro de un marco navy con una frase arriba por escena, y cierre con el logo. Hacer un piloto renderizado (registro por voz o por captura) con HyperFrames, sin voz final (texto de la voz en off aparte; la voz se hará luego con ElevenLabs).
5. README con la tabla de piezas, los tamaños y las rutas.

## Restricciones
- Un solo simulador. No usar el simulador entre las 9 y las 11 (hora de Lima).
- Sin deploy, sin secretos, no publicar nada.
- Card: «Piezas de marketing Yala general» en Yala/marketing.

## Herramienta extra a probar (añadido 2026-10-13 08:40)
Probar snapcn (Shadcn Labs, gratis y open source, https://x.com/shadcnlabs/status/2109633034396090728): más de 100 componentes de Remotion para títulos animados, subtítulos, mockups de dispositivo y escenas completas. Se instala con el CLI de shadcn. Hacer el piloto del reel por función también con snapcn (marco navy, capturas dark) y comparar con HyperFrames en el README: calidad, variedad de entradas del iPhone y tiempo.


## Reglas de esta sesión (2026-10-13)
Card: tablero-piezas-de-marketing-yala-general-lwbf (Yala/marketing). Totalmente autónoma: nunca AskUserQuestion ni preguntas, y sin pedir revisión antes de cerrar; decide tú. Como máximo 1 simulador y `xcrun simctl shutdown all` al terminar. NINGÚN simulador antes de las 11:00 Lima: empieza por el trabajo que no lo necesita. Nada publicado ni subido a redes ni a App Store Connect. PR a 2.1 solo si cambian ficheros del repo. Cierra con /cerrar-total.

## Paso 0 — decisiones (resueltas en autónomo, bypass)

1. **Dónde vive la entrega:** `~/Claude/propuestas/marketing-yala-general-2026-10-13/`, fuera del repo, como pide el brief. En el repo solo entra este encargo con su Paso 0: no se toca `marketing/` (plantillas, marca y Remotion siguen como están; el piloto de snapcn se hace en una copia aislada del estudio).
2. **Qué se anuncia:** solo lo que está en la build publicada (2.0.x, ficha viva). Cada pieza lleva una columna «build mínima»; las que enseñan algo de 2.1 (varias capturas, PDF por páginas, tipo de cambio, iPad, exportar gratis) quedan marcadas «esperar a 2.1» y no se programan antes. Las capturas salen del código de hoy (UI de 2.1); se dice en el README.
3. **Capturas:** simulador iPhone 17 Pro, **Yala Dev sin tocar código**, apariencia oscura y `userTheme 2` (Oscuro), semilla `realista` (vida personal en soles) y `grupos` (Viaje a Cusco). Nunca tema claro sobre navy. Se compila el esquema tal cual para lanzarlo, como hizo el piloto de la pizza; si algo pidiera tocar código o esquema, se le pide a Frank y no se hace aquí.
4. **Lo peruano:** montos en S/, nombres, lugares y comercios peruanos en titulares, frases y voz en off. **Sin logos ni recibos imitados de marcas reales** (Yape, BCP, Tottus…): se nombran en el texto, no se dibujan. Las pantallas enseñan lo que trae la semilla, no se retocan.
5. **«Plata»:** el brand voice prefiere «dinero», pero permite lo local en redes segmentadas (§2.3). Se usa «plata» solo en el gancho del reel, que es frase de Jürgen; el resto dice «dinero».
6. **Pro:** voz y escaneo son Pro. Ninguna pieza dice «gratis» de algo que es Pro.
7. **Cifras:** ninguna de negocio (usuarios, descargas, ahorro medio). Los montos de ejemplo son ilustrativos y salen de la semilla o de la escena.
8. **Piloto de reel por función:** registro por voz con `-uitest-voice-result two` (la hoja real, sin micro ni red). Se graba con `simctl` desde las 11:00 Lima; HyperFrames fijado en 0.8.138 y, si su render se cuelga, `capturar.mjs` del piloto anterior. Sin voz: el texto de la voz en off va aparte para ElevenLabs.
9. **snapcn:** MIT, se instala con `npx shadcn add @snapcn/…` en una copia del estudio Remotion en la carpeta de entrega; mismo guion y mismo footage que el piloto de HyperFrames, para comparar calidad, entradas del iPhone y tiempo.
10. **Reel «problema a solución»:** se entrega guion (texto en pantalla + voz en off por escena). No se renderiza: el brief pide el guion y la plantilla por función es la que lleva piloto.
11. **Franja del simulador:** a las 9:45 Jürgen escribió en la sesión «Usa el simulador, no esperes». Se usó antes de las 11:00, con un solo simulador (iPhone 17 Pro) y apagado al terminar.
