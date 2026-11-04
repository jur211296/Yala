# AnnotateKit en Yala Dev

Anotar una pantalla de Yala Dev (tocar, dibujar, escribir) y mandarla a la sesión de Claude en la Mac.
Solo existe en **Yala Dev en Debug**; el Yala de TestFlight y App Store no lo lleva (medido con
`strings`: 0 apariciones). Versión fijada: AnnotateKit 1.0.0 (MIT).

Video de la prueba en el simulador: [demo.mp4](demo.mp4).

## Una vez, en la Mac

1. Instala el programa que trae las notas a la Mac:
   `brew install ooolzhas/tap/annotate`
2. Comprueba que quedó: `annotate help` debe imprimir la ayuda.

## Cada vez que quieras anotar desde el iPhone

1. Conecta el iPhone a la Mac (cable, o la misma red Wi-Fi con el iPhone ya emparejado en Xcode).
2. En Xcode, abre `~/Yala`, elige el scheme **Yala Dev** y tu iPhone, y dale a ▶︎.
   Tiene que ser la build de ese mismo checkout: las notas vuelven a la carpeta del proyecto
   que compiló la app (`~/Yala/.annotate/`).
3. Abre Claude Code en `~/Yala` y pídele: «corre `annotate watch` con Monitor y atiende las notas que lleguen».
   En la app, el botón **Annotate** muestra un punto verde cuando alguien escucha.
4. En el iPhone, en la pantalla que quieras comentar:
   1. Toca **Annotate** (abajo, flotando).
   2. Toca un elemento, mantén pulsado en un punto, o dibuja con el dedo.
   3. Escribe la nota y toca **↑** en la tarjeta para guardarla. Puedes poner varias.
   4. Toca **↑** en la barra de abajo para enviar.
5. La barra va contando: «Claude received your notes» → «working» → «Claude is done».
   Para salir del modo anotar, **‹**.

## Bueno saber

- El botón **Annotate** no se arrastra: se aparta solo de las barras de la app. En el Welcome tapa en parte «Sin rastreo ni anuncios» (se ve en el video).
- No aparece en los tests automáticos ni en las capturas de XCUITest (se apaga con `-uitest`).
- La interfaz de AnnotateKit está en inglés; las notas puedes escribirlas en español.
- Alternativa sin pedirlo cada vez: el plugin de Claude Code (`/plugin install annotate --marketplace ooolzhas/annotatekit`).
  No está instalado: añade un hook a **todas** las sesiones y pide arrancar Claude con un flag experimental.
