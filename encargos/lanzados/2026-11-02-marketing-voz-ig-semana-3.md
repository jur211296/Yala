# Mezcla con voz de los 3 reels IG de semana 3

## Contexto
La tanda 2 de semana 3 (PR #743) dejó los 3 reels IG mudos porque faltaba la voz. Las voces ya están generadas: 15 mp3 en `reels/apple-pay/con-audio/_voz/`, `reels/siri-atajos/con-audio/_voz/` y `serie/yala-en-20-segundos/es/con-audio/_voz/`.
Card del tablero: tablero-mezcla-con-voz-de-los-reels-ig-semana-3-vfsf.

## Objetivo
Sacar `apple-pay-es-ig.mp4`, `siri-atajos-es-ig.mp4` y `cap-05-grupos-es-ig.mp4` con voz y música.

## Problema
El ffmpeg de `mezcla.py ig apple-pay` se colgó 20 minutos al 99 % de CPU. Usa un filter_complex con `volume` eval=frame, 5 `adelay`, `amix`, `apad`/`atrim` y `alimiter`, con `-c:v copy`. El log está en `_fuente/semana3/voz-ig.log`.
Hay que arreglarlo, por ejemplo con ducking por tramos fijos en vez de eval=frame, o mezclando primero el audio a wav y después muxeando con el video. Después corre los tres.

## Que NO hay que tocar
- Las versiones `-x` ni las 16:9.
- No regenerar voces salvo que una frase esté mal. Si hace falta la clave de ElevenLabs, pídesela a Lola.

## Como se sabe que esta bien
- Los 3 mp4 existen con voz y música.
- ffprobe da ok.
- La duración es igual a la de la versión muda.
- Hay hoja de control.
- La voz está sincronizada con las escenas: revisado con forma de onda o con los tiempos contra `voz.json`.

## Cierre
Termina con /cerrar-total.

## Paso 0

- **Repo:** `mezcla.py`, `voz.json` y los vídeos viven en `/Users/jur/Claude/marketing/biblioteca/`, fuera de git. En Yala solo entra este encargo.
- **El cuelgue:** el ffmpeg del 2-nov seguía vivo casi 3 h después (PID 68012, 99 % de CPU). No murió con SIGTERM y se mató con `kill -9`. El `apple-pay-es-ig.mp4` a medias se sobrescribe.
- **Arreglo:** se aplican las dos vías del encargo a la vez. (1) El ducking va por tramos fijos: los intervalos de voz se fusionan en Python, también los separados por menos de 0,5 s, y cada tramo es un `volume` con `enable=between(...)` y una sola rampa. Se acaba el `max()` anidado de cinco `clip()` sobre todo el reel. (2) La mezcla son dos pasos: primero un WAV de solo audio, sin vídeo en el grafo, y después el mux con `-c:v copy`. Fuera `apad`. Cada ffmpeg lleva un `timeout` de 120 s para que un cuelgue falle en vez de quedarse callado. La rama `x` no se toca.
- **Receta de sonido:** la misma de la tanda 3b: música −5,1 dB, −12 dB bajo la voz con rampas de 0,15 s, voz +2,5 dB y limitador a 0,89.
- **Sincronía (decisión):** en los tres reels la frase del gancho dura ~3 s y pisaba la 2 durante 0,6–0,8 s. Las voces están bien, así que no se regeneran. Se retrasa su `t` en `voz.json` y quedan 0,25 s de aire entre frases. Apple-pay: 1 → 0,0, 2 → 3,45 y 3 → 6,6. Siri-atajos: 1 → 0,0 y 2 → 3,3. Cap-05: 2 → 3,45. Hay copia en `voz.json.bak-20261102`.
- **Asumido:** en apple-pay, «Lo configuras una sola vez, con Atajos» acaba en 6,33 s y su escena en 5,4 s. Se come 0,9 s de «Pagas, y llega a tu Bandeja». Evitarlo pide acelerar la voz o recortar la frase, y aquí no se hace ninguna de las dos.

## Parte

- **Hecho:** los tres `*-es-ig.mp4` salen con voz y música en 0,6 s cada uno, frente a los 20 min colgados de antes.
- **Verificado:** ffprobe sin error, h264 1080×1920 más AAC 48 kHz estéreo, y la decodificación completa sin errores. La duración coincide con la del mudo al milisegundo: 16,833 / 16,600 / 20,000 s. Sonoridad −18,4 / −18,9 / −16,2 LUFS, con picos a −3 dBFS.
- **Sincronía:** la hoja con forma de onda está en `_fuente/semana3/sincronia-voz-ig-es.png`. Ninguna frase se pisa. Fuera de la voz el IG suena como la versión X (−15,5 dB RMS), y bajo la voz la música cae y deja −22 dB.
- **Hojas de control:** `hoja-<reel>-es-ig.jpg` junto a cada mp4.
- **Respaldo:** `mezcla.py.bak-colgado-20261102`.
