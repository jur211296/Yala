# Piloto de Claude Motion · 4-nov-2026

> **Veredicto: se adopta como complemento, no como sustituto.** Motion iguala a los reels v3 cuando
> parte de la misma toma. Donde aporta algo nuevo es en las piezas hechas **solo con capturas** y en la
> **revisión por enlace**. El reel diario sigue con HyperFrames, porque Motion no exporta sin un clic en
> el navegador ni admite nuestra música elegida. Dinero extra: ninguno.

Nada de esto está publicado. Las tres piezas son artifacts privados de Jürgen.

## Las tres piezas

| Pieza | Enlace (privado) | Hecha con | Se compara con |
|---|---|---|---|
| **Voz** · «¿Sin tiempo para anotar?» · 19,6 s | [Yala · Voz](https://claude.ai/artifact/9v15MeNhDGtGvxNzVZ3pj5) | La misma toma, frases y tiempos del reel v3 | `voz-pop.mp4` de v3 |
| **Foto** · «¿Boletas para después?» · 18,5 s | [Yala · Foto](https://claude.ai/artifact/SGe55k7bnXu3pzadfW327n) | Ídem | `foto-pop.mp4` de v3 |
| **¿A dónde va tu dinero?** · 19 s | [Yala · Dinero](https://claude.ai/artifact/Spf7koD6TdiZWswfyuPS4D) | **Solo dos capturas reales de 2.2** (Panel y Estadísticas, semilla de la ficha) | `ia-pop.mp4` de v3, que cuenta lo mismo con una grabación |

Las tres siguen la guía de la serie: navy liso, estrellas planas de cuatro puntas, iPhone entero,
una frase por escena con una palabra subrayada, transiciones lentas y el cierre fijo de 3,5 s. No llevan
degradados ni brillos. Están en 9:16, a 1080×1920 y 30 fps, en soles y con datos de ejemplo.

## Qué se midió

**1 · Con la misma toma, el resultado es el mismo.** Las tiras de comparación (v3 arriba, Motion abajo)
coinciden fotograma a fotograma: encuadre, giro del teléfono, toques y cierre. Motion reproduce la toma
acelerada por tramos igual que la plantilla v3. Para eso se usa `kit.seek` con la misma tabla de
`tramos` de cada `reel.json`.

**2 · Por dentro es lo mismo que ya usamos.** Una pieza de Motion es HTML y JavaScript, donde cada
fotograma depende solo del tiempo. Es la misma idea que HyperFrames con GSAP. No genera vídeo con IA:
anima lo que le das. Por eso la regla «la UI de Yala no se dibuja, se filma» se cumple sin esfuerzo.

**3 · Lo que Motion añade y v3 no tiene**

- **Piezas sin grabación.** La pieza Dinero saca el balance y la tarjeta de categorías del teléfono,
  ampliados y legibles, a partir de dos PNG. Sirve para lo que no se puede grabar en el simulador:
  Apple Pay, Wallet, Siri, widgets, iPad.
- **Revisión por enlace.** Cada pieza es una página con línea de tiempo y comentarios fijados a un
  segundo. Además, el panel Tweaks deja cambiar el texto de una frase sin tocar código. Jürgen o Lola
  pueden corregir desde el móvil.
- **Música generada** dentro de la pieza, sincronizada con los toques y el cierre. Es original y sale de
  un sintetizador sencillo.
- **Exporta a MP4** desde la página: 720p o 1080p, 30 o 15 fps, con la opción «Sharper text».

**4 · Lo que Motion no puede, y es lo que decide**

- **No hay render por línea de comandos.** El MP4 sale solo del botón Export de la página, una pieza
  cada vez. El reel diario de v3 sale de un comando (`plantilla/reel.sh reels/<tema>`). Para un ritmo
  diario, Motion añade un paso manual.
- **No admite audio propio.** No puede usar la pista Pop (Mixkit 729) que eligió Jürgen el 13-oct ni
  una locución. Su música es de sintetizador. Si la pieza lleva nuestra música o voz, se mezcla
  después de exportar.
- **No dibuja la insignia oficial del App Store.** Motion no reproduce diseños de otras empresas. El
  cierre lleva el texto «Disponible en el App Store». Si la pieza se usa, la insignia se añade al
  editar.
- **Tipografía:** sale en Inter (Google Fonts), no en SF Pro. A tamaño de reel la diferencia es mínima.
  Se puede subir la fuente como archivo si se quiere idéntica.

## Costo

- **Dinero:** cero. Motion viene incluido en el plan Team y gasta el uso normal del plan; las piezas
  largas gastan más que un mensaje.
- **Tiempo (aproximado, medido en esta sesión):** la primera pieza costó alrededor de media hora,
  incluido aprender la herramienta. Con la plantilla ya hecha, Foto llevó unos 10 minutos y Dinero
  unos 15. Sobre eso va un clic de Export por pieza.

## Cuándo usarlo

| Caso | Herramienta |
|---|---|
| Reel diario o interdiario con toma del simulador, música Pop y voz | **HyperFrames v3**: un comando, sin manos |
| Función que no se puede grabar (Apple Pay, widgets, iPad), o pieza hecha de capturas de la ficha | **Motion** |
| Pieza que Jürgen quiere revisar y comentar por enlace antes de exportar | **Motion** |
| Presentación 16:9 por escenas | Remotion (`marketing/remotion/`), como hasta ahora |

## Cómo se trabaja una pieza

Las fuentes viven aquí y la pieza viva vive en el store de su artifact:

```
motion-piloto/
  comun/base.css      los colores y las clases de la serie (el color principal lo pone cada pieza)
  comun/shared.js     estrellas, frases con subrayado, la escena de toma y el cierre
  <pieza>/pieza.json  enlace del artifact, color principal y de dónde salen sus assets
  <pieza>/modules/    scenes.json, las escenas y la partitura
  herramientas/motion.py
```

1. `python3 herramientas/motion.py preparar <pieza> --player <copia del reproductor> --out <dir>` monta
   una carpeta para sacar fotogramas en local con el `render.mjs` de la referencia
   `render-offline.md` del tipo Motion.
2. `python3 herramientas/motion.py docs <pieza> --out <dir>` deja un JSON por documento. Se suben con
   `ArtifactData` (`batch`, con `file_path`) a la URL de `pieza.json`.
3. Las tomas y las capturas **no se commitean**: `pieza.json` dice de dónde salen.

Una pieza nueva de la serie con toma es solo configuración: copia `voz/`, cambia la toma, los
`tramos`, las frases y los toques.

## Antes de publicar cualquiera

- **Voz y Foto** repiten las tomas de v3 (13-oct). Valen las mismas notas de v3: la hoja de foto es de 2.1.
- **Dinero** usa capturas de la ficha 2.2 (semilla `ficha`): S/ 84,524 de balance, Hogar 47 % y
  Alimentación 28 %. No se usó la de Presupuestos, porque trae «Maia 🐶».
- Ninguna lleva voz. La música es la de Motion, no la Pop.
