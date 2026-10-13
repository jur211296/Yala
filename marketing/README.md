# marketing

Único árbol vivo de marketing de este repo. **Nada de lo que hay aquí se publica solo**: son
borradores, plantillas y herramientas. Publicar en App Store Connect o en redes es un paso a mano.

## Por dónde empezar

| Quiero… | Ve a |
|---|---|
| Saber cómo se ve una pieza de Yala (colores, titular, pill, logo) | [`marca/`](marca/) |
| Saber qué trae 2.1 y cómo enseñarlo en un vídeo | [`funcionalidades/`](funcionalidades/) |
| Copiar un texto listo (posts, hilo, ficha de la tienda) | [`copys/`](copys/) |
| Preparar la ficha 2.1 (capturas, encabezado, ícono) | [`assets/checklist-2.1.md`](assets/checklist-2.1.md) |
| Planificar la semana en IG y X | [`calendario/`](calendario/) |
| Hacer un post, una portada de reel o un carrusel sin Figma | [`plantillas/`](plantillas/) |

## Carpetas

### Contenido

- [`marca/`](marca/): el sistema visual. Paleta navy, brillos rosa/azul/teal, titular blanco con
  una palabra subrayada, pill tag y logo, con los hex medidos. El tono y las palabras no se repiten
  aquí: viven en [`docs/planning/BRAND-VOICE.md`](../docs/planning/BRAND-VOICE.md).
- [`funcionalidades/`](funcionalidades/): una ficha por función de 2.1, con qué gana el usuario, el
  guion de la demo, dónde se graba y su evidencia en el código.
- [`copys/`](copys/): textos de 2.1 corregidos con el criterio de copy de 2.1.
  - [`changelog-2.1.md`](copys/changelog-2.1.md): post y hilo de X, y las Novedades.
  - [`app-store-2.1.md`](copys/app-store-2.1.md): Novedades, texto promocional, subtítulo, keywords y la descripción que hay que cambiar.
- [`assets/`](assets/): [`checklist-2.1.md`](assets/checklist-2.1.md). Specs de Apple 2025-2026 y qué
  hace falta para enviar la ficha 2.1.
- [`calendario/`](calendario/):
  - [`plantilla-semanal.md`](calendario/plantilla-semanal.md): IG + X, con su checklist de copy.
  - [`x-presencia-minima.md`](calendario/x-presencia-minima.md): handle y tono de la cuenta de X.
- [`plantillas/`](plantillas/): HTML a tamaño real. Post 1080×1350, portada de reel 1080×1920 y carrusel. Se exportan con Chrome headless.

### Herramientas (sin cambios)

- `App Store/`: metadata actual, PNGs de iPhone y de iPad en ES y EN, y scripts en uso.
- `screenshots-appstore/`: el generador de capturas y el post diario automático.
- `remotion/`: **estudio de demos en vídeo**. Footage real del iPhone y motion al estilo de Apple,
  renderizado por código. Piezas 9:16 y 16:9 del pack 2.1. Empieza por
  [`remotion/docs/OPERACION.md`](remotion/docs/OPERACION.md).

Las tres son hermanas y ninguna sustituye a otra: el generador saca **capturas** para la ficha,
Remotion saca **vídeo** para redes y las plantillas sacan **imágenes** para redes.

`Web/` sigue en la raíz del repo, porque es un sitio independiente.

## Criterio de copy de 2.1 (vale para todo lo de aquí)

- «Más de 50 divisas», sin cifra exacta.
- Grupos vive en la nube de Yala, **nunca** en iCloud.
- Exportar es gratis en todos los períodos, en CSV y en Excel.
- Ni la cuenta en la nube (Modo Nube) ni el conector de Claude salen en nada público.
- Nunca «no almacenamos nada en servidores».

Viene de la política 2.1 (PR #469).

## Decisiones de esta reorganización (2026-10-13)

1. **No se movió nada de lo que ya funcionaba.** `App Store/`, `screenshots-appstore/` y `remotion/`
   siguen en su sitio, porque sus scripts dependen de esas rutas (`asc-extra-locales-2.0.py`, el
   generador, el post diario y su `launchd`).
2. **`x-presencia-minima.md` pasó a `calendario/`** con `git mv`. Ningún script lo citaba; solo lo
   citaban los borradores de `~/Claude/lola-borradores/`, que están fuera del repo.
3. **La marca sale del código y no del feed.** Los posts de @yala_app.pe no se pudieron abrir sin
   sesión. Los valores se tomaron del render del post diario, que es lo que genera esos posts, y
   de la web. Falta confirmarlos contra el feed.
4. **En redes manda la paleta del post diario**, no la de la web, que es más saturada. Las dos
   están en `marca/`.
5. **El logo y el ícono no se copian**: `marca/` enlaza a los ficheros de origen, para que no haya
   dos versiones.
6. **Los copys de 2.1 se corrigieron con el criterio de arriba.** Cada fichero termina con su tabla de
   correcciones. Lo principal: entra la exportación gratis, y Grupos ya no está «bloqueado» por la
   política, sino a la espera de su despliegue en Vercel.
7. **Hay una ficha nueva, `09-exportar-gratis`**: la exportación gratis la trae el PR #469 y el
   borrador del 12-oct no la tenía.
8. **El ritmo del calendario (IG 3 posts y 2 reels, X uno al día) es un punto de partida**, no una
   decisión. Se ajusta con las métricas.
