# Reels 16:9 para X de Bandeja y Grupos (marketing semana 3)

## Contexto
Pedido de marketing Yala de la semana 3, aprobado por Jürgen hoy, lunes 2 de noviembre de 2026. Los reels de Bandeja y Grupos para X existen hoy solo en 9:16; hacen falta versiones 16:9. Arrancas en contexto limpio: todo lo necesario está aquí.

## Qué se pide
Solo las prioridades 1 y 2, en este orden. Avisa al cerrar cada una.

- **P1 — para HOY lunes 2 antes de las 12:00 (hora de Lima):** `reels/bandeja/con-audio/bandeja-es-x-16x9.mp4` y `reels/bandeja/con-audio/bandeja-en-x-16x9.mp4`, con la misma pista de audio y la misma duración que `bandeja-es-x.mp4` y `bandeja-en-x.mp4` (hoy en 9:16).
- **P2 — para el martes 3 antes de las 11:00 (hora de Lima):** `reels/grupos/con-audio/grupos-es-x-16x9.mp4` y `reels/grupos/con-audio/grupos-en-x-16x9.mp4`, con el mismo criterio respecto a sus versiones 9:16.

## Reglas
- Partir de la biblioteca `/Users/jur/Claude/marketing/biblioteca/`, con el mismo estilo, música y pipeline que la tanda del 25 de octubre: `PARA-LOLA-assets-x-16x9.md` y `_fuente/serie/hacer-x-16x9.sh`.
- Formato: 1920×1080, 30 fps, H.264 + AAC 48 kHz, con música y sin voz.
- Composición: frase a la izquierda y teléfono a la derecha, sin franjas negras y sin estirar nada.
- Usar pantallas reales de la app 2.1.
- El texto en español va en español neutro latinoamericano, nunca de España (nada de vosotros, móvil, ordenador, etc.).
- Registrar todo en `INDICE.md` y en `PARA-LOLA-semana-3.md`: el `ffprobe` de cada video, su duración y una hoja de control en .jpg por video.
- Si falta un dato, decide lo razonable, anótalo en `PARA-LOLA-semana-3.md` y sigue sin detenerte.

## Qué NO hay que tocar
- Prioridades 3 en adelante: no se hacen en esta sesión.
- Los 9:16 existentes no se modifican ni se sobrescriben.
- Nada de la app (código de Yala fuera de marketing).

## Cómo se sabe que está bien
- Existen los 4 mp4 16:9 con 1920×1080, 30 fps, H.264 + AAC 48 kHz, y la duración y la pista de cada uno coinciden con su 9:16.
- Cada video tiene su hoja de control .jpg y su ffprobe registrado en `INDICE.md` y `PARA-LOLA-semana-3.md`.
- Hubo un aviso al cerrar P1 y otro al cerrar P2.
- Termina con `/cerrar-total`.

## Paso 0

- **Pipeline:** `_fuente/reels/hacer-x-16x9.sh` ya mapeaba Bandeja (`t3-bandeja`) y Grupos (`reel3`); se le pasaron como argumento, sin tocar el script.
- **Pantallas 2.1:** se reutiliza el footage del 20-21 oct (app 2.1 real en simulador, datos de ejemplo, según `_fuente/README.md`); no se regraba.
- **Texto ES:** el mismo del 9:16. «Depa» es latinoamericano, se queda para que 16:9 y 9:16 cuenten lo mismo.
- **Hojas de control:** una por vídeo, junto al vídeo (8 fotogramas, 4×2).
- **Avisos P1/P2:** `PushNotification` + `SendUserFile` con los vídeos y las hojas; `avisar_grok.py` no tiene un motivo de hito intermedio.
- **Repo:** los entregables viven en `/Users/jur/Claude/marketing/biblioteca/`, fuera de git; en Yala solo entra este encargo.
