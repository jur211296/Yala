# Vista previa del iPad 13" en en-GB, pt-BR y pt-PT (4-nov-2026)

Pedido de Lola, aprobado por Jürgen. Nada se subió a App Store Connect: lo cargan Lola y Dan.

## Dónde están los videos

En la Mini, en la misma estructura que los de es/en:
`~/Claude/marketing/biblioteca/asc/vista-previa/<idioma>/`

| Idioma | Vertical 1200×1600 | Horizontal 1600×1200 |
|---|---|---|
| en-GB | `en-GB/yala-vista-previa-ipad-13-vertical.mp4` | `en-GB/yala-vista-previa-ipad-13-horizontal.mp4` |
| pt-BR | `pt-BR/yala-vista-previa-ipad-13-vertical.mp4` | `pt-BR/yala-vista-previa-ipad-13-horizontal.mp4` |
| pt-PT | `pt-PT/yala-vista-previa-ipad-13-vertical.mp4` | `pt-PT/yala-vista-previa-ipad-13-horizontal.mp4` |

Cada uno tiene su `-poster.jpg`. Medido con `ffprobe`: H.264 High, 30 fps, ~11 Mbps CBR; AAC estéreo 48 kHz en
silencio; 28,6–28,7 s (Apple admite de 15 a 30); ~39 MB.

## Cómo se hicieron

La misma plantilla «set B» de los videos de es/en (`~/Claude/marketing/biblioteca/_fuente/reels/plantilla/`), el
mismo movimiento de cámara y las mismas cuatro escenas (Yala IA, foto, voz y Grupos). La pantalla es la toma 2.2 que
el lote de la ficha ya había grabado en cada idioma, con libras y euros (`ficha-app-store/video/`). Las piezas
quedaron en `_fuente/reels/piezas/vp-<idioma>-ipad[-horizontal]/` y la receta, en el README de `_fuente`.

## Frases

**en-GB**: el texto en inglés de es/en, tal cual. **pt-BR y pt-PT: BORRADOR de copy**, traducido del set B por Frank,
pendiente de que lo revisen Lola y Jürgen antes de subirlo a la ficha.

| Escena | en-GB | pt-BR (borrador) | pt-PT (borrador) |
|---|---|---|---|
| Yala IA | Text **Yala AI** / and it's logged. | Escreva pra **Yala IA** / e fica anotado. | Escreva à **Yala IA** / e fica registado. |
| Foto | Or snap / the **receipt**. | Ou tire **foto** / da nota. | Ou tire **foto** / ao talão. |
| Voz | Or just / **say** it. | Ou só **fale** / do seu jeito. | Ou basta **dizer** / à sua maneira. |
| Grupos | Shared bills, / all **square**. | Contas **claras** / entre amigos. | Contas **certas** / entre amigos. |
| Cierre | Your finances, / **effortlessly**. | Suas finanças, / sem **esforço**. | As suas finanças, / sem **esforço**. |
| Etiqueta 1 | Pizza · £24.00 | Pizza · R$ 90,00 | Pizza · € 26,00 |
| Etiqueta 2 | Owed to you · £190 | Te devem · R$ 380 | Devem-te · € 190 |

El cierre sale del molde de cada idioma (`ficha-app-store/textos/<idioma>.js`, `VIDEO.cierre`).

Las etiquetas repiten el monto que se ve en pantalla en ese momento. En en-GB se pidió «Pizza · £28.00», pero en la
toma la pizza es de £24.00: con el visto bueno de Lola va £24.00.

## Hojas

Un fotograma por escena, más las dos etiquetas y el cierre: `hoja-<idioma>-<vertical|horizontal>.jpg`.
Pósters verticales: `poster-<idioma>-vertical.jpg`.
