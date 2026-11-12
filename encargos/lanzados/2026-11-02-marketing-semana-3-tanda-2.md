# Carruseles y reels nuevos de Yala (marketing semana 3, tanda 2)

## Contexto
Segunda tanda de piezas de la semana 3 de marketing de Yala. Se parte de la biblioteca `/Users/jur/Claude/marketing/biblioteca/`, con el mismo estilo, música y pipeline que la tanda del 25 de octubre (`PARA-LOLA-assets-x-16x9.md`, `_fuente/serie/hacer-x-16x9.sh`) y los mismos nombres y rutas que ya usa la biblioteca. Todas las horas son de Lima.

## Qué se pide
Hacer las piezas en este orden. Cerrar el entregable de cada una antes de pasar a la siguiente y anotarlo en `PARA-LOLA-semana-3.md`, para que se pueda publicar sin esperar el resto.

### P3 · miércoles 4, antes de las 11:00 · carrusel `cuentas-recordatorios`
- IG: 6 láminas 1080×1350 (4:5) en ES, y en EN si sale con el mismo comando.
- X: 4 láminas 1600×900 en ES y EN (`x-4`).
- Láminas: 1) portada con el gancho «Tus cuentas y tus pagos, bajo control»; 2) todas tus cuentas (efectivo, banco y tarjeta) con su saldo; 3) transferencias entre cuentas; 4) recordatorios de pagos y vencimientos; 5) pagos planificados o recurrentes; 6) cierre con el logo y «Descarga Yala gratis».
- En X van la portada, las cuentas, los recordatorios y el cierre.

### P4 · jueves 5, antes de las 11:00 · reel `apple-pay`
- Guion de 15 a 20 s: gancho «Pagas con Apple Pay y Yala lo anota solo»; se configura una sola vez con Atajos (automatización de Wallet); pago; el gasto llega a Bandeja, se aprueba; cierre.
- Entregables: IG 9:16 ES con voz y música; `*-x.mp4` 9:16 ES y EN con música; X 16:9 ES y EN; portadas 9:16 y 3:4 en ES y EN.

### P5 · viernes 6, antes de las 11:00 · carrusel `entiende-tus-gastos`
- Mismos formatos que P3.
- Láminas: 1) «¿A dónde se va tu plata?»; 2) categorías; 3) tendencias mes a mes; 4) comparativa entre períodos; 5) salud financiera; 6) cierre.
- En X van la portada, las categorías, las tendencias y el cierre.

### P6 · sábado 7, antes de las 11:00 · reel `siri-atajos`
- Mismos entregables que P4.
- Guion: «Dile a Siri "anota 25 en almuerzo"»; el gasto entra sin abrir la app; el Atajo en la pantalla de inicio; cierre.

### P7 · si sobra
- Panel 16:9 para X en ES y EN (`reels/panel/con-audio/panel-{es,en}-x-16x9.mp4`).
- Serie «Yala en 20 segundos», cap. 5 · Grupos, en los mismos formatos que los caps. 2 a 4.

## Reglas
- Video para X: 1920×1080, 30 fps, H.264 + AAC 48 kHz, sin voz, frase a la izquierda y teléfono a la derecha, sin franjas negras y sin estirar nada.
- Reel de IG: 1080×1920 con voz y música. La portada 9:16 lleva el titular y el logo juntos y dentro de la zona segura.
- Carruseles con márgenes seguros.
- Lo que sea Pro va marcado «Pro».
- Pantallas reales de la app, sin funciones inventadas. El texto en ES va en español neutro latinoamericano, nunca de España.
- Registrar todo en `INDICE.md` y en `PARA-LOLA-semana-3.md`, con el ffprobe, la duración y una hoja de control .jpg de cada pieza.
- Si un texto no cabe, acortarlo y anotarlo. Si falta un dato, decidir lo razonable y anotarlo.

## Qué NO hay que tocar
- No hacer las estáticas de las 19:30 ni el cap. 3.

## Cómo se sabe que está bien
- P3 a P6 entregadas en orden, cada una registrada en `INDICE.md` y `PARA-LOLA-semana-3.md` con ffprobe, duración y hoja de control .jpg; P7 si dio el tiempo.
- Terminar con `/cerrar-total`.

## Paso 0

- **Repo:** los entregables viven en `/Users/jur/Claude/marketing/biblioteca/`, fuera de git. En Yala solo entra este encargo.
- **Pantallas:** se usa el banco de la app 2.1 real (`_fuente/estaticos/pantallas/`). Faltan la transferencia, la lista de cuentas y Atajos, y compilar es de Frank: se le piden capturas de 2.1 con la semilla de marketing en `_fuente/estaticos/pantallas-semana3/`. Lo que no salga se cubre con otra pantalla real y se anota.
- **Carrusel EN 4:5:** `gen.py` gana el formato `en-4x5`, que es la maqueta vertical con los textos y las pantallas EN. Sale con el mismo comando y va a `carruseles/<tema>/en-4x5/`.
- **Cierre del carrusel:** el texto es «Descarga Yala gratis» / «Download Yala for free», según pide el encargo, con el logo y la insignia. El cierre de los reels se queda igual.
- **Pro:** según `FeatureGateService`, la voz, la foto, Yala IA y Siri en lenguaje natural son Pro. Cuentas, transferencias, recordatorios, pagos planificados, categorías, tendencias, comparativa y salud financiera son gratis. El reel `siri-atajos` va marcado Pro.
- **Frase de Siri:** «anota 25 en almuerzo» no es una frase que la app registre. Las de 2.1 son «Anota un gasto en Yala», y luego Siri pregunta. El guion usa esas dos frases, y el gasto entra como borrador en la Bandeja.
- **Reels de Apple Pay y Siri:** no hay tomas grabadas, y Siri y Wallet no se pueden grabar en el simulador. La toma se monta con pantallas reales fijas y con el tramo de la Bandeja de `footage/t3-bandeja-*`.
- **Voz de IG:** no hay clave de ElevenLabs en la sesión (1Password no conecta). Se dejan el guion de voz con sus tiempos y el comando, y el `*-ig.mp4` queda pendiente de Jürgen. No se publica una voz provisional.
- **Música:** «Pop Track 03» (Mixkit 729), igual que en los reels de la tanda 3b.
