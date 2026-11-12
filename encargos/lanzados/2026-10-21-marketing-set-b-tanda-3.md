# TANDA 3 de 3: esta sesión hace SOLO las piezas 4, 6 y 7 del encargo de abajo (las tandas 1 y 2 ya están en la biblioteca: PR #583 y PR #585). Reutiliza la plantilla set B, las tomas de _fuente/footage y el INDICE.md que dejaron. La rama sale de origin/2.2 (si el worktree nace de 2.1, rehazla sobre origin/2.2 antes de tocar nada). Cierra sola con /cerrar-total.

# Marketing set B y biblioteca reutilizable (pedido de Lola aprobado por Jürgen, 21-oct)

Este pedido se hace en 3 tandas, cada una en su propia sesión, una a la vez. Cada sesión hace SOLO su tanda (ver el encabezado del archivo de la tanda) y cierra sola con /cerrar-total.

## Contexto
- Lola (marketing de Yala) pidió un paquete de marketing completo con un estilo nuevo, el «set B», que reemplaza el teal→azul. Jürgen lo aprobó.
- Material anterior: ~/Claude/propuestas/marketing-lanzamiento/, ~/Claude/marketing/, los reels HyperFrames (PR #572), la vista previa de App Store (PR #573), las portadas y los reels en inglés (PR #575) y la semilla de marketing del estilo oficial (PR #580). Reutiliza las fuentes (reels/_fuente, semillas, grabaciones S/ 1,500) en vez de empezar de cero.
- Antes de diseñar, mira `~/Claude/referencias-ui/README.md` y usa lo que aplique como inspiración (no copies marcas ni pantallas).

## Alcance
- El trabajo de repo va en una rama que sale de origin/2.2, con su PR contra 2.2. No se toca la rama 2.1.
- Es solo marketing. En el código de la app solo se permiten cambios en seeds de debug o de marketing, si hacen falta.
- La calidad va primero. La sesión puede crear builds, seeds, casos de prueba y simuladores si los necesita, pero nunca más de un simulador encendido a la vez.
- Se usa la app real en el simulador (nada de maquetas inventadas de pantallas).
- NO tocar los iPhones ni el iPad reales de Jürgen.
- Dependencias: la sesión arranca ya sobre origin/2.2, sin esperar CI ni merge del PR anterior; justo antes de abrir el PR, `git fetch` y un solo rebase sobre origin/2.2, y build/simulador (si aplica) una vez después. Solo si dos sesiones tocan el mismo archivo o una necesita el código de la otra, la segunda espera el merge.
- Pipeline serial (si hay build y simulador): 1) limpiar (sims muertos, DerivedData y cachés XcodeBuildMCP de worktrees cerrados), 2) build `xcodebuild -jobs 2` sin sim booteado, 3) bootear 1 sim (antes `xcrun simctl list devices booted`), 4) grabar o capturar, 5) `xcrun simctl shutdown all` y borrar ese sim. Prohibido solapar build, sim y UITests.

## ESTILO set B (nuevo, reemplaza teal→azul)
- Ningún texto con degradado.
- Fondo azul marino (navy) con estrellitas pequeñas. Las palabras clave en índigo sólido (como «set B»).
- Los reels conservan las animaciones nuevas y el halo detrás del teléfono.
- Montos en soles (S/) en ES y en dólares (US$) en EN.
- Nada de Yape ni Plin, nada de «gratis», nada de viajes.
- Cierre fijo: logo + «Tus finanzas, sin esfuerzo.» (ES) o «Your finances, effortlessly.» (EN) + badge de App Store.
- Nunca escribir «OpenAI».

## Las piezas que pidió Lola (con su numeración)
1. App Store Connect: la nueva vista previa de 6.9" (Grupos en movimiento), vertical 886×1920 y horizontal 1920×886, ES y EN, con el estilo set B. Las vistas previas de App Store llevan una pista AAC muda.
2. La imagen del evento in-app de 2.1: quitar «gratis» si aparece. No cambiar el nombre del evento. No tocar las capturas del set B, la diapositiva 6 ni el encabezado, la pieza universal ni la pieza de búsqueda del 13-oct.
3. Pasar al set B:
   - los 4 reels en ES y EN, 1080×1920 y mudos;
   - las 16 portadas en 3:4 y 9:16;
   - el bento, estático y animado: IG 1080×1350 ES, X 1600×900 ES y EN.
4. Un banco de unas 50 piezas estáticas: 25 funciones (incluidas las secundarias) con 2 textos distintos cada una, un teléfono y un texto corto por pieza. Tamaños 1080×1350 ES y 1600×900 ES y EN.
5. 4 carruseles cerrados de 6 diapositivas (portada gancho, 4 funciones, cierre), en 1080×1350 ES y 1600×900 EN. Temas:
   - registro rápido (voz, foto, Apple Pay, bandeja);
   - Panel y presupuestos;
   - Yala IA;
   - Grupos.
