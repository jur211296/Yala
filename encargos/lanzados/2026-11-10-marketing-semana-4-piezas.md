---
toca: marketing/
release: no
esfuerzo: high
---
marketing
# Piezas de marketing de la semana del 10 al 15 de noviembre y cap. 6 de la serie

AUTORIZADO: Jürgen dio el sí el 9-nov a las 20:14 Lima para encolarlo en la Max, después de la subida a TestFlight de 2.2. Lo de abajo que dice «no lo encoles» ya no aplica. Si arrancas más tarde que el martes 10 temprano, prioriza según el orden del encargo y deja en PARA-LOLA-semana-4.md qué piezas no llegan a su fecha, para que Lola use las estáticas de respaldo. En la Max puedes usar un segundo simulador si otro está ocupado (tope 2) o el iPhone 14 por DeviceMCP.

# Encargo para Frank · piezas de marketing · 10 al 15 de noviembre de 2026 (y cap. 6 para el 22)

Estado: **APROBADO POR JÜRGEN PARA ENVIAR A FRANK (9-nov-2026, 17:43 Lima), SIN ENCOLAR.** Frank: no lo encoles todavía. Pregúntale a Jürgen cuándo meterlo en la cola y encólalo solo cuando él te lo diga. Las fechas límite de abajo asumen que arranca a más tardar el martes 10 temprano; si Jürgen lo mete más tarde, recalcula los límites con él y avísame a mí (Lola) qué piezas no llegan, para usar las estáticas de respaldo del plan.
Quién lo encola, si hay sí: Frank. Destino: marketing (`lanzar-sesion marketing` / Yala/marketing). Lola no lanza ni encola.
Card: `cierra-sola`. La sesión termina con `/cerrar-total` (trabajo completo, merge incluido, un aviso).
Si no cabe en una sola sesión: sesiones **secuenciales**, nunca en paralelo. Misma máquina, una detrás de otra. No usar `--permitir-paralelo`.
Esfuerzo sugerido: `high` (mucho que producir, criterio de estilo ya conocido). El esfuerzo va en el frontmatter o en la bandera, no en frases del tipo «piensa bien» o «razona paso a paso».
Idioma de las piezas nuevas: **solo español neutro latinoamericano**. No hace falta versión en inglés: Jürgen decidió el 9-nov-2026 que en X se publica solo en español, sin calendario EN.

---

# Piezas de marketing para la semana del 10 al 15 de noviembre

## Contexto

Yala 2.1 está en el aire. La 2.2 se atrasó el 9-nov y no tiene fecha: **no se anuncia la 2.2 y no se muestran como nuevas las funciones que solo viven ahí** (tarjeta en dos monedas, consulta a Siri de saldos o gastos, deshacer al guardar, Grupos con ventas por cobrar o «tu parte», widget nuevo de Grupos, resumen automático de Estadísticas con Yala IA, importar Excel, ícono nuevo Liquid Glass).

El material sale de la app **2.1 real** en el simulador, con la semilla de marketing, montos en soles, estilo set B. Lola no genera assets: Frank produce todo; Lola solo pondría música o voz si algo quedara mudo, pero en este pedido la mezcla de IG (voz + música) y de X (solo música) va incluida.

Si este texto llega a una sesión, es porque Jürgen ya dio el sí y eligió cuándo meterlo.

Biblioteca: `~/Claude/marketing/biblioteca/` (índice en `INDICE.md`). Estilo y tono: `~/Claude/marketing/GUIA-PUBLICACIONES.md`. Referencia de pipeline: tandas de la semana 3 en `PARA-LOLA-semana-3.md` y scripts en `_fuente/`.

## Qué se pide

Un solo lote, en este orden de prioridad. Cada pieza, en todos los formatos que necesita. Al terminar, actualizar `INDICE.md` añadiendo filas (no reescribirlo desde cero) y dejar un `PARA-LOLA-semana-4.md` en la raíz de la biblioteca, con rutas, `ffprobe`, volumen medido y hojas de control.

### Estilo, audio y medidas (valen para todo el lote)

