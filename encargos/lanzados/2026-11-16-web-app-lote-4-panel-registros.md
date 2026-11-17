Yala
# Yala web como la app · lote 4: Panel, Registros y Nuevo registro
---
toca: webapp/src/client/app/Panel.tsx, webapp/src/client/app/Registros.tsx, webapp/src/client/app/Apuntar.tsx, webapp/src/client/app/FilaRegistro.tsx, webapp/src/client/app.css, webapp/test/, docs/web-app/parecida-a-la-app/capturas/lote-4/, tickets/done/2026-11-16-web-app-lote-4-panel-registros.md
esfuerzo: high
cierre: cierra-sola
---

## Contexto
Jürgen (16-nov, 17:45 Lima) revisó la maqueta comentable «Yala web lo más parecida posible a Yala móvil» (PR #1007, `docs/web-app/parecida-a-la-app/index.html` y su `README.md`) y aprobó **todo lo recomendado**. Esto implementa el lote 4 de los seis de su «Plan por lotes».

Va después del lote 3 («Yala web como la app · lote 3: navegación de cristal en escritorio y celular»): parte de `2.3` con ese PR mergeado. Si no lo está al arrancar, no dupliques su trabajo: espera la decisión como vital según el modo.

Decisiones aprobadas (las recomendadas de la maqueta): tema oscuro Liquid Glass por defecto con selector en Ajustes (Como el sistema, Claro, Oscuro, Liquid Glass); barra lateral de cristal en escritorio, como la app en iPad; en celular las pestañas de la app (Panel, Registros, Grupos y Más, con Buscar aparte, Bandeja arriba a la izquierda y «+ Nuevo registro» en el contenido); Voz, Foto y Yala IA no se muestran hasta que la web los tenga (Yala IA sigue en la barra lateral con «Pronto»); íconos Lucide con tabla desde los SF Symbols; cifras en letra redondeada del sistema con Nunito de respaldo; Planificación y Distribución se suman al Panel, como en la app.
Además, el hero del Panel de la app (saldo grande con rótulo claro, «?» que explica la cifra y sin hueco antes del valor) es el estándar de claridad: aplícalo donde la web muestre una cifra principal.

## Lote 4 · Panel, Registros y Nuevo registro
Saldo de hoy, cuentas, filas con ícono y píldoras, días con su total, detalle a la derecha en escritorio y la hoja «Nuevo registro» centrada en el monto.

Archivos previstos: webapp/src/client/app/Panel.tsx, webapp/src/client/app/Registros.tsx, webapp/src/client/app/Apuntar.tsx, webapp/src/client/app/FilaRegistro.tsx (nuevo), webapp/src/client/app.css.
Pruebas: las de Registros (filtros, CSV, cargar más) y las de borradores siguen en verde.

## Cómo entregar
- Usa `docs/web-app/parecida-a-la-app/herramientas/` para las capturas de antes y después en claro y oscuro, escritorio y celular (390 px), guardadas en `docs/web-app/parecida-a-la-app/capturas/lote-4/`.
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

Hechos medidos antes de decidir: el lote 3 está mergeado en `2.3` (la rama nace de su merge); el núcleo manda los gastos
con signo negativo (`buscar_movimientos`, tests de CSV), la necesidad de cada registro y `divisa_preferida`; el total del
Panel es el saldo de la app («ni excluidas ni archivadas», incluye tarjetas); la app tiene en sus 16 idiomas todos los
rótulos que hacen falta (`panel.hero.haveToday`, `panel.saldo.info.balanceBody`, `panel.panorama.title`,
`panel.hero.leftNow/leftPast`, `l2d.amount.question.*`, `l2d.note.example`, `need.*`).

**D1 · Textos nuevos en 14 idiomas, con los i18n fuera de `toca:`** → se añaden 11 claves a `i18n/*.ts`, copiadas de
`Localizable.strings` de la app (es-AR y en-GB con su variante cuando la app la tiene). Por qué: la decisión «Nombres: los
de la app» pide «Tu saldo hoy», «Tus finanzas», «Te queda»; copiar de la app no inventa traducción. Alternativa
descartada: reusar «Saldo total» y los textos de hoy — deja el Panel con los nombres que la maqueta marcó como diferencia.

**D2 · El «?» del hero del Panel** → botón «?» junto a «Tu saldo hoy» que despliega debajo la explicación de la app
(«Suma todas tus cuentas, también las tarjetas…») y, si toca, el aviso de aproximado. Sin hoja aparte. Por qué: es el
estándar de claridad pedido (17:21) y la web no tiene «Tu dinero hoy» ni elegir cuentas, que es lo demás de la hoja de la
app. Alternativa descartada: copiar la hoja entera — promete un ajuste que la web no tiene.

**D3 · Resumen «Te queda» de Registros** → arriba de la lista, con `/api/estadisticas` del período (Este mes: «Te queda»;
Mes pasado: «Te quedó»), entradas, salidas y número de movimientos, solo sin filtro de cuenta, categoría ni texto. Con
filtros o con «Todo» no sale. Por qué: son las cifras de Estadísticas (la misma regla de la app); sumarlas en la página
con la lista paginada daría otra cifra. Alternativa descartada: cambiar el Worker para que `/api/registros` mande totales
— toca el núcleo y está fuera del lote.

**D4 · Total de cada día** → lo gastado ese día, como la cabecera de día de la app (`dayTotals(...).expense`, con signo):
suma de los gastos en la divisa preferida, sin ingresos, transferencias ni ajustes. No sale si algún gasto del día no
tiene importe convertido, ni en el último día de la página mientras quede «Cargar más» (estaría a medias), ni si es 0.
Por qué: es la cifra de la app y no inventa una conversión.

**D5 · Detalle en escritorio** → a partir de 1100 px de ventana, la lista a la izquierda y el detalle a la derecha (se
abre el primero al cargar); por debajo, la hoja de siempre. ⌘K sigue abriendo el detalle en hoja. Por qué: la maqueta
aprobada; 1100 px es donde caben lista y detalle junto a la barra lateral.

**D6 · Filtros de Registros** → cápsulas de cristal: período (Este mes, Mes pasado, Todo) como cápsula desplegable,
Cuenta y Categoría igual, el buscador de notas y «Exportar CSV» al final de la fila. Por qué: el estilo de la app sin
perder lo que la web ya hace. Alternativa descartada: el menú «…» de la maqueta para Exportar — un menú propio con
teclado es trabajo y riesgo para un solo botón; queda anotado.

**D7 · Hoja «Nuevo registro»** → centrada en el monto: «Hoy» en cápsula (abre el calendario del navegador), Gasto o
Ingreso, la descripción grande con el ejemplo de la app, «¿Cuánto gastaste?» y el monto grande con la divisa en rosa
(ingreso en turquesa), hasta tres categorías sugeridas, y Cuenta y Categoría en cápsulas. El botón dice «Enviar a la
Bandeja». Sin Mi parte, Favorito, Recurrente ni Etiquetas (la web no los tiene). Escritorio: centrada a 560 px; celular:
sube desde abajo. Las sugeridas salen de las subcategorías de los últimos registros del Panel. Por qué: la maqueta, sin
prometer lo que el borrador no guarda.

**D8 · Planificación y Distribución en el Panel** → entran (decisión «panel-widgets» A): Distribución con las categorías
de gasto del mes (con su ícono y color de `/api/categorias`) y Planificación con «Por pagar en los próximos 30 días» y
los dos presupuestos más gastados. Cada título lleva a su pantalla. Por qué: Jürgen lo aprobó; los datos ya existen.

**D9 · Ficheros fuera de `toca:`, mínimos** → `Shell.tsx` (pasa «+ Nuevo registro» bajo el hero en el celular, la
navegación del Panel y las sugeridas), `api.ts` (`divisa_preferida` en la página de Registros), `i18n/*.ts` (D1) y la
herramienta de capturas (`servidor-maqueta.mjs`: gastos con signo negativo, como el núcleo; `capturar-pantallas.mjs`
nuevo, para la hoja y el detalle). Se anotan en «Decidido sin consultar».

**D10 · Producción** → se despliega solo si todo está en verde y hay credenciales en esta máquina (la Max); si no las
hay, no se buscan: queda en «Necesita de ti». Por qué: «sin credenciales nuevas inventadas».
