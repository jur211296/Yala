# TANDA 1 de 3: esta sesión hace SOLO las piezas 3 y 5 del encargo de abajo. Las otras tandas van en sesiones aparte.

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

---

## Paso 0 (Frank, 2026-10-21) — tanda 1: piezas 3 y 5

Decisiones tomadas sin preguntar (MODO de sesión lanzada; ninguna es de producto ni de acceso):

1. **Rama.** El worktree nació sobre `origin/2.1`; se movió a `origin/2.2` (no tenía commits). PR contra `2.2`.
   En el repo solo va este encargo con su Paso 0 y su Resultado: las plantillas y los binarios viven en la biblioteca.
2. **Qué es «set B», medido en `capturas-app-store-final-v2-2026-10-13/_fuente/lamina.css`:** fondo navy liso
   `#0F172A`, estrellas planas de cuatro puntas (sin glow) en teal `#3BD6F0`, índigo `#6164EB` y rosa `#FF2D78` como en
   esas capturas, y la palabra clave en índigo sólido `#6164EB` con su barra de subrayado plana. La cifra del gancho va
   en blanco. El halo detrás del teléfono se queda (lo pide el encargo) en índigo; no es texto. El cierre es una placa
   navy lisa con estrellas, logo, lema con la palabra clave en índigo e insignia del App Store.
3. **Sin nueva grabación ni build.** Las tomas y capturas del 20-oct (app 2.1 real en el simulador) cubren los 4 reels,
   las portadas, el bento y los 4 carruseles en ES y EN. Compilar 2.1 para cubrir dos huecos (lista de la Bandeja en ES,
   notificación de Apple Pay en EN) costaba disco (22 GB libres) y una hora sin mejorar lo que se ve: la lámina de
   Apple Pay lleva la notificación como tarjeta flotante con el texto real de la app, como hacía el set B con sus objetos.
4. **«16 portadas»** = 4 reels × 2 idiomas × 2 formatos (3:4 1080×1440 y 9:16 1080×1920), como en el lote del 20-oct.
5. **Bento:** estático y animado en IG 1080×1350 ES, X 1600×900 ES y X 1600×900 EN = 6 ficheros.
6. **Carruseles:** 4 temas × 6 láminas × (1080×1350 ES + 1600×900 EN) = 48 PNG.
7. **Dólares en EN:** el símbolo es `$`, el que enseña la app en inglés, en pantalla y en los textos.
8. **Material viejo:** las carpetas de contenido social de `~/Claude/propuestas/` (las series del 13-oct y el lote
   oficial del 19/20-oct) se mueven a `biblioteca/_archivo/` y dejan un enlace simbólico en su ruta vieja, para que los
   scripts y las tandas 2 y 3 sigan encontrando sus fuentes. Las de App Store Connect (`capturas-app-store-*`,
   `assets-asc-*`, `ficha-app-store-2.1`) no se tocan: son la ficha vigente.
9. **Los textos de los reels no cambian** (están aprobados y pasan la guía); solo cambia el estilo.

## Resultado (tanda 1, 2026-10-21)

Hecho. Todo vive en `~/Claude/marketing/biblioteca/` y figura en su `INDICE.md` como **lista** (38 filas).

- **Biblioteca montada:** `reels/`, `carruseles/`, `estaticos/`, `serie/`, `asc/`, `lanzamiento/`, `_fuente/` y
  `_archivo/`. Siete carpetas de contenido social de `~/Claude/propuestas/` se movieron a `_archivo/` y dejaron un
  enlace simbólico en su ruta (nada se borró). Las de App Store Connect siguen donde estaban.
- **Pieza 3:** 4 reels × ES/EN en `reels/<función>/` (1080×1920, 30 fps, sin pista de audio, 18,8-21,5 s), las 16
  portadas (1080×1440 y 1080×1920) y el bento estático y animado en IG 1080×1350 ES, X 1600×900 ES y X 1600×900 EN
  (`estaticos/bento/`, animados de 10 s mudos).
- **Pieza 5:** 4 carruseles × 6 láminas en `carruseles/<tema>/es` (1080×1350) y `/en` (1600×900): registro rápido,
  panel y presupuestos, Yala IA y grupos. Pantallas reales de la app 2.1 del simulador; las cifras de las tarjetas son
  las que enseña cada pantalla. Voz, foto y Yala IA llevan «· Pro» en la pill, como en el código de 2.1.
- **Plantillas set B reutilizables** en `_fuente/` (paleta única en `base/setb.json`): `reel-setb.mjs`, portadas,
  bento y carruseles; las usarán las tandas 2 y 3.
- **Verificado:** medidas con `ffprobe`/`sips` (todas exactas; ningún reel tiene pista de audio), y barrido de los
  textos y los HTML generados: ni degradados en texto, ni Yape/Plin, ni «gratis», ni viajes, ni «OpenAI»; `S/` solo en
  ES y `$` solo en EN; cierre fijo con logo, lema e insignia en su idioma.
- **Nota para Lola:** `PARA-LOLA-tanda-1.md` (qué hay, dónde y qué publicar primero) y la hoja `hoja-tanda-1.jpg`.

Retoque único: la barra de estado de la lámina de la Bandeja (ES) es la de `01-panel`, para quitar el «◂ Atajos» que
dejó abrir Yala desde Atajos. Sin build, sin simulador y sin cambios en el código de la app.
