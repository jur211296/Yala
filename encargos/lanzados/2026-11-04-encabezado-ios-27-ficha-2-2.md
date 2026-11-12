# Encabezado de página de iOS 27 para la ficha 2.2 de App Store: video 21:9 en loop, y 3:2 si sale fácil
toca: propuestas-ficha-2-2-encabezado

Base: origin/2.2 en jur211296/Yala. Una sola sesión, un cierre. Card: «Encabezado de página de iOS 27 para la ficha 2.2: vídeo 21:9 en loop (y 3:2 si sale fácil)». Jürgen pidió que la 2.2 salga sí o sí con esto.
Arma un video 21:9 de 3840×1646, de 5 a 30 s, a 30 o 60 fps, en .mov, .m4v o .mp4, sin audio, que se reproduzca solo y en loop sin corte visible. Tiene que mostrar una sola idea clara que se entienda sin sonido. Puede salir de los reels que ya existen en ficha-app-store/video. Si sale fácil, haz también la versión 3:2 (entre 1920×1280 y 3840×2560) o una universal. Guías: https://developer.apple.com/app-store/asset-best-practices/ y https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications/
No lo subas a App Store Connect: déjalo en ~/Claude/propuestas/ dentro de la carpeta de la 2.2, con la ruta y un fotograma en el PR para que Jürgen lo apruebe. Lo suben Jürgen o Dan. Mueve la card a «in qa». Si tienes una duda que cambie el resultado, pregunta con preguntar-bot; no la asumas.

Termina con /cerrar-total.

## Paso 0 — decisiones (resueltas en autónomo, bypass; idiomas respondidos por el bot dueño)

1. **Idea única:** «le dices un gasto a Yala IA y queda anotado». Toma real `ia` del molde: aparece la burbuja, los tres puntos y la tarjeta del registro. Se descartan foto, voz y Grupos: serían cuatro ideas.
2. **Texto encima: ninguno.** Solo el logo y el iPhone (el bot: «lo ideal, universal sin texto»). Lo único que cambia por idioma es la pantalla grabada.
3. **Idiomas:** es (principal), en, en-GB, pt-BR y pt-PT, los mismos de la vista previa. La toma de español se regraba con la build 2.2 (`video/grabar.sh es ia`), porque la de 2.1 tiene otra bienvenida.
4. **Zona segura:** la burbuja y la tarjeta caen dentro de la zona segura de Apple (21:9: 1646×661 centrada; 3:2: 2168×1030). El teléfono es grande y se corta por abajo, para que el iPad, que enseña el lienzo entero, no lo vea diminuto (la lección de la portada 2.2).
5. **Loop:** fondo quieto y fundido de 0,8 s de la tarjeta a la bienvenida, cosido de modo que el último fotograma enlaza con el primero.
6. **Formato:** H.264 High, `.mp4`, 30 fps, sin pista de audio, de 8 s. 21:9 a 3840×1646 y 3:2 a 3840×2560 (el máximo).
7. **Dónde vive:** el molde en `ficha-app-store/encabezado/` (es código del molde y no de `marketing/`) y la salida en `~/Claude/propuestas/ficha-app-store-2.2/<idioma>/encabezado/`. No se sube a App Store Connect.