- Set B: fondo navy `#0F172A`, estrellas planas de cuatro puntas, palabra clave en índigo sólido `#6164EB` subrayada, nada de degradados en el texto. Reels con las animaciones nuevas y el halo índigo detrás del teléfono.
- Cierre fijo: logo, «Tus finanzas, sin **esfuerzo**.» e insignia del App Store.
- Montos en soles. Nada de Yape ni Plin en las imágenes. «Gratis» solo si es factual. No decir Beta, ni app privada, ni vender multimoneda como novedad. Si la función es Pro, la pill lleva «· Pro».
- Recortes: IG feed / carrusel 1080×1350 (4:5). Reels e historias 1080×1920 (9:16). Portadas de reel y de serie en **3:4 (1080×1440) y 9:16 (1080×1920)**. X siempre 16:9: estáticas y láminas 1600×900; vídeos 1920×1080, sin franjas, sin estirar. Nunca 1:1.
- Reels de 15 a 25 s (la serie, 20 s exactos, plantilla ya usada). Gancho en el primer segundo, poco texto en pantalla. Subtítulos / texto on-screen siempre, también en la versión de X (va sin voz).
- Voz (solo IG/Threads): ElevenLabs, voz `gePzt50ZNIzsH3pmvJB6`, modelo `eleven_v4`, stability 0.5, similarity 0.8, style 0, speaker boost activado, speed 0.95.
- Música: Pop Track 03 (Mixkit 729), al mismo nivel que las referencias de la semana 3 (alrededor de −15,8 dB de media, medido con `volumedetect`). En X: música, sin voz. En IG: voz + música con ducking.
- Carrusel IG: 6 láminas (portada con gancho, 4 de contenido, cierre con lema e insignia). Carrusel X: 4 láminas 16:9 que cuentan la historia completa (gancho con teléfono, dos funciones o pasos, cierre). No son las 4 primeras de las 6.
- Vídeo: `h264` High, 30/1 fps. Audio: `aac` LC, 48 kHz, estéreo. Hoja de control (fotogramas a lo largo de todo el vídeo o las láminas) por cada pieza.
- No toques la app, ni piezas ya publicadas, ni versiones EN ya existentes, ni los `*-x.mp4` verticales viejos que no se piden aquí.

### P1 · Portadas 9:16 y 3:4 de la serie «Yala en 20 segundos» (cap. 2, 3, 4 y 5) · ES

**Fecha límite:** cap. 2, el martes 10 antes de las 11:00, hora de Lima, si la sesión arranca a tiempo. Si no alcanza, Lola usa el apaño de Dan (titular del inicio + logo del cierre) solo para el cap. 2. Caps. 3, 4 y 5: el sábado 14 antes de las 18:00.

Hoy no hay ningún archivo `portada` bajo `biblioteca/serie/`. El 1-nov el cap. 2 se publicó con una portada armada a mano, y quedó como lección pedirla aparte.

- Cap. 2 · Foto de la boleta (Pro)
- Cap. 3 · Yala IA (Pro)
- Cap. 4 · Presupuestos
- Cap. 5 · Grupos (2.1: quién le debe a quién; no ventas por cobrar ni «tu parte»)

Salida, por capítulo, en la carpeta ya existente de la serie, ES:

- `serie/yala-en-20-segundos/es/portada-cap-0N-<slug>-es-3x4.jpg`
- `serie/yala-en-20-segundos/es/portada-cap-0N-<slug>-es-9x16.jpg`

Frame legible en miniatura: 3 a 5 palabras + el teléfono o un número, sin cortar el logo. Variar un poco el layout entre capítulos para que la cuadrícula de IG no se vea repetida (lección de la guía, 25-oct).

### P2 · Reel nuevo · Salud financiera · para el jueves 12 a las 12:30

**Fecha límite:** miércoles 11, 18:00, hora de Lima.

Gancho (1 s, on-screen y en voz): «¿Cómo vas este mes?»
Demostrar la pantalla de salud financiera / resumen del mes en la app 2.1. No usar el resumen automático de Estadísticas con Yala IA (eso es 2.2). Cierre: la voz responde al gancho.

Entregar:

- Mudo 9:16 ES: `reels/salud-financiera/reel-salud-financiera-es.mp4`
- IG con voz y música: `reels/salud-financiera/con-audio/salud-financiera-es-ig.mp4` (misma duración que el mudo)
- X solo música, 16:9 (1920×1080): `reels/salud-financiera/con-audio/salud-financiera-es-x-16x9.mp4` (misma duración; frase a la izquierda, teléfono a la derecha, como los 16:9 de la semana 3)
- Portadas ES 3:4 y 9:16: `reels/salud-financiera/portada-salud-financiera-es-{3x4,9x16}.jpg`
- Hojas de control de las versiones con audio
- Voces fuente en `reels/salud-financiera/con-audio/_voz/`

### P3 · Carrusel nuevo · «Antes de Black Friday, ponle tope» · para el viernes 13 a las 12:30

**Fecha límite:** jueves 12, 18:00, hora de Lima.

