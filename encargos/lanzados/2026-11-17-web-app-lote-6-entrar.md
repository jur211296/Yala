Yala
# Yala web como la app · lote 6: pantalla de entrada y código QR
---
toca: webapp/src/client/App.tsx, webapp/src/client/QrLogin.tsx, webapp/src/client/styles.css, webapp/test/, docs/web-app/parecida-a-la-app/capturas/lote-6/, tickets/done/2026-11-16-web-app-lote-6-entrar.md
esfuerzo: high
cierre: cierra-sola
---

## Contexto
Jürgen (16-nov, 17:45 Lima) revisó la maqueta comentable «Yala web lo más parecida posible a Yala móvil» (PR #1007, `docs/web-app/parecida-a-la-app/index.html` y su `README.md`) y aprobó **todo lo recomendado**. Esto implementa el lote 6 de los seis de su «Plan por lotes».

Va después del lote 5 («Yala web como la app · lote 5: Planificación, Estadísticas, Grupos, Bandeja y Ajustes»): parte de `2.3` con ese PR mergeado. Si no lo está al arrancar, no dupliques su trabajo: espera la decisión como vital según el modo.

Decisiones aprobadas (las recomendadas de la maqueta): tema oscuro Liquid Glass por defecto con selector en Ajustes (Como el sistema, Claro, Oscuro, Liquid Glass); barra lateral de cristal en escritorio, como la app en iPad; en celular las pestañas de la app (Panel, Registros, Grupos y Más, con Buscar aparte, Bandeja arriba a la izquierda y «+ Nuevo registro» en el contenido); Voz, Foto y Yala IA no se muestran hasta que la web los tenga (Yala IA sigue en la barra lateral con «Pronto»); íconos Lucide con tabla desde los SF Symbols; cifras en letra redondeada del sistema con Nunito de respaldo; Planificación y Distribución se suman al Panel, como en la app.
Además, el hero del Panel de la app (saldo grande con rótulo claro, «?» que explica la cifra y sin hueco antes del valor) es el estándar de claridad: aplícalo donde la web muestre una cifra principal.

## Lote 6 · Entrar
Pantalla de entrada y del código QR sobre el degradado de la bienvenida de la app.

Archivos previstos: webapp/src/client/App.tsx, webapp/src/client/QrLogin.tsx, webapp/src/client/styles.css.
Pruebas: entrar con Apple, Google y QR en staging; Turnstile visible en los dos temas.

## Cómo entregar
- Usa `docs/web-app/parecida-a-la-app/herramientas/` para las capturas de antes y después en claro y oscuro, escritorio y celular (390 px), guardadas en `docs/web-app/parecida-a-la-app/capturas/lote-6/`.
- `npm run typecheck` y `npm test` de la web en verde.
- Las direcciones de hoy (/registros, /presupuestos, /pagos…) siguen funcionando.
- Producción: Jürgen autorizó el 16-nov ir subiendo Yala web a producción (app.yala-app.pe) para probarla con su cuenta personal; todavía no está enlazada desde la web principal y eso no cambia. Despliega a producción solo con todo en verde y pruébalo de punta a punta allí, como se hizo en «Yala web en producción probada de punta a punta» (PR #1001). Entrar con Apple, Google y QR se prueba en staging antes de producción.
- Entregable visual: artifact de Claude con antes y después lado a lado de cada pantalla tocada, junto a la app como referencia. Nunca Markdown ni PDF como entregable.

## Reglas
- Toca solo lo declarado. Si hace falta otro archivo, agrégalo de forma mínima y anótalo en «Decidido sin consultar».
- Commits y PR sin firma de IA. PR contra `2.3`.
- Si necesitas mirar la app como referencia: en la Max puedes usar un segundo simulador (además del de otra sesión) o el iPhone 14 conectado por DeviceMCP; en la Mini, uno solo.
- Lo menor y reversible lo decides con la opción recomendada y lo anotas. Lo vital se pregunta según el modo fijado al arrancar (semi 05:30–20:00: pregunta y espera viva; nocturno 20:00–05:30: checkpoint recuperable y card «Espera decisión» para Jürgen, sin mergear ni desplegar lo incompleto).
- Sin credenciales nuevas inventadas: los secretos de producción ya están en su lugar (Turnstile en la Mini, `~/Secrets/yala-web-production/`); nunca los imprimas.
- Cierre: si está completo y el modo lo permite, `/cerrar-total`. El cierre incluye «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», el link del artifact y el link de producción si se desplegó.

## Paso 0 (resuelto por la sesión, 17-nov, Max)

Base: `2.3` al día, con el lote 5 mergeado (PR #1015). Referencia medida en Swift, no a ojo: `WelcomeF2Background`
y `WelcomeAccessButton` de `Yala/App/Views/Onboarding/WelcomeShowcaseView.swift`.

1. **Fondo: el de la bienvenida de la app 2.3 (F2), no el lineal de la maqueta.** Base `#08081A`, brillo índigo
   `#6063F1` al 62 % centrado a media anchura y al 26 % de alto, y un toque turquesa al 14 % arriba a la derecha. La
   maqueta dibujó el índigo→negro lineal del onboarding viejo (no tenía captura de la app para esta pantalla); el encargo
   dice «el degradado de la bienvenida de la app». Reversible: es un bloque de CSS.
2. **La entrada es siempre oscura, en cualquier tema**, como la bienvenida de la app («solo oscura», SPEC 2.3). Vale
   para entrar, el QR, la página de la cámara (`/v/…`), los avisos y «sin nube». Turnstile se pide en oscuro para que
   se vea sobre ese fondo con el sistema en claro y en oscuro.
3. **Botones: los de la app** (tres iguales, cristal blanco al 10 %, borde al 22 %, 50 px de alto, radio 16, 17
   semibold, ícono a la izquierda: manzana de Apple, «G» de Google en color, iPhone). La maqueta pintaba Apple en
   blanco; la app lo retiró el 13-nov («los blancos gritan mucho») y manda la app.
4. **Logo, título y ancho: los de la maqueta aprobada**: el cuadrado índigo→rosa de 64 px se mantiene, «Entra a tu
   Yala» a 30 px, sin tarjeta: el contenido va sobre el fondo, de 420 px en escritorio y a todo el ancho en celular.
5. **Textos sin cambios**: los 16 idiomas ya dicen lo mismo que la maqueta.
6. **Sin tocar la app con sesión**: todo el estilo nuevo cuelga de `.entrada`; `.btn`, `.fade` y `.brand` siguen
   sirviendo a Ajustes y al resto como hoy.
7. Pruebas de interfaz: solo navegador sin cabeza (Playwright) contra el servidor de maqueta y staging; no hay
   simulador ni XCUITest en este lote.
