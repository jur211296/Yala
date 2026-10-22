# Shot contract — qué promete la plantilla y qué no

El contrato entre el guion (`src/brand/copy.ts`) y el motor
(`src/compositions/FeatureDemo.tsx`). Si algo de aquí cambia, cambia para todas las piezas.

---

## Las dos capas, que no se mezclan nunca

**Capa A · verdad del producto.** La grabación real del iPhone, sin recolorear, sin
estirar y sin reconstruir. Vive en `DeviceFrame` y llega por `OffthreadVideo`.
La UI de Yala **jamás** se genera con IA ni se redibuja en React.

**Capa B · motion.** Beats de texto, cámara, barra de avance, end card. Vive encima.

Si la Capa A está mal, se vuelve a grabar. La Capa B no arregla una toma mala: la disfraza.

---

## Los props

Una sola cosa se pasa a mano: **el `slug`**. Todo lo demás sale de `copy.ts`.

```ts
type FeatureDemoProps = {
  slug: string;                 // clave en PIECES
  locale: "es" | "en";
  aspect: "9x16" | "16x9";
  showSafeAreas: boolean;       // guía de Studio; en render va false
};
```

Y la pieza que el `slug` resuelve:

| Campo | Qué es | Regla |
|---|---|---|
| `footage` | Ruta dentro de `public/`, o `null` | `null` pinta el cartel «falta la toma» en vez de reventar |
| `footageSec` | Duración **medida con ffprobe** | Nunca se estima. De aquí sale `durationInFrames` |
| `source` | `{ w, h }` del origen | Encaja sin deformar. Si mientes aquí, el vídeo se estira |
| `crop` | Fracción que se recorta arriba/abajo | Recorta, no escala. Para tapar una status bar sucia |
| `theme` | `dark` \| `light` | Es el **marco**. El footage no se recolorea nunca |
| `beats[]` | El hilo de texto | Ver abajo. **6–8 por pieza**, no uno |
| `shots[]` | Los planos de cámara | Ver abajo |
| `endCard` | Wordmark + una línea | Una línea. No dos |

`durationInFrames` **no se escribe**: lo calcula `calculateMetadata` como
`footageSec + endCard.durationSec`.

---

## `beats` — el hilo de texto

El texto no es decoración: **es lo que se lee cuando el vídeo va sin sonido**, que es como
se ve la mayoría de las veces. Una pieza de 16 s lleva **6–8 beats**. Si hay dos segundos
sin texto, el pulgar sigue bajando.

| `style` | Tamaño | Para |
|---|---|---|
| `hero` | 104 px, peso 800 | Abrir y rematar. Dos o tres palabras |
| `line` | 62 px, peso 700 | Contar el paso que está pasando |
| `pill` | 40 px en píldora de cristal | Etiquetar lo que la pantalla acaba de enseñar |

Cada beat **entra por palabras**, con la siguiente medio paso por detrás, y lleva una barra
de acento que crece debajo. Un bloque que aparece entero se lee como una diapositiva.

**Todo el texto va ARRIBA** (`REELS_TEXT.top`), y eso es una decisión, no un descuido de
maquetación: entre las dos safe areas de Reels quedan 1300 px, y ahí no caben texto grande
arriba + teléfono grande + texto grande abajo. Intentarlo hizo que los rótulos de abajo
taparan el botón Guardar, la lista de cuentas y la fila de éxito — o sea, taparan justo lo
que la pieza viene a demostrar. **El texto titula; el teléfono demuestra.**

---

## `shots` — la cámara

Enseñar la pantalla entera, quieta, durante dieciséis segundos es la forma más rápida de
que nadie mire. Cada plano lleva a la vista donde está pasando algo.

```ts
{ atSec: 8.4, focusY: 0.41, scale: 1.22 }
```

- **`focusY`** = fracción del alto **visible** (el origen menos el crop) que queda centrada.
  Se calcula midiendo el elemento en el footage:
  `focusY = (fracciónEnElOriginal − cropTop) / (1 − cropTop − cropBottom)`
- **`scale`** = 1 llena el ancho del escenario. La ventana que se ve es
  **`0,505 / scale`** del alto visible. Por encima de **~1,25 empieza a cortar texto por los
  lados**.

**La cámara se SOSTIENE y luego viaja.** Interpolar de un `atSec` al siguiente sin parar
suena razonable y es lo que rompió una versión entera: la cámara está siempre en tránsito,
así que ningún encuadre llega a leerse. Medido — a 0,9 s la vista ya iba por la mitad del
camino al plano de 1,7 s, y de los tres chips solo se veía uno. El viaje ocupa los últimos
`CAMERA_MOVE_SEC` (0,65 s) de cada tramo; el resto, el plano está quieto.

---

## `Presentation-16x9` — escenas, no beats

La pieza horizontal tiene otro contrato: **`scenes[]`**, y cada escena trae

