# TANDA 2 de 3: esta sesión hace SOLO las piezas 1, 2 y 8 del encargo de abajo. Las otras tandas van en sesiones aparte.

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

## Paso 0 (Frank, 2026-10-21, MODO AUTÓNOMO: decisiones asumidas)

1. **Rama.** El worktree salía de 2.1 (`df498b7cc`); se rehízo la rama del encargo sobre `origin/2.2` antes de tocar nada.
   Del repo solo cambia este fichero: todo lo demás vive en `~/Claude/marketing/biblioteca/`.
2. **Sin simulador ni build.** Las tomas de la app 2.1 real ya existen en `_fuente/footage/` (tanda 1 y PR #580):
   `cfr-vp-<idioma>` es la de la ficha con **Grupos en movimiento** (lista → «Depa compartido» → Balances), ES en soles
   y EN en dólares. Grabar de nuevo no aportaba nada y gastaba disco (22 GB libres al empezar).
3. **Pieza 1, vista previa.** Mismos guiones que la vista previa oficial del 20-oct (4 escenas: Yala IA, foto, voz,
   Grupos; 29,13 s), pasados por la plantilla set B de la tanda 1, que ya tenía los formatos `appstore` (886×1920) y
   `horizontal` (1920×886) con la codificación de ASC (H.264 High@4.0 ~11 Mbps, AAC estéreo 48 kHz mudo).
   **Cierre sin insignia del App Store:** la vista previa ya vive dentro de la tienda (como la del 13-oct) y la regla
   2.3.4 de Apple pide que enseñe la app. Logo y lema sí. La plantilla gana `"badge": false`, opcional.
4. **Pieza 2, evento.** El que tiene Lola en `assets-asc-2.1-2026-10-13/eventos/` decía «GRUPOS GRATIS» y enseñaba
   «Viaje a Cusco». Se parte del del 20-oct (ya sin «gratis» y con «Depa compartido», pantalla real) y se pasa al
   índigo del set B (era violeta). Solo ES, como el original. **El nombre del evento no se toca**, como pide Lola;
   el del README del 13-oct («Novedades 2.1: Grupos gratis») lleva «gratis» y se le avisa en la nota.
5. **Pieza 8, post de lanzamiento.** Las tres novedades son las de la pantalla «Novedades» de la app
   (`whatsNew.v21.*`): Grupos, anotar con voz/foto/IA (Pro, y se dice) y tus datos en tu iCloud o en la nube de Yala.
   Imagen en IG 1080×1350 ES y X 1600×900 ES y EN; reel corto 1080×1920 mudo ES y EN (~15 s) con gancho
   «Yala 2.1», toma de Grupos y de voz de la tanda 1 y el cierre fijo con insignia. La plantilla gana
   `"contador": false` en el gancho: contar de 0 a 2.1 pasaba por «Yala 2.0», que es otra versión.
6. **La plantilla set B no cambia para lo de la tanda 1**: el `index.html` del reel 3 sale idéntico byte a byte.

## Resultado

Todo en `~/Claude/marketing/biblioteca/`, en el `INDICE.md` como **guardada para 2.1**, con `PARA-LOLA-tanda-2.md` y
`hoja-tanda-2.jpg`. Del repo solo cambia este fichero.

- **Pieza 1 · vista previa 6,9"** — `asc/vista-previa/<es|en>/yala-vista-previa-6.9-<vertical|horizontal>.mp4`.
  ffprobe de las cuatro: **886×1920 / 1920×886, 30/1 fps, 29,13 s, H.264 High@4.0 a 10,96 Mbps, AAC LC estéreo
  48 kHz con máximo −91 dB (mudo), 40 MB**. Grupos se mueve: lista → «Depa compartido» → Balances, con «Te deben
  S/ 190» / «Owed to you · $190». Cierre: logo y lema, sin insignia.
- **Pieza 2 · evento in-app** — `asc/evento/yala-evento-tarjeta-3840x2160.png` y `-detalle-2160x3840.png` (sips: tamaños
  exactos, PNG sin alfa). Pill «Novedades 2.1 · Grupos», «Depa compartido», índigo set B. Ni «gratis» ni viajes.
- **Pieza 8 · lanzamiento** — `lanzamiento/imagen/` IG 1080×1350 ES, X 1600×900 ES y EN; `lanzamiento/reel/` reel
  corto 1080×1920 sin pista de audio, 15,3 s ES y 15,1 s EN.
- **Revisión set B, pieza por pieza** (tiras de contacto): ningún texto con degradado, clave en índigo sólido, navy
  con estrellas, soles en ES y dólares en EN, cierre «Tus finanzas, sin esfuerzo.» / «Your finances, effortlessly.».
  Búsqueda de «gratis», Yape, Plin, OpenAI y viajes en guiones y plantillas: ninguno en las piezas.
- **Sin simulador ni build**: no se encendió ninguno; `xcrun simctl list devices booted` vacío al empezar y al cerrar.
- **Fuente** (`_fuente/`): `reels/hacer-vista-previa.sh` y `reels/piezas/vp-*`, `evento/`, `lanzamiento/gen.py` y
  `lanzamiento/tomas.py`. La plantilla de reel gana `"badge": false` y `"gancho": {"contador": false}`; el reel 3 de
  la tanda 1 genera el mismo `index.html` byte a byte.

**Encontrado y no tocado:** el texto del evento del 13-oct (`assets-asc-2.1-2026-10-13/README.md`) se llama
«Novedades 2.1: Grupos gratis» y habla de «gastos del viaje». El encargo dice no cambiar el nombre: se avisa a Lola en
su nota para que elija el texto que escribe en ASC.
