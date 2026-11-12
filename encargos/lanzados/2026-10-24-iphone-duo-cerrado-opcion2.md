# iPhone Duo cerrado: barra vertical en todas las vistas (opción 2), comentarios de Jürgen y propuestas de ancho

## Contexto
El PR #622 adaptó Yala al iPhone Duo. Jürgen revisó las capturas el 2026-10-24 y decidió la opción 2 de la barra, dejó comentarios del modo cerrado y pidió propuestas de ancho. Rama base: `2.2`. El brief completo, que es la fuente, está abajo y en `~/Claude/tmp-frank/iphone-duo-cerrado-opcion2-y-comentarios.md`; las notas originales en `~/Claude/tmp-frank/duo-comentarios-jurgen-2026-10-24.md`. Card: `tablero-iphone-duo-los-botones-de-barra-de-solo-l31e`.

## Simuladores
Regla de Jürgen: en sesiones Duo se borran los demás simuladores y queda solo el del Duo. Al terminar, se desinstala el Duo y se vuelve a instalar el iPhone (el iPad solo si hace falta). Pipeline serial de la Mini: limpiar, build con `xcodebuild -jobs 2` sin simulador encendido, encender uno, tests, apagarlo.
Al lanzar y al cerrar, borra el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen, sin preguntar.

# Duo cerrado · opción 2 + comentarios Jürgen (una sesión)

Fuente: Jürgen 2026-10-24 (opción 2 ~19:22; comentarios C1/C4/C5/alcance ~19:22–20:05; tanda cerrada ~20:25 Lima).
Card barra: `tablero-iphone-duo-los-botones-de-barra-de-solo-l31e`.
Notas completas: `~/Claude/tmp-frank/duo-comentarios-jurgen-2026-10-24.md`
Skills Apple en Mini: exportar/leer `app-resizability` y `swiftui-whats-new-27` (`xcrun agent skills export`).

## Alcance
- **Solo Duo cerrado.** Abierto (horizontal / vertical / pliegue) OK: no rediseñar.
- Consistencia en cerrado: una sola regla de layout; no mezclar «unas vistas bajo glass y otras no».
- NO incluir consistencia botón «nuevo» vs FAB (card `kzhe`, al final de la cola).

## Qué hacer (en orden)

### 1) Opción 2 barra (decidida)
- Aplicar `.toolbarVerticalCompressionBehavior(.prefersToolbarItems)`.
- Avatar y acciones de toolbar en la **barra vertical en TODAS las vistas** (no solo Panel). Jürgen aún ve avatar en títulos de algunas (p. ej. Estadísticas) → unificar.
- NO texto→icono app-wide en iPhone normal.

### 2) Comentarios de diseño cerrado
- **C1 Welcome:** cerrado disparejo por hueco a la derecha; cards flotantes salen por la izquierda. Evaluar usar todo el ancho incl. zona de la barra vertical para centrar, o la regla que salga de (3).
- **C4 Panel:** cuentas bajo «tus finanzas» usan todo el ancho (incluso detrás de la barra) con liquid glass; widgets no — disparejo.
- **C5 Estadísticas (+ resto):** mismo tema; avatar aún en título en algunas vistas.

### 3) Ancho / safe area — PROPUESTAS (no fijar a ciegas)
Jürgen ve el «ancho seguro» como cortado: la barra vertical parece pieza aparte, no parte de la página.
- Investigar con skills Apple.
- Dejar **propuestas + capturas lado a lado** de al menos:
  - **A:** contenido/controles en safe area (recomendación Apple).
  - **B:** contenido o fondos bajo/detrás del glass de forma coherente en TODAS las vistas cerradas (como las cuentas del Panel hoy).
- Carpeta: `~/Claude/tmp-frank/duo-propuestas-ancho-2026-10-24/` (o `capturas/` del worktree + md resumen).
- Md corto: pros/contras, qué dice Apple, recomendación.
- Si A/B no se pueden mergear sin decisión: aplicar (1) y fixes claros de (2) que no dependan del ancho; dejar pregunta + capturas; **parar** (sin /cerrar-total ciego). Si todo queda aplicado con una opción marcada como propuesta por defecto y la otra solo en capturas, OK — Jürgen revisa y otra sesión aplica el cambio de ancho si hace falta.

## Criterio hecho
- Opción 2 en Duo cerrado, avatar en barra vertical en todas las vistas tocadas.
- C1/C4/C5 abordados o con propuesta visual clara.
- Capturas antes/después Duo cerrado + propuestas A/B de ancho.
- Abierto no empeorado.

## NO tocar
- marketing/, FAB vs botón nuevo (kzhe), rediseño de abierto H/V/P.

## Paso 0 (Frank, 2026-10-24 — auto-contestado, sesión lanzada)

1. **Simuladores.** Al arrancar había solo un iPhone 17 Pro (runtime 27.0) y ningún runtime 27.1, que es el mínimo del
   Duo. Se baja el 27.1 con `xcodebuild -downloadPlatform iOS`, se borra el iPhone 17 Pro y se crea
   `YalaLane-Adapt-iPhone-Duo`. El runtime 27.0 se deja instalado sin dispositivos (como en #622): hace falta al cerrar
   para el iPhone 17 Pro. *Asumido.*
2. **Opción 2 de la barra.** `.toolbarVerticalCompressionBehavior(.prefersToolbarItems)` en cada una de las siete
   páginas de pestaña, dentro de su pila (puesto en la `TabView` o en cada `Tab` no hacía nada: medido). El avatar
   (`ProfileToolbarItem`) pasa a la barra vertical desde el propio componente, así no hay página que se quede fuera.
   **Las dos cosas solo en ancho compacto**: abierto en horizontal la compresión plegaba las siete pestañas del Panel y
   el avatar se iba a «···», donde una vista propia no se pinta; el abierto no se rediseña. *Asumido.*
3. **Texto → icono no se hace** (lo prohíbe el encargo). «Seleccionar» de Registros (solo texto) se retira cuando hay
   barra vertical (`\.toolbarVerticalEdge`); sigue en «···». `.axisBehavior(.horizontalOnly)` no bastaba: la barra del
   título grande es horizontal y lo dejaba ahí. Los «Cancelar / Hecho» de hojas y el «👥 3» del detalle de grupo quedan
   como están. *Asumido.*
4. **Ancho.** Regla por defecto aplicada: **A, todo en el ancho seguro** (Apple, `app-resizability` y HIG del Duo:
   contenido y controles fuera de la barra; solo fondos debajo). En un solo sitio: `scrollViewGlassEdges` recorta el
   scroll de la página por el lado de la barra, y el Welcome lo lleva a mano. La B queda en capturas
   (`qa/evidencia-duo-cerrado-20261024/`) y la pregunta en el ticket `iphone-duo-closed-width-a-or-b`, con la
   excepción posible del Welcome. No se para por ella: el encargo admite cerrar con una opción aplicada y la otra en
   capturas. *Asumido.*
5. **Abierto no se toca**: medido base contra A en horizontal y en vertical. Solo cambia, por la regla A, que la
   tarjeta de cuenta del Panel abierto en horizontal ya no pasa por debajo del «···».
6. **iPhone**: el runtime 27.1 solo admite el Duo, así que el iPhone 17 Pro vuelve con 27.0 y ahí todo lo nuevo es
   un no-op (`#available(iOS 27.1, *)`). Comparación al píxel base contra cambios: 0 px en las siete pantallas.