6. 6 reels nuevos de funciones secundarias, de 15 a 25 s, mudos, ES y EN, cada uno con portadas 3:4 y 9:16. Funciones: categorías, pagos planificados, bandeja, cuentas, recordatorios de pago, búsqueda.
7. La serie «Yala en 20 segundos»: una plantilla fija con una función por capítulo, y los primeros 4 capítulos en ES y EN.
8. El post de lanzamiento de 2.1, como imagen (1080×1350 y 1600×900) y como reel corto.

## Organización
- Todo va en una biblioteca reutilizable en ~/Claude/marketing/biblioteca/, con una carpeta por tipo (reels, carruseles, estaticos, serie, asc, lanzamiento) y dentro por función.
- INDICE.md en la raíz de la biblioteca: cada pieza con función, idioma, tamaño, fecha y estado (lista, publicada o guardada para 2.1). Cada tanda lo actualiza, no lo reescribe desde cero.
- El material viejo se mueve a ~/Claude/marketing/biblioteca/_archivo/ y nunca se borra.
- Cada tanda deja una nota PARA-LOLA (~/Claude/marketing/biblioteca/PARA-LOLA-tanda-N.md) con qué hay, dónde y qué publicar primero.
- Los binarios pesados viven en la biblioteca, no en el repo; en el repo solo van seeds, scripts o el encargo.

## Tandas (sesiones separadas; cada una cierra sola con /cerrar-total)
### Tanda 1 = piezas 3 y 5 (primero, para que Lola empiece a publicar)
- Montar la biblioteca (carpetas, INDICE.md, _archivo con lo viejo) y luego las piezas 3 y 5.
- Hecho cuando: los 4 reels ES/EN, las 16 portadas en 2 formatos, el bento estático y animado en los 3 tamaños y los 4 carruseles en los 2 tamaños están en la biblioteca, en el INDICE como «lista», con PARA-LOLA-tanda-1.md.
### Tanda 2 = piezas 1, 2 y 8
- Hecho cuando: la vista previa 6.9" vertical y horizontal ES/EN pasa las specs de App Store (dimensiones, duración, AAC mudo; verificar con ffprobe), la imagen del evento ya no dice «gratis» y el post de lanzamiento (imagen en 2 tamaños + reel corto) está en la biblioteca como «guardada para 2.1», con PARA-LOLA-tanda-2.md.
### Tanda 3 = piezas 4, 6 y 7
- Hecho cuando: el banco de ~50 estáticas (25 funciones × 2 textos, en los tamaños pedidos), los 6 reels secundarios con sus portadas y la plantilla más los 4 capítulos de «Yala en 20 segundos» ES/EN están en la biblioteca y en el INDICE, con PARA-LOLA-tanda-3.md.

## Qué NO hay que tocar
- La rama 2.1. Código de la app fuera de seeds de debug o marketing. Los iPhones y el iPad reales de Jürgen. Ninguna sesión tmux ajena. No borrar material viejo (va a _archivo).

## Cómo se sabe que está bien
- Revisión pieza por pieza contra el ESTILO set B: sin degradados en texto, sin Yape/Plin, sin «gratis», sin viajes, sin «OpenAI», moneda correcta por idioma, cierre fijo correcto, tamaños exactos (verificar con ffprobe/sips), reels mudos.
- INDICE.md completo para la tanda y nota PARA-LOLA escrita.
- Al cerrar: sims apagados y borrados, worktree limpio. El cierre de cada tanda dice que Lola recibe una nota de una línea en su 1:1.


## Limpieza (sin preguntar)
- Al lanzar y al cerrar, borra el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No toques los de sesiones vivas (sigue viva la del QA guiado de 2.1). Si el borrado falla, dilo en el cierre.
- Al terminar, /cerrar-total.

## Paso 0 (Frank, 2026-10-21) — tanda 3: piezas 4, 6 y 7

Decisiones tomadas sin preguntar (sesión lanzada; ninguna es de producto ni de acceso):

1. **Rama.** El worktree nació sobre `origin/2.1` sin commits; se movió a `origin/2.2`. En el repo solo va este encargo
   con su Paso 0 y su Resultado: plantillas, tomas y binarios viven en la biblioteca.
2. **Se graba la app 2.1, no la 2.2.** Es la versión que va a salir y la de las tandas 1 y 2; 2.2 cambia 545 ficheros
   de `Yala/` y enseñaría cosas aún no publicadas. Se compila una copia de `origin/2.1` (`git archive`) en el
   scratchpad, scheme Yala Debug, `-jobs 2`, con la copia de `SourcePackages` (sin red de SPM en el sandbox).
3. **Simulador propio y uno solo:** un iPhone 17 Pro creado para la tanda, que se apaga y se borra al cerrar. Molde
   `ficha-app-store/` de 2.1 con `YALA_FICHA_MARKETING=1` (grupos de casa, sin viajes ni nombres propios) y su reloj
   en el 13-oct-2026, tema oscuro, Pro. ES en soles (es-419, es_PE) y EN en dólares (en-US).
