Yala
# Modo claro: más contraste entre el fondo y los botones y campos blancos
---
toca: Yala/App/Theme/,Yala/App/DesignSystem/,YalaTests/ContrasteModoClaro/,tickets/backlog/2026-11-19-contraste-modo-claro-botones-blancos.md,tickets/done/2026-11-19-contraste-modo-claro-botones-blancos.md
esfuerzo: high
cierre: cierra-sola
depende:
---

Rama base: 2.3. Tokens de color en `Yala/App/Theme/` (DesignTokens, ThemeColor, YalaTheme, ViewModifiers) y componentes en `Yala/App/DesignSystem/`.

## Qué pidió Jürgen (19-nov, 12:51 Lima, con capturas del iPhone)
En modo claro, los campos y botones blancos (chips de atajos «Uber / Starbucks / Plaza Vea», «Hoy», sugerencias de categoría, «Categoría», «Etiquetas», USD, el campo «Escribe tu pregunta…», el botón + y la X de cerrar, y el botón de ajustes de Yala IA) casi no se distinguen del fondo de la hoja. No se ve el contorno, así que no se sabe qué es un botón. Opciones que propone: un fondo ligeramente más gris, una sombra suave en los blancos, o una combinación. Le gustó mucho una referencia («Send money»): el fondo es gris claro, las superficies y botones blancos están bien definidos y los botones circulares blancos se leen claramente sobre el fondo.

Capturas en la Mini, `~/Claude/flota/borradores/contraste-claro/`: `referencia-send-money.png` (la que le gustó), `actual-nuevo-registro.png` y `actual-yala-ia.png`. Si corres en la Max, cópialas con `scp` desde la Mini.

## Qué hacer
1. Resolverlo en los tokens, no pantalla por pantalla. En modo claro el fondo de pantallas y hojas pasa a un gris claro neutro, y las superficies, botones y campos blancos tienen una separación visible: un borde finísimo y/o una sombra muy suave, al estilo de la referencia. Elige la mejor combinación, compara dos o tres variantes y muestra la recomendada.
2. Modo oscuro sin cambios visibles, salvo que se rompa algo. Respetar los temas Pro y el Aumentar contraste del sistema.
3. Verificar en las pantallas de las capturas (Nuevo registro con y sin teclado, Yala IA) y en un barrido de Panel, Registros, Presupuestos, Pagos, Flujo de caja, Ajustes y las hojas principales. Nada debe quedar raro, como doble fondo o tarjetas que antes eran grises y ahora se funden. Contraste del contorno: que se lea en pantalla, no solo que cumpla un número.
4. Si una vista usa `Color.white` o un fondo fijo fuera de los tokens y por eso no hereda el cambio, la corrección mínima va permitida aunque esté fuera del toca. Anótala en «Decidido sin consultar». No toques las vistas de Flujo de caja que está editando otra sesión (`Yala/App/Views/Reports/CashFlow/`); si algo ahí necesita cambio, anótalo como pendiente.

## Cómo entregar
- Probar en claro y oscuro, en iPhone chico, iPhone grande y iPad, con el iPhone 14 por DeviceMCP. En la Max puedes usar un segundo simulador además del de otra sesión; en la Mini, uno solo. No uses `-derivedDataPath /tmp/claude-*`. Presupuesto de UI tests acotado: solo los nuevos en `YalaTests/ContrasteModoClaro/` (tokens claros distintos del blanco, por ejemplo). Si hace falta texto nuevo, va en una tabla propia, nunca en Localizable.strings. Nunca un botón debajo de otro.
- Entregable visual: un artifact de Claude con el antes y el después de cada pantalla (claro), las variantes comparadas junto a la referencia y una franja de modo oscuro para mostrar que no cambió. Nunca Markdown ni PDF.

## Reglas
- Sin esquema de datos nuevo. Commits y PR sin firma de IA, PR contra 2.3.
- Lo menor y reversible se decide con la opción recomendada y se anota. Lo vital, según el modo fijado al arrancar: en semi (05:30–20:00) preguntas y esperas con la sesión viva; en nocturno (20:00–05:30) dejas un checkpoint recuperable y una card «Espera decisión», sin mergear ni desplegar lo incompleto.
- Cierre: si está completo, con CI verde y el modo lo permite, `/cerrar-total`, con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», y el link del artifact.

## Paso 0 — decisiones

> Resueltas en semiautónomo por Frank: son menores y reversibles (colores de un token), así que van con la recomendación y se discuten en el PR.

**D1 · ¿Dónde se resuelve?** → En el tema, no por pantalla. (a) `YalaTheme.light.background` pasa a un gris claro neutro; (b) el relleno `.thCard` lleva en el tema claro su contorno dentro del propio estilo (`ShapeStyle.shadow`: una sombra de 0,5 pt que se lee como borde finísimo + una sombra suave); (c) el degradado de las pantallas completas (`PanelBackgroundView`) arranca en ese mismo gris.
Por qué: `.thCard` tiene 177 usos; con el contorno en el token todos lo heredan sin tocar 177 vistas. Alternativa descartada: un modificador de borde aplicado vista a vista (cientos de cambios y se olvidaría en las nuevas).

**D2 · ¿Qué gris y cuánto contorno?** → Se comparan tres variantes en el simulador (solo fondo gris · gris + borde finísimo · gris + borde + sombra suave, como la referencia «Send money») y se elige la que mejor se lea en pantalla. Recomendación de partida: gris `#F2F2F7` + borde + sombra suave.
Por qué: Jürgen pidió comparar y elegir la mejor combinación.

**D3 · El degradado índigo del Panel** → Se queda abajo (es identidad: tarjetas blancas sobre fondo no blanco); solo su parte de arriba, hoy casi blanca, pasa al gris.
Por qué: arriba es donde las tarjetas blancas se funden; abajo ya contrastan. Alternativa descartada: Panel gris plano (quita la marca).

**D4 · Modo oscuro y temas Pro** → Sin cambios: el contorno solo existe con `baseColorScheme == .light` y todos los temas Pro son oscuros.

**D5 · Aumentar contraste** → Colores dinámicos: con «Aumentar contraste» el gris baja un punto y el borde se marca más.

**D6 · Hojas a media altura con el cristal del sistema** → No se tocan (regla «Ninguna hoja con fondo gris», g1uw): pintan el glass del sistema, no `theme.background`.

**D7 · Usos del color crudo `theme.card`** (120) → Solo los de las pantallas de las capturas (chips de selección, etc.) pasan al token con contorno; el resto se deja salvo que el barrido enseñe algo raro.

**D8 · Contraste de texto** → El texto sobre el gris nuevo sigue en AA: lo fijan `ThemeTokenContrastTests` y los tests nuevos de `YalaTests/ContrasteModoClaro/`.

**D9 · Variantes para la comparación** → Un argumento DEBUG temporal (`-contrastVariant N`) para capturar las tres con un solo build; se retira antes del commit.

**D10 · Botones de cristal de la barra (X, ajustes de Yala IA)** → Son del sistema; ganan contorno con el fondo gris, no se rediseñan.
