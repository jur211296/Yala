Yala
# Yala web como la app · lote 2: íconos y colores de categoría desde la nube
---
toca: shared-core/src/toolCore.ts, shared-core/src/data.ts, webapp/src/worker/data.ts, webapp/src/client/app/api.ts, webapp/src/client/app/simbolos.ts, webapp/src/client/app/icons.tsx, webapp/package.json, webapp/package-lock.json, shared-core/test/, gateway/test/, webapp/test/, docs/web-app/parecida-a-la-app/capturas/lote-2/, tickets/done/2026-11-16-web-app-lote-2-iconos-categoria.md
esfuerzo: high
cierre: cierra-sola
---

## Contexto
Jürgen (16-nov, 17:45 Lima) revisó la maqueta comentable «Yala web lo más parecida posible a Yala móvil» (PR #1007, `docs/web-app/parecida-a-la-app/index.html` y su `README.md`) y aprobó **todo lo recomendado**. Esto implementa el lote 2 de los seis de su «Plan por lotes».

Va después del lote 1 («Yala web como la app · lote 1: base visual en claro y Liquid Glass»): parte de `2.3` con ese PR mergeado. Si no lo está al arrancar, no dupliques su trabajo: espera la decisión como vital según el modo.

Decisiones aprobadas (las recomendadas de la maqueta): tema oscuro Liquid Glass por defecto con selector en Ajustes (Como el sistema, Claro, Oscuro, Liquid Glass); barra lateral de cristal en escritorio, como la app en iPad; en celular las pestañas de la app (Panel, Registros, Grupos y Más, con Buscar aparte, Bandeja arriba a la izquierda y «+ Nuevo registro» en el contenido); Voz, Foto y Yala IA no se muestran hasta que la web los tenga (Yala IA sigue en la barra lateral con «Pronto»); íconos Lucide con tabla desde los SF Symbols; cifras en letra redondeada del sistema con Nunito de respaldo; Planificación y Distribución se suman al Panel, como en la app.
Además, el hero del Panel de la app (saldo grande con rótulo claro, «?» que explica la cifra y sin hueco antes del valor) es el estándar de claridad: aplícalo donde la web muestre una cifra principal.

## Lote 2 · Íconos y datos de categoría
El servidor manda el ícono y el color de categoría, subcategoría y cuenta, y la necesidad de cada registro. Ya están en la nube; hoy la web no los pide. Tabla de SF Symbol a Lucide y cambio de los íconos propios por Lucide.

Archivos previstos: shared-core/src/toolCore.ts, shared-core/src/data.ts, webapp/src/worker/data.ts, webapp/src/client/app/api.ts, webapp/src/client/app/simbolos.ts (nuevo), webapp/src/client/app/icons.tsx, webapp/package.json (lucide-react).
Toca el núcleo que comparten el gateway y la web: va con revisión adversarial y con las pruebas de shared-core, del gateway y de la web.

## Cómo entregar
- Usa `docs/web-app/parecida-a-la-app/herramientas/` para las capturas de antes y después en claro y oscuro, escritorio y celular (390 px), guardadas en `docs/web-app/parecida-a-la-app/capturas/lote-2/`.
- `npm run typecheck` y `npm test` de la web en verde, más las pruebas de shared-core y del gateway, con revisión adversarial del cambio en el núcleo compartido.
- Las direcciones de hoy (/registros, /presupuestos, /pagos…) siguen funcionando.
- Producción: Jürgen autorizó el 16-nov ir subiendo Yala web a producción (app.yala-app.pe) para probarla con su cuenta personal; todavía no está enlazada desde la web principal y eso no cambia. Despliega a producción solo con todo en verde y pruébalo de punta a punta allí, como se hizo en «Yala web en producción probada de punta a punta» (PR #1001). El gateway (servidor MCP) solo se despliega si el cambio en shared-core lo exige, primero en staging y con sus pruebas en verde; si hay cualquier riesgo para los clientes de Claude o ChatGPT, pregúntalo como vital.
- Entregable visual: artifact de Claude con antes y después lado a lado de cada pantalla tocada, junto a la app como referencia. Nunca Markdown ni PDF como entregable.

## Reglas
- Toca solo lo declarado. Si hace falta otro archivo, agrégalo de forma mínima y anótalo en «Decidido sin consultar».
- Commits y PR sin firma de IA. PR contra `2.3`.
- Si necesitas mirar la app como referencia: en la Max puedes usar un segundo simulador (además del de otra sesión) o el iPhone 14 conectado por DeviceMCP; en la Mini, uno solo.
- Lo menor y reversible lo decides con la opción recomendada y lo anotas. Lo vital se pregunta según el modo fijado al arrancar (semi 05:30–20:00: pregunta y espera viva; nocturno 20:00–05:30: checkpoint recuperable y card «Espera decisión» para Jürgen, sin mergear ni desplegar lo incompleto).
- Sin credenciales nuevas inventadas: los secretos de producción ya están en su lugar (Turnstile en la Mini, `~/Secrets/yala-web-production/`); nunca los imprimas.
- Cierre: si está completo y el modo lo permite, `/cerrar-total`. El cierre incluye «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», el link del artifact y el link de producción si se desplegó.

## Paso 0 — decisiones

> Resueltas por la sesión (modo semi, ninguna es vital): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Cómo manda el servidor ícono, color y necesidad sin tocar el conector de Claude ni Yala IA?** → Un indicador `apariencia` en `ToolContext` que solo pone el Worker de la web. Con él, `listar_cuentas`, `listar_categorias` y `buscar_movimientos` piden también `icon_name,color_hex` y añaden campos AL FINAL de cada fila. Sin él (conector, gateway) las consultas y las respuestas son las de hoy, byte a byte.
Por qué: la paridad del conector (`mcp/test/shared-core-parity.test.ts`) fija qué pide y qué devuelve; el modelo no gana nada con íconos. Alternativa descartada: añadir los campos para todos (cambia el contrato del conector y obliga a desplegar el gateway).

**D2 · ¿Ícono y color ya resueltos o crudos?** → En los registros, resueltos con la regla de la fila de la app (`RecordRowView`: ícono de la subcategoría o de la categoría, color de la categoría; `null` = respaldo de la app). En cuentas, la regla `displayIconName` (propio, si no por tipo, si no el banco). En categorías y subcategorías, crudos: cada pantalla de la app elige su respaldo.
Por qué: la regla vive una sola vez, en el núcleo, como pide R1. Alternativa descartada: resolver en la página (tres sitios con la misma regla).

**D3 · ¿Qué necesidad se manda?** → `effectiveNeed` de la app tal cual (`need_override`, si no la naturaleza de la subcategoría, si no «sin_clasificacion»), siempre. La página decide la píldora (la app solo la pinta con subcategoría).

**D4 · Color e ícono, ¿se validan?** → Sí, en el servidor: color solo `#RRGGBB` (6 cifras hex), ícono solo forma de SF Symbol; lo demás sale `null`. Por qué: van a un `style` y a una tabla; un texto libre no tiene sitio ahí.

**D5 · ¿Dónde se ven los íconos en este lote?** → Navegación entera con Lucide (`icons.tsx`), el círculo de la fila de registros (Panel, Registros, Buscar) con el ícono y el color de la categoría en vez de la inicial, y las tarjetas de cuenta del Panel con el ícono de la cuenta (el fondo sigue siendo el de la base: con el color de la cuenta, el texto blanco no siempre se lee, y las tarjetas son del lote 4). Añade `Panel.tsx` (mínimo). Lo demás (píldoras, filas de 40 px, Estadísticas, Pagos) es de los lotes 4 y 5.
Por qué: sin un sitio donde verse, los datos nuevos no se pueden comprobar en las capturas. Alternativa descartada: rediseñar la fila ahora (es el lote 4).

**D6 · Pruebas de shared-core** → No hay `shared-core/test/`: sus pruebas corren en `mcp/test/` (lo dice su README). Se añaden allí, junto a la paridad que demuestra que el conector no cambia.

**D7 · Despliegue** → Web a producción tras todo verde (autorizado). Gateway: no se despliega; el cambio no le alcanza (D1) y su CI lo prueba.

**D8 · Versión de lucide-react** → 1.66.0 exacta (31-oct-2026, más de dos semanas).

**D9 · Ícono de cuenta: ¿`displayIconName` o el del carrusel del Panel?** → `displayIconName` (listas y selectores de la app). El carrusel de la app usa el ícono crudo y el diseño de tarjeta guardado; eso entra con las tarjetas del lote 4. Lo señaló la revisión adversarial.
