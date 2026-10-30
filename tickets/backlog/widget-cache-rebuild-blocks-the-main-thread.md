---
id: widget-cache-rebuild-blocks-the-main-thread
status: backlog
priority: medium
area: "performance, widgets"
created: 2026-10-30
updated: 2026-10-30
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
