---
id: widget-cache-rebuild-blocks-the-main-thread
status: done
priority: medium
area: "performance, widgets"
created: 2026-10-30
updated: 2026-11-05
card: tablero-la-cache-de-los-widgets-bloquea-el-hilo-1hcz
source: "encargo eficiencia-carga-por-vista (S27e), medido en el simulador"
---

# Reconstruir la caché de los widgets bloquea el hilo principal

## Qué pasa

`WidgetDataCache.updateCache(context:)` es síncrona en el main actor: trae todos los movimientos, calcula ocho períodos
(cada uno recorre el histórico entero para el saldo), la curva, los saldos y la foto de Siri, y la escribe. Corre en el
paso 9 del arranque y **tras cada alta, edición o borrado** (`TransactionService`).

Medido el 2026-10-30 (corpus `rendimiento`, 2.337 movimientos, iPhone 17 Pro, iOS 27.0, `LoadTimeMarks`): **~0,27 s**
por reconstrucción (mediana de 5). En el arranque retrasa que la escena pase a activa y, con ella, el primer cálculo del
Panel; tras guardar un registro es un tirón de un cuarto de segundo.

## Por qué no se arregló en el encargo

Sacarla del hilo principal pide leer los `@Model` desde otro contexto (otro `ModelContext` en un actor) o pasar a
valores, y toca la foto que comparten widgets y Siri: no es un arreglo pequeño sin cambiar comportamiento. Aplazarla
cambia cuándo se ve el dato en el widget.

## Hecho cuando

La reconstrucción no ocupa el hilo principal (o se agrupa: varias altas seguidas, una reconstrucción), la foto sigue
siendo la misma (test de paridad sobre el snapshot) y la medida lo refleja.

## Hecho (lote P2, 2026-11-05): agrupada, no fuera del hilo principal

- `WidgetDataCache.updateCache` pide la foto; las peticiones de 1 s se funden en una reconstrucción. La foto es la de
  siempre (`updateCacheNow`, mismo cuerpo, misma puerta del borrado armado), así que la paridad de widgets y Siri no
  cambia; lo fija un scan del cuerpo en `WidgetCacheCoalescingTests`.
- Las tareas de fondo la hacen en el acto (`updateCacheNow`), el paso a segundo plano vacía lo pendiente
  (`flushPendingUpdate`), y `clearCache` y la suelta del contenedor en un swap lo cancelan (contexto en `weak`).
- **Lo que no se hizo**: sacarla del hilo principal. Exige leer los `@Model` desde otro contexto en todo `buildSnapshot`
  y sus ayudantes `@MainActor`; queda como mejora si la reconstrucción sigue notándose. Cada una cuesta igual
  (~0,31–0,33 s en el simulador); lo que baja es cuántas hay y cuándo caen (fuera del arranque y del gesto de guardar).
- Medido en el simulador: 2 reconstrucciones por arranque en frío → 1.

## Cómo medirlo en el iPhone

`LoadTimeMarks` solo escribe en DEBUG (en Release es no-op), así que la medida en el teléfono va con el scheme
`Yala Dev` instalado desde Xcode, con datos de volumen:
1. Conecta el iPhone, elige el scheme **Yala Dev** y el iPhone como destino, y dale a Run (⌘R).
2. En la Mac abre **Consola**, elige el iPhone en la barra lateral, escribe `app.yala.perf` en el buscador y pulsa
   Iniciar.
3. Cierra Yala del todo (deslizar en el multitarea) y ábrela; luego cambia a Estadísticas y vuelve al Panel, cinco veces.
4. Las líneas `PERF arranque`, `PERF panel` y `PERF widgets` traen los milisegundos. En el simulador, con el mismo
   corpus: arranque 4,67 → 3,62 s; volver al Panel 0,71 → ~0,22 s; caché de widgets una reconstrucción por arranque
   en vez de dos (medianas de 5, PR del lote P2).
