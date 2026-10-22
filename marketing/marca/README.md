# Marca de Yala — lo visual

> El tono y las palabras viven en [`docs/planning/BRAND-VOICE.md`](../../docs/planning/BRAND-VOICE.md).
> Aquí no se copian: este fichero solo cubre cómo se **ve** una pieza.
>
> **De dónde sale cada valor (medido el 2026-10-13):** los posts de @yala_app.pe no se pudieron abrir
> en una sesión nocturna sin login. Por eso los valores salen del código que ya genera las piezas:
> el post diario de IG (`screenshots-appstore/daily-post/render-post.mjs`) y la web
> (`Web/src/styles/global.css`). Los posts publicados salen de ese mismo render, así que deberían
> coincidir. Conviene confirmarlo contra el feed la primera vez que alguien lo abra con sesión.

## Paleta

### Fondo navy

| Token | Hex | Dónde se usa |
|---|---|---|
| `navy-900` | `#0F172A` | Arriba del degradado del post diario. Es también el fondo de la web (`--bg-primary`) |
| `navy-950` | `#0B1122` | Abajo del degradado del post diario |
| Degradado | `linear-gradient(180deg, #0F172A 0%, #0B1122 100%)` | Fondo de toda pieza de redes |

### Brillos y acentos

En redes se usan los del post diario. La web tiene otra tanda, más saturada.

| Nombre | Redes (post diario) | Web | Uso |
|---|---|---|---|
| Rosa | `#FF2D78` | `#FF0080` | Brillo y palabra subrayada |
| Azul / índigo | `#6164EB` | `#6366F1` | Brillo y palabra subrayada |
| Teal / cian | `#3BD6F0` | `#00F3FF` (cian) · `#00C2CB` (teal) | Brillo y palabra subrayada |
| Violeta | `#8B5CF6` | — | Cuarto acento del post diario. Úsalo poco |

**Decisión:** en redes manda la columna del post diario, porque es la que ya tiene publicada el feed.
La de la web no se toca desde aquí.

### Texto

| Uso | Valor |
|---|---|
| Titular | `#FFFFFF`, peso 850, interlineado 1,16, tracking −1px |
| Subtítulo | `rgba(255,255,255,.72)`, peso 600 |
| Texto secundario (web) | `#CBD5E1` · apagado `#94A3B8` |

## Piezas del sistema

1. **Titular blanco con una palabra subrayada.** Solo una palabra por pieza. Lleva el color del
   acento y una barra de 10 px con radio de 6 px, 6 px por debajo de la línea de base
   (`.hl .w` + `.hl .bar` en el post diario). Ejemplo: «Tus gastos, en el **iPad**».
2. **Pill tag** sobre el titular. Va en MAYÚSCULAS, con peso 800 y tracking de 2 px. El texto es del
   color del acento y el fondo es ese acento al 15 % (`${accent}26`). Radio de 32 px. Ejemplos:
   «NUEVO EN 2.1», «GRUPOS», «IPAD».
3. **Brillos.** Son de dos tipos:
   - un halo radial del acento al 30 % de opacidad, que no queda debajo del texto;
   - destellos de cuatro puntas en los bordes, de 50 a 80 px, girados entre −15° y 18°, con su sombra del mismo color.

   El trazado del destello: `M50 0 C54 36 64 46 100 50 C64 54 54 64 50 100 C46 64 36 54 0 50 C36 46 46 36 50 0 Z` (viewBox 100).
4. **Logo «yala» blanco con destello**, abajo a la izquierda: 190 px de ancho en 1080 y a 64 px del borde.
   En el encabezado de la App Store no se repite el ícono, porque la ficha ya lo pone debajo.

## Logo e ícono (fuentes, no copias)

| Asset | Ruta |
|---|---|
| Logo de las piezas de redes, con destello (PNG 2400×800) | `screenshots-appstore/generator/public/yala-spark.png` |
| Logo «yala» de la app (PNG 360×120) | `screenshots-appstore/generator/public/yala-logo.png` (el mismo fichero que `Yala/Resources/Assets.xcassets/YalaLogo.imageset/YalaLogo@3x.png`) |
| Logo de la web (SVG) | `Web/public/logo.svg` |
| Ícono de la app | `screenshots-appstore/generator/public/app-icon.png` |

No se duplican aquí. Si cambia el logo de la app, las piezas lo heredan.

## Tipografía

Fuente del sistema: `-apple-system, BlinkMacSystemFont, "SF Pro Display", "Segoe UI", Roboto, sans-serif`.
Es la del post diario, y en un Mac sale SF Pro, igual que en la app. Las plantillas de
[`../plantillas/`](../plantillas/) usan esa misma pila de fuentes.

## Lo que nunca sale en una pieza

- Modo Nube, «tu cuenta en la nube» ni el conector de Claude.
- «Vía tu iCloud» para Grupos: Grupos vive en la nube de Yala.
- «No almacenamos nada en servidores».
- Una cifra exacta de divisas: se dice «más de 50 divisas».
