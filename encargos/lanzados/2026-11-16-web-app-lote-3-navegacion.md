Yala
# Yala web como la app · lote 3: navegación de cristal en escritorio y celular
---
toca: webapp/src/client/app/Shell.tsx, webapp/src/client/app.css, webapp/src/client/app/Busqueda.tsx, webapp/wrangler.toml, webapp/test/movil.test.ts, webapp/test/, docs/web-app/parecida-a-la-app/capturas/lote-3/, tickets/done/2026-11-16-web-app-lote-3-navegacion.md
esfuerzo: high
cierre: cierra-sola
---

## Contexto
Jürgen (16-nov, 17:45 Lima) revisó la maqueta comentable «Yala web lo más parecida posible a Yala móvil» (PR #1007, `docs/web-app/parecida-a-la-app/index.html` y su `README.md`) y aprobó **todo lo recomendado**. Esto implementa el lote 3 de los seis de su «Plan por lotes».

Va después del lote 2 («Yala web como la app · lote 2: íconos y colores de categoría desde la nube»): parte de `2.3` con ese PR mergeado. Si no lo está al arrancar, no dupliques su trabajo: espera la decisión como vital según el modo.

Decisiones aprobadas (las recomendadas de la maqueta): tema oscuro Liquid Glass por defecto con selector en Ajustes (Como el sistema, Claro, Oscuro, Liquid Glass); barra lateral de cristal en escritorio, como la app en iPad; en celular las pestañas de la app (Panel, Registros, Grupos y Más, con Buscar aparte, Bandeja arriba a la izquierda y «+ Nuevo registro» en el contenido); Voz, Foto y Yala IA no se muestran hasta que la web los tenga (Yala IA sigue en la barra lateral con «Pronto»); íconos Lucide con tabla desde los SF Symbols; cifras en letra redondeada del sistema con Nunito de respaldo; Planificación y Distribución se suman al Panel, como en la app.
Además, el hero del Panel de la app (saldo grande con rótulo claro, «?» que explica la cifra y sin hueco antes del valor) es el estándar de claridad: aplícalo donde la web muestre una cifra principal.

## Lote 3 · Navegación
Barra lateral de cristal en escritorio; barra flotante con Buscar aparte en celular; Bandeja desde su botón; avatar hacia Ajustes; «+ Nuevo registro» en la cabecera. Planificación reúne Presupuestos y Pagos, y /presupuestos y /pagos siguen abriendo su segmento.

Archivos previstos: webapp/src/client/app/Shell.tsx, webapp/src/client/app.css, webapp/src/client/app/Busqueda.tsx, webapp/wrangler.toml (ruta /planificacion), webapp/test/movil.test.ts.
Pruebas: navegación con teclado, ⌘K, enlaces viejos y 390 px de ancho sin scroll lateral.

## Cómo entregar
- Usa `docs/web-app/parecida-a-la-app/herramientas/` para las capturas de antes y después en claro y oscuro, escritorio y celular (390 px), guardadas en `docs/web-app/parecida-a-la-app/capturas/lote-3/`.
- `npm run typecheck` y `npm test` de la web en verde.
- Las direcciones de hoy (/registros, /presupuestos, /pagos…) siguen funcionando.
- Producción: Jürgen autorizó el 16-nov ir subiendo Yala web a producción (app.yala-app.pe) para probarla con su cuenta personal; todavía no está enlazada desde la web principal y eso no cambia. Despliega a producción solo con todo en verde y pruébalo de punta a punta allí, como se hizo en «Yala web en producción probada de punta a punta» (PR #1001).
- Entregable visual: artifact de Claude con antes y después lado a lado de cada pantalla tocada, junto a la app como referencia. Nunca Markdown ni PDF como entregable.

## Reglas
- Toca solo lo declarado. Si hace falta otro archivo, agrégalo de forma mínima y anótalo en «Decidido sin consultar».
- Commits y PR sin firma de IA. PR contra `2.3`.
- Si necesitas mirar la app como referencia: en la Max puedes usar un segundo simulador (además del de otra sesión) o el iPhone 14 conectado por DeviceMCP; en la Mini, uno solo.
- Lo menor y reversible lo decides con la opción recomendada y lo anotas. Lo vital se pregunta según el modo fijado al arrancar (semi 05:30–20:00: pregunta y espera viva; nocturno 20:00–05:30: checkpoint recuperable y card «Espera decisión» para Jürgen, sin mergear ni desplegar lo incompleto).
- Sin credenciales nuevas inventadas: los secretos de producción ya están en su lugar (Turnstile en la Mini, `~/Secrets/yala-web-production/`); nunca los imprimas.
- Cierre: si está completo y el modo lo permite, `/cerrar-total`. El cierre incluye «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», el link del artifact y el link de producción si se desplegó.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass, modo nocturno): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Cómo se modela Planificación sin romper `/presupuestos` y `/pagos`?** → Una sección nueva `planificacion` con dos segmentos; `/presupuestos` y `/pagos` siguen siendo direcciones propias que abren Planificación en su segmento, y `/planificacion` abre Presupuestos. Tocar un segmento cambia la dirección a la suya, así que recargar deja el mismo segmento.
Por qué: los enlaces viejos y la búsqueda (que manda a «Presupuestos») siguen funcionando sin redirecciones. Alternativa descartada: redirigir las viejas a `/planificacion?seg=` — más cambio, y rompe el «atrás» del navegador.

**D2 · ¿Hace falta tocar `wrangler.toml` para `/planificacion`?** → No, si se confirma: el Worker ya sirve la página para cualquier dirección que no sea `/api` ni `/auth` (`not_found_handling = "single-page-application"`). Se fija con una prueba en vez de con una línea de configuración.
Por qué: tocar la configuración de producción sin necesidad es riesgo sin beneficio. Alternativa descartada: una regla de ruta explícita.

**D3 · ¿Dónde va la lógica de rutas?** → En un módulo puro nuevo `webapp/src/client/app/navegacion.ts`, probado en `test/navegacion.test.ts`.
Por qué: la suite corre en Node, sin navegador; el Shell carga los textos al importarse. Alternativa descartada: probar a través del Shell con un DOM falso (dependencia nueva).

**D4 · Textos nuevos.** → Una sola clave, `app.nuevoRegistro`, con la traducción que ya usa la app (`transaction.new`) en los 11 idiomas base; las variantes regionales la heredan. «Configurar» no se renombra a «Ajustes» en este lote: el avatar lleva a Configurar con su nombre de hoy.
Por qué: el renombrado de secciones toca Configurar y los 14 idiomas, que son del lote 5. Alternativa descartada: renombrar ya — pisaría el lote 5.

**D5 · «+ Nuevo registro» en el celular: ¿en qué pantallas?** → En Panel y Registros, como cápsula índigo al principio del contenido. En escritorio, en la cabecera de todas las secciones de la nube completa (como hoy «Apuntar»).
Por qué: es donde lo pone la app; en Planificación, Grupos o Configurar la acción principal es otra. Alternativa descartada: en todas — ruido en pantallas que no registran.

**D6 · El ojo de ocultar montos y la búsqueda.** → El ojo se queda en la cabecera en los dos tamaños. En escritorio, Buscar es el campo de la barra lateral (con ⌘K o Ctrl K según el sistema); en celular, la lupa redonda junto a las pestañas. La lupa de la cabecera de escritorio se retira (la sustituye el campo).
Por qué: es lo que dibuja la maqueta aprobada. Alternativa descartada: mantener las dos lupas — duplicado.

**D7 · «Más» en el celular.** → Tarjetas con ícono de color: Bandeja (con su contador), Estadísticas, Presupuestos y Pagos planificados bajo «Planificación», Configurar y Yala IA con «Pronto». Sin la línea de descripción de la maqueta (pediría textos nuevos en 14 idiomas; va con el lote 5 si se quiere).
Por qué: navegación completa sin abrir alcance de textos. Alternativa descartada: copiar las descripciones de la maqueta.

**D8 · Cuenta «solo Grupos».** → Pestañas Grupos y Configurar, más la lupa; sin botón de Bandeja ni «+ Nuevo registro», como hoy.
Por qué: no tiene nube completa. Alternativa descartada: ninguna razonable.

**D9 · Pruebas de teclado, ⌘K, enlaces viejos y 390 px.** → Unitarias en Node (rutas y CSS) + un recorrido en Chromium sin cabeza contra el servidor de maqueta (Tab por la barra lateral, ⌘K abre y Esc cierra devolviendo el foco, `/presupuestos` `/pagos` `/planificacion` abren su segmento, ancho de documento ≤ 390 en celular). El recorrido queda como script en `docs/web-app/parecida-a-la-app/herramientas/`.
Por qué: la suite de la web no tiene navegador; no se añade Playwright como dependencia del proyecto. Alternativa descartada: vitest con jsdom (dependencia nueva).

**D10 · Producción.** → Se despliega a app.yala-app.pe solo con typecheck, tests y recorrido en verde, y se prueba allí de punta a punta como en el PR de producción probada (navegar, enlaces viejos, ⌘K, celular). Si el despliegue o la prueba no son posibles desde la Max (credenciales), se anota y no se busca otra vía.
