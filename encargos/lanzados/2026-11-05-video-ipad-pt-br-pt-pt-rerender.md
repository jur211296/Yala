# Video iPad 13" pt-BR y pt-PT: copy de la app + pizza ~1,9 s
toca: `marketing/biblioteca/_fuente/reels/piezas/vp-pt-BR-ipad*`, `marketing/biblioteca/_fuente/reels/piezas/vp-pt-PT-ipad*`, `marketing/biblioteca/asc/vista-previa/{pt-BR,pt-PT}/`, `ficha-app-store/textos/pt-PT.js` (capturas); sin código de la app iOS

Rama base: **2.2**. Lane Lola / marketing. Prioridad PRIMERA en cola (Jürgen vía Lola 2026-11-05). Sin simulador. Un solo PR si hace falta (copy/json en repo); salidas en biblioteca. Card: «Video iPad 13" vista previa: re-render pt-BR y pt-PT (copy app + pizza ~1,9 s)», cierra-sola.

## Contexto
Los videos iPad 13" de vista previa en pt-BR y pt-PT (set B, 4-nov) tienen copy desalineado con la app y la etiqueta de pizza corta (~1,05 s). Receta en `~/Claude/marketing/biblioteca/_fuente/README.md` → `reels/plantilla/reel-setb.sh`. Piezas: `reels/piezas/vp-pt-BR-ipad`, `vp-pt-BR-ipad-horizontal`, `vp-pt-PT-ipad`, `vp-pt-PT-ipad-horizontal`.

## Qué se pide
1. Corregir copy en los 4 `reel.json` (vertical + horizontal):

**pt-BR**
- Badge/destacado «Te devem · R$ 380» → «Devem a você · R$ 380» (como dice la app).

**pt-PT (trato de «tu», como la app)**
- «Escreva à Yala IA / e fica registado.» → «Escreve à Yala IA / e fica registado.»
- «Ou tire foto / ao talão.» → «Ou fotografa / o talão.»
- «Ou basta dizer / à sua maneira.» → «Ou diz / à tua maneira.»
- Lema «As suas finanças, sem esforço.» → «As tuas finanças, sem esforço.»
- Ese lema sale también de `ficha-app-store/textos/pt-PT.js`: alinear el mismo trato «tu» en las capturas pt-PT si el texto está ahí.

2. En pt-BR y pt-PT (vertical y horizontal): alargar la etiqueta de la pizza de ~1,05 s a ~1,9 s, como en es/en (ej. es: 4,74→6,64).

3. Re-render con la receta del README:
   `cd ~/Claude/marketing/biblioteca/_fuente/reels && ./plantilla/reel-setb.sh piezas/<pieza> ../../asc/vista-previa/<idioma>/yala-vista-previa-ipad-13-<vertical|horizontal>.mp4 <segundo-póster>`
   (pt-BR póster ~5,6; ajustar si el README indica otro).

4. Salida exacta:
   `~/Claude/marketing/biblioteca/asc/vista-previa/{pt-BR,pt-PT}/yala-vista-previa-ipad-13-{vertical,horizontal}.mp4`
   con su `-poster.jpg` junto a cada mp4. Duración entre **15 y 30 s**.

5. Mueve la card con `tablero`: in progress al empezar; done al cerrar (o in qa solo si hace falta ojo de Jürgen).
6. Al cerrar, el digest debe decirle a Frank/Lola que avise a Dan para subir los videos a App Store Connect.

## Qué NO hay que tocar
- Videos de otros idiomas (es, en, en-GB).
- Código de la app iOS, gateway, TestFlight.
- Publicar en ASC (eso lo hace Dan después).
- No asumas copy distinto al listado: si la app dice otra cosa, `preguntar-bot`.

## Cómo se sabe que está bien
- 4 mp4 + 4 posters en las rutas de arriba, 15–30 s cada video.
- Textos pt-BR/pt-PT como arriba; pizza ~1,9 s; lema/capturas pt-PT con «tu».
- Termina con `/cerrar-total` (cierra-sola). Sección «Saltado o asumido sin preguntar».

PREGUNTAR, NO SALTAR. Habla con el bot dueño (`preguntar-bot`) si bloquea. Da siempre una descripción corta en español a cada Bash.
