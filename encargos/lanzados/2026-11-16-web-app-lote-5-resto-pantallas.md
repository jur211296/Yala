Yala
# Yala web como la app · lote 5: Planificación, Estadísticas, Grupos, Bandeja y Ajustes
---
toca: webapp/src/client/app/Presupuestos.tsx, webapp/src/client/app/Pagos.tsx, webapp/src/client/app/Estadisticas.tsx, webapp/src/client/app/Grupos.tsx, webapp/src/client/app/Bandeja.tsx, webapp/src/client/app/Configurar.tsx, webapp/src/client/app.css, webapp/src/client/i18n/*.ts, webapp/test/, docs/web-app/parecida-a-la-app/capturas/lote-5/, tickets/done/2026-11-16-web-app-lote-5-resto-pantallas.md
esfuerzo: high
cierre: cierra-sola
---

## Contexto
Jürgen (16-nov, 17:45 Lima) revisó la maqueta comentable «Yala web lo más parecida posible a Yala móvil» (PR #1007, `docs/web-app/parecida-a-la-app/index.html` y su `README.md`) y aprobó **todo lo recomendado**. Esto implementa el lote 5 de los seis de su «Plan por lotes».

Va después del lote 4 («Yala web como la app · lote 4: Panel, Registros y Nuevo registro»): parte de `2.3` con ese PR mergeado. Si no lo está al arrancar, no dupliques su trabajo: espera la decisión como vital según el modo.

Decisiones aprobadas (las recomendadas de la maqueta): tema oscuro Liquid Glass por defecto con selector en Ajustes (Como el sistema, Claro, Oscuro, Liquid Glass); barra lateral de cristal en escritorio, como la app en iPad; en celular las pestañas de la app (Panel, Registros, Grupos y Más, con Buscar aparte, Bandeja arriba a la izquierda y «+ Nuevo registro» en el contenido); Voz, Foto y Yala IA no se muestran hasta que la web los tenga (Yala IA sigue en la barra lateral con «Pronto»); íconos Lucide con tabla desde los SF Symbols; cifras en letra redondeada del sistema con Nunito de respaldo; Planificación y Distribución se suman al Panel, como en la app.
Además, el hero del Panel de la app (saldo grande con rótulo claro, «?» que explica la cifra y sin hueco antes del valor) es el estándar de claridad: aplícalo donde la web muestre una cifra principal.

## Lote 5 · Planificación, Estadísticas, Grupos, Bandeja y Ajustes
Cada pantalla con las piezas de la app y su adaptación a escritorio: dos columnas en Presupuestos, grupo abierto a la derecha, Bandeja como panel lateral y Ajustes a 700 px.

Archivos previstos: webapp/src/client/app/Presupuestos.tsx, webapp/src/client/app/Pagos.tsx, webapp/src/client/app/Estadisticas.tsx, webapp/src/client/app/Grupos.tsx, webapp/src/client/app/Bandeja.tsx, webapp/src/client/app/Configurar.tsx, webapp/src/client/app.css, webapp/src/client/i18n/*.ts.
Pruebas: escritura en Grupos en staging (nuevo gasto, saldar, invitar) antes de producción.

## Cómo entregar
- Usa `docs/web-app/parecida-a-la-app/herramientas/` para las capturas de antes y después en claro y oscuro, escritorio y celular (390 px), guardadas en `docs/web-app/parecida-a-la-app/capturas/lote-5/`.
- `npm run typecheck` y `npm test` de la web en verde.
- Las direcciones de hoy (/registros, /presupuestos, /pagos…) siguen funcionando.
- Producción: Jürgen autorizó el 16-nov ir subiendo Yala web a producción (app.yala-app.pe) para probarla con su cuenta personal; todavía no está enlazada desde la web principal y eso no cambia. Despliega a producción solo con todo en verde y pruébalo de punta a punta allí, como se hizo en «Yala web en producción probada de punta a punta» (PR #1001). Lo que escribe en Grupos se prueba en staging antes de producción.
- Entregable visual: artifact de Claude con antes y después lado a lado de cada pantalla tocada, junto a la app como referencia. Nunca Markdown ni PDF como entregable.

## Reglas
- Toca solo lo declarado. Si hace falta otro archivo, agrégalo de forma mínima y anótalo en «Decidido sin consultar».
- Commits y PR sin firma de IA. PR contra `2.3`.
- Si necesitas mirar la app como referencia: en la Max puedes usar un segundo simulador (además del de otra sesión) o el iPhone 14 conectado por DeviceMCP; en la Mini, uno solo.
- Lo menor y reversible lo decides con la opción recomendada y lo anotas. Lo vital se pregunta según el modo fijado al arrancar (semi 05:30–20:00: pregunta y espera viva; nocturno 20:00–05:30: checkpoint recuperable y card «Espera decisión» para Jürgen, sin mergear ni desplegar lo incompleto).
- Sin credenciales nuevas inventadas: los secretos de producción ya están en su lugar (Turnstile en la Mini, `~/Secrets/yala-web-production/`); nunca los imprimas.
- Cierre: si está completo y el modo lo permite, `/cerrar-total`. El cierre incluye «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», el link del artifact y el link de producción si se desplegó.

## Paso 0 — decisiones

> Resueltas en autónomo (modo nocturno): las recomendaciones se dan por buenas. Se discuten en el PR.

Hechos medidos antes de decidir: el lote 4 está mergeado en `2.3` (la rama nace de su merge). La API no manda ícono ni
color de presupuestos, cobros ni trozos de Estadísticas: solo el nombre (`Cobro.categoria` es la subcategoría o, sin
ella, la categoría; `Trozo.categoria`, la categoría). Los grupos sí traen `icono` y `color`. Las cifras de Estadísticas
dejan fuera transferencias y ajustes de saldo (`summary.ts`). La app tiene en sus 16 idiomas «Bandeja de Entrada»
(`inbox.title`), «Ajustes» (`profile.title`), «Te quedan» / «Te pasaste por» / «En el límite» / «Te pasaste»
(`budgets.l9.*`) y «Te deben en total · en %@» / «Debes en total…» / «Estás a mano…» (`groups.hero.net*`). Credenciales
de Cloudflare: solo en la Mini (se despliega por `ssh`, como los lotes 1 a 4).

**D1 · Ícono y color sin tocar el servidor** → se buscan por nombre en `/api/categorias` (categoría o subcategoría), con
un hook compartido y en caché (`app/categorias.ts`, nuevo). Sin coincidencia, el respaldo de la app («tag.fill» y el
color por defecto; en presupuestos, «chart.pie.fill» con el acento). Por qué: el lote es visual; cambiar el Worker y el
núcleo para mandar `icon_name` es otro alcance. Alternativa descartada: añadir `icono`/`color` a `/api/presupuestos` y
`/api/pagos` — toca `shared-core` y su paridad.

**D2 · Presupuestos** → tarjeta de la app (`BudgetRowView`): círculo con ícono y color, nombre, «S/ 1,461.00 de
S/ 1,800.00 · 15 días», a la derecha «Te quedan» y la cifra (o «Te pasaste por» en rosa con ⚠), barra del color de la
categoría, ámbar en riesgo y rosa al pasarse, con «En el límite» / «Te pasaste» debajo. Títulos de sección sueltos
(Excedidos, Activos, Inactivos), sin tarjeta contenedora; en escritorio dos columnas. Sin navegador de período: la web
solo tiene el período en curso.

**D3 · Pagos planificados** → «Por pagar en los próximos 30 días» como cifra principal sobre el fondo, con «?»; filas con
el ícono de la categoría; días como en Registros; en escritorio Próximos cobros a la izquierda y Suscripciones a la
derecha.

**D4 · Estadísticas** → segmentos con ícono y texto en el orden de la app (Resumen, Tendencias, Distribución); el período
como cápsula desplegable (la de Registros); «Te queda» / «Te quedó» como cifra principal con «?», entradas y salidas con
flechas de color; Gasto medio diario y Gasto más alto en tarjetas, en la misma fila que la cifra en escritorio; «Dónde
gastaste más» con ícono y color de cada categoría. Fuera: la gráfica «Gastos del mes» acumulada día a día (la API no
manda serie diaria) y «Tu salud financiera» (se calcula en el iPhone).

**D5 · El «?» de las cifras nuevas** → Estadísticas, Pagos y Grupos llevan el «?» del Panel con un texto que dice de
dónde sale la cifra. Son tres textos nuevos (la app no tiene uno equivalente), traducidos a los 14 idiomas de la web.
Por qué: el estándar de claridad del 16-nov (17:21).

**D6 · Grupos** → arriba, con una sola divisa, «Te deben en total · en S/» (o «Debes…», «Estás a mano…») con el neto en
grande, la barra rosa y verde y «Debes» / «Te deben» a los lados; con varias divisas, las líneas de hoy. Tarjetas con el
ícono y el color del grupo. Desde 1100 px de ventana, la lista a la izquierda y el grupo abierto a la derecha (se abre
el primero), con «Nuevo gasto», «Saldar» e «Invitar» como cápsulas en su cabecera y Saldos, Gastos y Pagos como
pestañas; por debajo, se entra al grupo como hoy. Las tres escrituras no cambian (mismos formularios, mismas llamadas).
Fuera: «Nuevo gasto» en la portada (en la app elige grupo; la web no tiene ese selector).

**D7 · Bandeja** → panel lateral de cristal encima de la pantalla en la que estás (escritorio) y hoja que sube desde
abajo (celular), con «Bandeja de Entrada», la cápsula «N pendientes», «Esperando a tu iPhone» (editar y descartar como
hoy) y «Por revisar en tu iPhone» con la fila de Registros y la píldora del origen. `/bandeja` sigue abriendo: debajo va
la sección de inicio. Cerrar (✕, Esc o tocar fuera) vuelve a la dirección de debajo. Sin segmento «Archivados»: la web
no los lee. Requiere tocar `Shell.tsx` (fuera de `toca:`, mínimo).

**D8 · Ajustes** → «Configurar» pasa a llamarse «Ajustes» (el nombre de la app, en sus 16 idiomas) y `/configurar` sigue
siendo su dirección. Columna de 700 px centrada en escritorio; cabecera con el avatar grande, el nombre y el correo;
grupos de filas con cuadrito de color e ícono (Tu cuenta, Sesiones web, En esta web) y «Salir de Yala web» al final.
Sin «Editar perfil» ni insignia Pro: la web no los tiene.

**D9 · Limpieza anotada en el lote 4** → se quitan `app.apuntar` y `app.apuntarTitulo` de los 14 idiomas (sin uso).

**D10 · Ficheros fuera de `toca:`, mínimos** → `Shell.tsx` (Bandeja encima de la sección), `app/categorias.ts`,
`app/pantallas.ts` y `app/Cifra.tsx` (nuevos: el hook de D1, lo que deciden las pantallas sin navegador para probarlo, y
la cifra principal con «?», compartida por tres pantallas), `docs/TICKETS.md`, dos tickets de backlog con lo encontrado,
y en `herramientas/` el guion de capturas y el recorrido del lote 5 más dos comprobaciones del recorrido de navegación
del lote 3 que esperaban los nombres de antes («Bandeja» como título, «Configurar»). Se anotan en «Decidido sin
consultar».

**D11 · Pruebas de escritura en Grupos** → nuevo gasto, saldar e invitar contra staging con el usuario de prueba antes de
producción (Playwright en la Mini, donde viven las credenciales). Producción: se despliega solo con todo en verde.