4. **Pieza 4 = 25 funciones × 2 textos = 50 piezas**, cada una en 1080×1350 ES, 1600×900 ES y 1600×900 EN (150 PNG).
   Un teléfono con la pantalla real de esa función y un texto corto. Las dos versiones de una función comparten la
   pantalla y cambian texto y composición (A: titular arriba; B: frase grande al lado, teléfono girado al otro lado).
   Las 25: voz, foto, Yala IA, capturas, Apple Pay, Bandeja, Panel, presupuestos, pagos planificados, recordatorios,
   cuentas, multimoneda, estadísticas, tendencias, flujo de caja, reportes, categorías, etiquetas, búsqueda, registros,
   favoritos, Grupos, reparto en Grupos, exportar y transferencias (ajustable si una no se puede fotografiar real).
   Fuera, por la guía de `marketing/funcionalidades/README.md`: la nube de Yala, el conector para Claude y la prueba de
   5 notas. «· Pro» en la pill de voz, foto, capturas y Yala IA, como en las tandas 1 y 2.
5. **Pieza 6:** 6 reels (categorías, pagos planificados, Bandeja, cuentas, recordatorios de pago, búsqueda) × ES/EN,
   1080×1920, 15-25 s, sin pista de audio, con la plantilla `reel-setb` de la tanda 1 y portadas 3:4 y 9:16 con
   `portadas-setb.py`. Tomas nuevas del simulador, una por función e idioma.
6. **Pieza 7, «Yala en 20 segundos»:** plantilla fija nueva (`_fuente/serie/`): tarjeta de capítulo («Cap. N»), barra
   de 20 s que se llena, pasos numerados 1-2-3 sobre el teléfono y el cierre fijo. Capítulos 1-4: voz, foto de la
   boleta, Yala IA y presupuestos, ES/EN, 20 s exactos, mudos. Tomas nuevas con el molde (mismos datos en toda la serie).
7. **Dólares en EN con `$`**, el símbolo que enseña la app en inglés, como decidió la tanda 1 (punto 7 de su Paso 0).
8. **Lo ya hecho no se rehace**: el INDICE se amplía con una sección «Tanda 3»; nada pasa a `_archivo/`.
9. **Bandeja y cuenta extranjera con parche de semilla local.** La semilla de marketing traía solo 2 borradores en
   español fijo (uno «Taxi aeropuerto») y en inglés la cuenta extranjera se llamaba «Travel EUR». Se parcheó solo la
   semilla `#if DEBUG` en la copia de 2.1 que se compiló (5 borradores traducidos; «Savings EUR»). No va a ninguna rama:
   el parche vive en `biblioteca/_fuente/tomas/semilla-tanda3.patch` para poder repetir las tomas.
10. **Etiquetas fuera del banco:** la semilla tiene la etiqueta «Vacaciones» con un avión (viaje); en su lugar entran
   Siri y Atajos, Face ID y temas. Las capturas de pantallas que la enseñaban (editor de pago, filtros de exportar) no se usan.

## Resultado (tanda 3, 2026-10-21)

Hecho. Todo vive en `~/Claude/marketing/biblioteca/` y figura en su `INDICE.md` como **lista** (95 filas nuevas).

- **Pieza 4 · banco de estáticas:** 25 funciones × 2 textos = 50 piezas en `estaticos/<función>/`, cada una en
  1080×1350 ES, 1600×900 ES y 1600×900 EN (150 PNG). Pantallas reales de la app 2.1 (25 por idioma).
- **Pieza 6 · 6 reels secundarios** (categorías, pagos planificados, Bandeja, cuentas, recordatorios de pago,
  búsqueda) × ES/EN en `reels/<función>/`: 1080×1920, 30 fps, 15,5-20 s, sin pista de audio, con portadas 3:4
  (1080×1440) y 9:16 (1080×1920).
- **Pieza 7 · «Yala en 20 segundos»:** plantilla fija `_fuente/serie/plantilla/` y capítulos 1-4 (voz, foto, Yala IA,
  presupuestos) × ES/EN en `serie/yala-en-20-segundos/<idioma>/`, 20,0 s exactos, mudos.
- **Fuente reutilizable:** `_fuente/tomas/` (guion de grabación con `axe`, `guiones.json`, `piezas.py` que calcula los
  tramos desde las marcas, `hacer-tanda3.sh`, README con las trampas) y `_fuente/estaticos/` (`gen.py` + textos).
- **Verificado:** `ffprobe`/`sips` (todo a medida, ningún vídeo con audio, la serie a 20,000 s); barrido de textos y
  HTML generados sin degradados en texto, Yape, Plin, «gratis», viajes ni «OpenAI»; S/ en ES y $ en EN en todos los
  textos propios; cifras de ganchos y tarjetas medidas en la pantalla de cada idioma.
- **Nota para Lola:** `PARA-LOLA-tanda-3.md` y hoja `hoja-tanda-3.jpg`.

Limpieza: simulador de la tanda borrado, DerivedData `marketing-tanda3` y caché XcodeBuildMCP del worktree de la tanda 2
borrados, y las 6 copias temporales de la app que dejó el molde (~3,4 GB) retiradas. En el repo solo cambia este encargo.