Ángulo: el Black Friday en Perú es el viernes 27-nov. No es una oferta de Yala. Es «decide tu tope ahora». Solo funciones 2.1: presupuestos, recordatorios, comparativa o tendencias, salud financiera. Cierre con el lema y la insignia.

Propuesta de las 6 láminas IG (puedes ajustar redacciones, no el ángulo):

1. Portada / gancho: «El Black Friday es el 27. Ponle tope ahora.»
2. Elige la categoría que sí quieres cuidar.
3. Ponle un presupuesto y ve cuánto te queda.
4. Deja un recordatorio para no pasarte.
5. Compara el mes, para no adivinar.
6. Cierre: «Tus finanzas, sin esfuerzo.» + insignia.

Las 4 de X cuentan la misma historia completa, no un recorte pobre de las 6.

Salida:

- IG 6 láminas 1080×1350: `carruseles/antes-de-black-friday/es/`
- X 4 láminas 1600×900: `carruseles/antes-de-black-friday/x-4/es/`
- Hoja de control: `carruseles/antes-de-black-friday/hoja-antes-de-black-friday.jpg`

### P4 · Reel nuevo · Flujo de caja (Pro) · para el sábado 14 a las 12:30

**Fecha límite:** viernes 13, 18:00, hora de Lima.

Gancho: «Tu saldo, meses adelante.»
Demostrar flujo de caja de la 2.1, con pill «· Pro». No prometer predicciones mágicas ni «garantizado». La voz aclara que ves cómo se movería tu dinero si se mantienen ingresos y pagos.

Entregar, mismo esquema que P2, en `reels/flujo-de-caja/`:

- `reel-flujo-de-caja-es.mp4` (mudo 9:16)
- `con-audio/flujo-de-caja-es-ig.mp4`
- `con-audio/flujo-de-caja-es-x-16x9.mp4`
- `portada-flujo-de-caja-es-{3x4,9x16}.jpg`
- Hojas de control y `_voz/`

### P5 · Serie «Yala en 20 segundos» · cap. 6 · Pagos planificados y recordatorios · para el domingo 22

**Fecha límite:** miércoles 18, 18:00, hora de Lima (no bloquea esta semana; va al final de la sesión o de la siguiente sesión secuencial).

Misma plantilla de los caps. 1 a 5 (capítulo, barra de 20 s, 3 pasos, cierre). Tema 2.1: dejar un pago planificado y un recordatorio. No usar el copy de «cuánto te falta pagar este mes» ni «marcar en un toque» como novedad de 2.2.

Entregar:

- Mudo ES 9:16: `serie/yala-en-20-segundos/es/cap-06-pagos-recordatorios-es.mp4`
- IG voz + música: `serie/yala-en-20-segundos/es/con-audio/cap-06-pagos-recordatorios-es-ig.mp4`
- X música 16:9: `serie/yala-en-20-segundos/es/con-audio/cap-06-pagos-recordatorios-es-x-16x9.mp4`
- Portadas ES 3:4 y 9:16
- Hojas de control y `_voz/`

### P6 (si alcanza el tiempo, en la misma sesión o en la siguiente secuencial) · Carrusel «Grupos paso a paso» · 2.1

**Fecha límite:** no es de esta semana; queda en biblioteca para un turno posterior. Si no entra, no lo empieces a medias: déjalo documentado en el cierre.

6 láminas IG + 4 X, solo Grupos 2.1: crear el grupo, anotar gastos, ver quién le debe a quién, iCloud privado. Prohibido: ventas por cobrar, «tu parte» automática, widget de Grupos, «quién anotó cada gasto» como novedad 2.2.

Salida: `carruseles/grupos-paso-a-paso/es/` y `carruseles/grupos-paso-a-paso/x-4/es/`.

No se pide en este lote el carrusel «Tu app, segura y tuya» ni un reel de pagos favoritos: esta semana Face ID cubre confianza con una estática ya lista, y Favoritos ya tuvo estática el 7-nov (pendiente de confirmar publicación).

## Qué NO hay que tocar

- El código de la app, TestFlight, App Store Connect, ni capturas de la ficha 2.2.
- `PLAN-PUBLICACIONES.md` y `GUIA-PUBLICACIONES.md`.
- Piezas ya publicadas o ya listas que no estén en este pedido.
- Generar variantes en inglés de las piezas nuevas.
- Lanzar otra sesión en paralelo, abrir un segundo simulador si no hace falta, o dejar basura de build.

Si hay build o simulador (capturas nuevas de la 2.1): un simulador a la vez; pipeline serial (limpiar, build sin sim, boot 1, capturar, apagar); al `/cerrar-total`, apagar el sim, limpiar data, no dejar DerivedData ni cachés de XcodeBuildMCP de un worktree que ya no exista.

