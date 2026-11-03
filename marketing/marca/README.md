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
| `navy-900` | `#0F172A` | Fondo liso de toda pieza de redes. Es también el fondo de la web (`--bg-primary`) |
| `navy-950` | `#0B1122` | Solo en el degradado viejo del post diario. Las piezas nuevas no lo usan |

**Sin degradados, sin brillos ni glows** (regla de Jürgen del 2026-10-13: se ven hechos con IA). El fondo
es `navy-900` liso. El render del post diario (`render-post.mjs`) todavía pinta el degradado viejo
`#0F172A → #0B1122`: es una pieza anterior a la regla, no un modelo para las nuevas.

### Acentos

En redes se usan los del post diario. La web tiene otra tanda, más saturada.

| Nombre | Redes (post diario) | Web | Uso |
|---|---|---|---|
| Rosa | `#FF2D78` | `#FF0080` | Palabra subrayada, pill y formas planas |
| Azul / índigo | `#6164EB` | `#6366F1` | Palabra subrayada, pill y formas planas |
| Teal / cian | `#3BD6F0` | `#00F3FF` (cian) · `#00C2CB` (teal) | Palabra subrayada, pill y formas planas |
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
3. **Formas planas de color sólido**, no brillos. El movimiento lo dan la barra del subrayado en grande,
   un disco o una traza del acento, sin transparencias que hagan de halo. Nada de halo radial, destellos
   de cuatro puntas, resplandor detrás del teléfono ni reflejo sobre su pantalla. La única sombra es negra,
   para separar un objeto del fondo; nunca del color del acento.
4. **Logo «yala» blanco con destello**, abajo a la izquierda: 190 px de ancho en 1080 y a 64 px del borde.
   El destello del logo se queda porque es la marca; no se repite suelto por la pieza.
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
