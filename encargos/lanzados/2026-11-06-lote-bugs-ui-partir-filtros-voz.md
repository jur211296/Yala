# Lote · UI: línea de Partir, filtros de Estadísticas y perfil de voz
toca: Grupos Partir resumen, onChange Estadísticas Registros, perfil voz two Taxi

Rama base: origin/2.3. Un solo PR contra 2.3, un solo cierre. Máquina: la libre. Si la prueba va mejor en el celular que en el simulador, usa el iPhone 14 conectado por DeviceMCP. Si corres en la Max y otra sesión de otro proyecto ya usa un simulador, puedes abrir un segundo (tope 2 en la Max) o usar el iPhone 14 conectado por DeviceMCP. En la Mini el tope de simuladores es 1. Cierre autónomo. Termina con `/cerrar-total`. Commits y PR sin firma de IA.

## Contexto
Tres arreglos chicos de UI / datos:
1. Grupos B · línea resumen en «Partir»: «Debes S/ 510 a Pía · Sip sube S/ 500» (tablero-grupos-b-linea-resumen-en-partir-debes-s-uot1)
2. Estadísticas y Registros recalculan por filtros con el mismo onChange que dejó el Panel filtrado (tablero-estadisticas-y-registros-recalculan-por-yc2i)
3. Perfil de prueba de voz two pone Taxi en Restaurantes (tablero-perfil-de-prueba-de-voz-two-pone-taxi-en-2qvp)

## Qué se pide
Arreglar los tres; tests donde aplique; cards a `in qa` con guion corto.

## Qué NO hay que tocar
marketing/, reescrituras grandes de Grupos o del Panel.

## Cómo se sabe que está bien
Tres cards OK; gate verde; `/cerrar-total`.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · Base de la rama** → `origin/2.3`, como pide el encargo (el worktree nació sobre `2.2`; se rehízo la rama sobre `2.3` antes de tocar nada).
Por qué: la versión de las tres cards es 2.3. Alternativa descartada: 2.2, que el encargo no pide.

**D2 · Dónde va la línea resumen de «Partir»** → debajo de la tarjeta «Tu parte», en las dos superficies que la montan: la hoja de la Bandeja con «Partir» abierto y la hoja «Tu parte» (éxito y detalle del registro). Antes de tocar «Partir» no se añade nada.
Por qué: la maqueta (`opcion-b.html`, pantalla 4 del escenario 1 y 3 del 2) la pone ahí. Alternativa descartada: el «Debes S/ 510 a Pía» suelto en la hoja sin partir (pantalla 2): la card pide la línea «en Partir» y lo otro cambiaría la hoja de hoy.

**D3 · Qué dice si pagaste tú (Caso A)** → solo las cuentas que suben («Sip sube S/ 500»); sin parte de deuda. Si no hay recargas, no hay línea.
Por qué: tu parte no te hace deber nada cuando pagaste tú, y la maqueta solo dibuja el caso de pagó otro. Alternativa descartada: «Te deben S/ X», que habla de los demás y no de tu parte.

**D4 · Varias recargas a la misma cuenta** → se suman en una sola parte, en el orden de la primera; las recargas sin cuenta elegida no salen.
Por qué: la línea dice cuánto sube cada cuenta, no repite la tarjeta.

**D5 · Demo de voz `two`** → el taxi va a «Taxis y apps» (`L10n.Subcategory.rideshare`) si está sembrada; si no, la de siempre. El café se queda en Restaurantes. Mismo arreglo en la demo de foto `two`, cuya segunda foto («Taxi») caía igual en Restaurantes.
Por qué: es el mismo patrón en el seam hermano (regla de buscar todas las instancias).

**D6 · Card de Estadísticas y Registros** → primero se mide con un conductor XCUITest de 10 rondas (Distribución y Registros, 5 corridas); solo si cae se mueve la observación al ViewModel con el molde del Panel. El conductor se queda como red.
Por qué: es el «hecho cuando» de la card, y mover la observación sin fallo medido es una reescritura que el encargo excluye.