## Cómo se sabe que está bien

- Existen todos los archivos de P1 a P5 (y P6 solo si se completó entero) en las rutas indicadas, con el tamaño correcto.
- `ffprobe` OK; los IG y los 16:9 duran lo mismo que su mudo; el volumen de la música está alineado con la referencia.
- La voz de IG se oye clara, sincronizada con las escenas, y responde al gancho al cierre.
- Las portadas 9:16 se leen en miniatura y no cortan logo ni pill.
- No aparece ninguna función solo de 2.2, ni Yape/Plin en imagen, ni «gratis» engañoso.
- `INDICE.md` y `PARA-LOLA-semana-4.md` quedan actualizados.
- Hay hojas de control de cada vídeo y cada carrusel.

## Cierre

Al cerrar, el resumen dice pieza por pieza qué quedó, con su ruta, para que Lola arme captions y briefs de publicación. Modo de sesión: el que quede fijado al arranque (semiautónomo entre 05:30 y 20:00 Lima); si aparece una duda vital (por ejemplo, una función que no sabes si es 2.1 o 2.2), pregúntala y no la inventes.


Card `cierra-sola`. Cuando el trabajo esté completo, cierra con `/cerrar-total`. Si una prioridad posterior no entra, entrega P1–P4 sí o sí (son las de esta semana), deja P5 (y P6) para una sesión secuencial siguiente, y decláralo en el resumen de cierre, con lo que falta y la ruta donde seguir.

## Paso 0 — decisiones

> Modo semi. Resueltas por la sesión con su recomendación (son menores y reversibles); la única que pedía a Jürgen —la
> clave de ElevenLabs— la contestó él. Se discuten en el PR.

**D1 · ¿Dónde se renderiza?** → En la Max, sobre una copia de `_fuente`, y se sube a la Mini solo lo nuevo.
Por qué: la biblioteca vive en la Mini, pero ya no tiene Google Chrome y la plantilla lo necesita. Alternativa descartada: instalar Chrome en la Mini (cambia una máquina que no es de este encargo).

**D2 · ¿Se compila la 2.1 para grabar tomas nuevas?** → No. Salud financiera y Flujo de caja se montan con pantallas reales 2.1 fijas del banco; el cap. 6 encadena dos grabaciones reales 2.1 (`t3-planificados`, `t3-recordatorios`).
Por qué: el simulador de la Max tiene la 2.2 y otra sesión estaba archivando; compilar es de Frank y el método de pantallas fijas ya se aprobó en la semana 3. Alternativa descartada: build de `origin/1.0` (compite con el archivado y sale del territorio de marketing).

**D3 · ¿El 16:9 de X necesita un `*-x.mp4` vertical como en la semana 3?** → No: la misma receta de música se aplica directamente sobre el mudo 16:9.
Por qué: el pedido no pide el vertical con música y el nivel sale igual (medido). Alternativa descartada: generar verticales que nadie va a publicar.

**D4 · Lámina de avisos del carrusel Black Friday** → Se usa: 2.1 avisa al cruzar los umbrales de cada presupuesto (comprobado en `origin/1.0`, `BudgetAlertService`), con la pantalla real «Alertas 50%, 75%, 100%».
Por qué: el pedido la pide y es factual. Alternativa descartada: hablar de los recordatorios diarios, que no son un tope.

**D5 · ¿Se hace P6 «Grupos paso a paso»?** → No.
Por qué: es opcional, y su lámina de «iCloud privado» es falsa en 2.1 (Grupos vive en la nube de Yala, lo dice el texto de privacidad de la app y el criterio de copy de `marketing/README.md`). Alternativa descartada: rehacer la cuarta lámina por mi cuenta (cambia el contenido pedido).

**D6 · Frase 3 de Flujo de caja, que Whisper oye como pregunta** → Dos reintentos con el mismo ajuste; las tres tomas salen igual, va la primera y queda anotada en `PARA-LOLA-semana-4.md` con las otras dos al lado.
Por qué: lo pidió Jürgen así (no cambiar parámetros). Alternativa descartada: reescribir la frase sin su visto bueno.

**D7 · Decisiones del 9-nov pendientes de incorporar** → Las dos van a `marketing/README.md`, en «Decisiones de publicación». La de «esta semana a mano» se anota con su alcance (9 al 15-nov).
Por qué: el README de marketing es donde viven el criterio de copy y las decisiones de esta carpeta. Alternativa descartada: un ADR en `docs/DECISIONS.md` (es el registro de la app, no de redes).
