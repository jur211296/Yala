# Estudio de demos de Yala · Remotion

Las piezas de vídeo del pack 2.1: grabación real del iPhone + rótulos estilo Apple,
renderizadas por código. **No es un Reel: es el sistema que saca un Reel al día.**

```bash
cd marketing/remotion
bun install
bun run studio          # abre FeatureDemo-9x16
bun run render:reels    # → out/ia-gasto-pizza-es-9x16.mp4
```

## El principio, que no se negocia

**La UI de Yala no se dibuja: se filma.** Ni Imagine, ni Higgsfield, ni Kling, ni Sora, ni
Remotion pintando un iPhone en React. Lo que se ve en pantalla es una grabación de la app
de verdad; Remotion pone encima los títulos, los callouts y el cierre.

Si la toma está mal, se vuelve a grabar.

## Qué hay aquí

| | |
|---|---|
| `src/brand/tokens.ts` | La marca 2.1. Único sitio donde vive un hex |
| `src/brand/copy.ts` | El guion: los **beats** de texto y los **planos de cámara**. Ni una palabra de copy en el JSX |
| `src/compositions/FeatureDemo.tsx` | La plantilla. Una sola, para los dos lienzos |
| `src/components/` | `DeviceFrame` (el iPhone), `AppleTitle`, `Callout`, `FloatBadge`, `SafeAreas` |
| `src/lib/layout.ts` | El encuadre y la **cámara**, con los números medidos sobre el footage |
| `public/footage/` | Las tomas. Curadas, no crudas |
| `scripts/` | Render de una pieza o del pack, con comprobación del fichero |
| `out/` | Los mp4. **No se commitea** |

## Documentación

- **[`docs/OPERACION.md`](docs/OPERACION.md)** — el bucle diario, de la grabación al mp4.
  Empieza por aquí.
- **[`docs/SHOT-CONTRACT.md`](docs/SHOT-CONTRACT.md)** — qué promete la plantilla, los props
  y de dónde salen los números del encuadre.
- **[`docs/SHOT-CARDS.md`](docs/SHOT-CARDS.md)** — los cuatro planos de la pieza piloto.
- **[`LICENSE-NOTES.md`](LICENSE-NOTES.md)** — Remotion no es MIT. Hoy no bloquea nada.

## Compositions

| id | Lienzo | Para |
|---|---|---|
| `Presentation-16x9` | 1920×1080 | **La presentación** por escenas: YouTube, web, App Store preview |
| `FeatureDemo-9x16` | 1080×1920 | **Clip por función**: Reels, TikTok, Shorts |
| `FeatureDemo-16x9` | 1920×1080 | El mismo clip, en horizontal |

La pieza se elige por `slug` en los props, no creando una composition nueva.

## Estado

**Piloto `ia-gasto-pizza` renderizando en los dos lienzos.** Los otros 9 slugs del pack 2.1
están reservados en `copy.ts` sin toma: el Studio los enseña con su cartel de «falta la
toma» en lugar de reventar.

⚠️ **Al piloto le falta una toma limpia** antes de publicar: la actual va en tema Light y
lleva la píldora roja de grabación (tapada con un recorte). Los datos son seed de demo.
Ver `docs/OPERACION.md § Deuda de la toma piloto`.
