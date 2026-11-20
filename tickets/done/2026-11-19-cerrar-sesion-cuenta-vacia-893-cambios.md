---
id: 2026-11-19-cerrar-sesion-cuenta-vacia-893-cambios
status: done
priority: high
area: cloud-sync, sign-out
created: 2026-11-19
updated: 2026-11-19
card: tablero-cerrar-sesion-en-una-cuenta-vacia-dice-c-7xzi
source: Jürgen, 19-nov 21:32, build 2.3 (5), cuenta nueva en iCloud privado
---

# Cerrar sesión en una cuenta vacía dice «Cambios por subir: 893»

Jürgen creó una cuenta de cero en iCloud privado y, sin apuntar nada, al cerrar sesión la pantalla «Quitando tus datos
de este dispositivo… Subiendo tus cambios a iCloud…» enseñaba «Cambios por subir: 893».

## Causa (medida)

El contador del cierre privado (`PersonalExportPendingCounter`) contaba como cambio de la persona todo lo escrito en el
almacén personal después de la última subida confirmada a iCloud (el «ancla»). El ancla sobrevive al borrado del cierre
a propósito, así que en un iPhone que ya usó iCloud todo lo de una cuenta nueva queda después de ella. Y la app escribe
sola mucho al crear una cuenta:

- **Medido en el simulador** (cuenta nueva, sin tocar nada): 80 objetos — 11 categorías, 62 subcategorías y 7 avisos de
  serie. El segundo arranque añade el papel de sistema de 3 subcategorías (`SubcategorySystemRoleBackfill`).
- **En un iPhone, además**, un año de tipos de cambio: una fila por día (≈ 366), que se vuelven a bajar tras cada borrado.
- El 893 exacto **no se midió** (no había iPhone conectado a la Max): encaja con ~446 objetos de serie y tipos de cambio
  borrados de una copia anterior y ~447 vueltos a crear.

Reproducido en el simulador con el ancla puesta antes del alta: «Cambios por subir: 80» y, a los 45 s, «Aún faltan
cambios por subir a iCloud… se perderán».

## Arreglo

En el contador, sin tocar la espera ni el cierre:

- Los tipos de cambio no cuentan nunca (caché de la API; cada movimiento guarda su tasa e importe convertido).
- Lo que la app creó sola y nadie tocó después no cuenta: categorías y subcategorías de serie o de sistema, y avisos de
  serie con sus valores de serie. Entrar en Yala lo vuelve a crear igual.
- El papel de sistema de una subcategoría lo escribe la app en cada arranque: ese cambio solo no cuenta.
- Un borrado cuenta siempre (salvo de tipos de cambio), y todo lo editado por la persona también.
- Sin ancla y solo con lo de la app, el contador da 0 en vez de «no se puede contar».

## Pruebas

- `YalaTests/CerrarSesionCuentaVacia/CerrarSesionCuentaVaciaTests` (9 casos, historial real en disco): cuenta vacía = 0
  con y sin ancla; un registro, una categoría propia, editar una de serie, el papel + una edición, borrar una de serie y
  activar un aviso siguen contando; los tipos de cambio no cuentan ni al fusionarlos ni al borrarlos; si no se puede
  leer lo creado por la app, cuenta todo (seam `_testThrowOnDefaultsFetch`, lo pidió el revisor con checklist). Estable
  en 3 y 5 iteraciones. Cuatro mutantes (sin excluir tipos de cambio, sin restar lo de serie, sin el atributo de la app,
  todo alta = de serie): los cuatro en rojo.
- `PersonalExportPendingCounterTests` y `PrivateExitInbound*` siguen verdes.
- Simulador, misma cuenta y misma ancla: antes «Cambios por subir: 80» y aviso de pérdida a los 45 s; después cierra al
  instante.