| Campo | Qué es |
|---|---|
| `durationSec` | Cuánto dura la escena |
| `footage` | `{ src, fromSec, source, crop }` — desde qué segundo de qué mp4. `null` = escena solo de texto |
| `pose` | Dónde y cómo está el teléfono: `x`, `y` (fracción del lienzo), `scale`, `rotateX/Y/Z`. `null` = el teléfono se retira |
| `text` / `textSide` / `textStyle` | Una línea. A la izquierda, a la derecha o centrada |
| `enter` | `move` viaja con spring a la postura nueva; `flip` gira de canto y **cambia la pantalla a 90°**, cuando nadie la ve |

El teléfono es **un solo objeto** que persiste toda la pieza —`PhoneShell` con una
`ScreenVideo` por escena dentro—, así que las posturas se encadenan con spring y el giro de
canto ocurre de verdad, no como un corte disimulado.

**Las escenas terminan donde termina lo que enseñan.** La escena «Registrado.» dura 2,5 s
y no 3 porque en 14,0 s del footage la hoja del chat se cierra y el Panel asoma un instante
antes de Registros — medido frame a frame. Si una escena se alarga un segundo de más, enseña
algo que no estaba en el guion.

---

## La geometría, y de dónde salen los números

No son gusto. Salen de medir el footage del piloto con `ffmpeg`, frame a frame:

| Elemento del piloto | Dónde cae en la pantalla del iPhone |
|---|---|
| Chips de sugerencia | 30 %–53 % del alto |
| Campo de escritura | 82 %–89 % |
| Burbuja del usuario | 18 %–26 % |
| Card de confirmación | 27 %–73 % ← **el plano estrella** |
| Fila «Cuenta» | 40 %–45 % |
| Fila de éxito «Pizza · PEN 20.00 · Registrado» | 32 %–40 % |

En 9:16 el teléfono se dibuja **entero, con marco** (`PHONE`: pantalla de 690 px, bisel de
16, isla, botones, reflejo del cristal) y la cámara lo mueve **como un objeto**: escala desde
su centro y lo desplaza para llevar `focusY` al centro de cámara (`REELS_CAMERA.centerY`,
1210 px — más bajo que el centro del lienzo para que el texto tenga su banda arriba). Cuando
la cámara se acerca, el iPhone crece y se sale por arriba y por abajo, que es lo que hace
una cámara de verdad; nunca deja de tener forma de iPhone. Lleva un balanceo de ±3° en
`rotateY` para que parezca sostenido, no atornillado.

Cuatro encuadres probados, y por qué se descartaron los tres primeros:

1. **Teléfono pequeño centrado sobre negro** (65 % de ancho): el 36 % del lienzo queda
   vacío y en un feed la pieza es invisible.
2. **Footage a sangre**: el texto blanco cae sobre las tarjetas blancas de la app y no se
   lee, por mucho scrim que se le ponga.
3. **Pantalla recortada en una caja de 940×1000**: legible y grande, pero sin marco un trozo
   de UI no se lee como «un teléfono», se lee como una captura pegada. Jürgen lo tumbó.
4. **iPhone entero + cámara de objeto + fondo con orbes** ← el que está.

En el golpe, un `badge` **sale de la pantalla**: repite el dato que la fila de éxito ya
enseña —monto, concepto, categoría— y lo saca al primer plano con volumen. No inventa nada;
si no está en el footage, no va ahí. Una vez por pieza: repetirlo lo gasta.

`REELS_SAFE` (top 220, bottom 400, side 64) **no recorta nada**: `SafeAreas` lo dibuja en
punteado para comprobarlo en Studio, y va apagado en render. Lo que se respeta es que
ningún **texto** y ningún **gesto clave** caigan dentro.

`src/lib/layout.ts` va aparte de `tokens.ts` a propósito: **tokens es la marca** (lo que no
cambia entre piezas) y **layout es el encuadre** (lo que se recalcula si cambia el lienzo).

---

## Tipografía: Inter es un sustituto, y conviene saberlo

La referencia real de Yala es **SF Pro Rounded**, y no se puede empaquetar en un render web.
Se usa **Inter** (`@remotion/google-fonts/Inter`, cargada una sola vez en `src/brand/font.ts`).
No leas las piezas como «así se ve la tipografía de Yala»: se parece, no es.

**Las escalas están subidas respecto al brief del encargo** (hero 64 → 104, callout 28 → 40,
`linePx` es nuevo). A 64 px sobre 1080 el texto ocupa un 6 % del alto: se ve, pero no se
lee en un feed. **Los hex no se tocaron**: esto es escala tipográfica, no marca.

---

## Divergencia de marca detectada, sin tocar

`Web/public/logo.svg` construye el wordmark con **cian neón `#00F3FF`**. Los tokens 2.1 dicen
**teal `#00C2CB`**. La `EndCard` usa el token 2.1, que es lo que manda para el pack.
**La web no se toca desde aquí** — queda anotado para que alguien lo decida, no para que se
arregle por la espalda.
