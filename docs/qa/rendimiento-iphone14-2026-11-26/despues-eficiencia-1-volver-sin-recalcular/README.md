# Lote 1 · Volver a Yala no recalcula lo que no cambió — antes y después en el iPhone 14

Medido el 26-nov-2026 entre las 13:59 y las 14:50 (Lima) en el iPhone 14 de Jürgen («iPhone de JURGEN», iOS 27.2.1),
por cable a la Max, desbloqueado y cargando. La misma copia de perfilado que el informe de origen (`Release-Dev`
optimizada con `DEBUG` encendido de forma temporal, solo en la copia), el mismo almacén `YalaModel-UITest` de 16.004
movimientos, los mismos guiones (`../scripts/`), lanzada por Instruments con `-uitest -uitest-skip-onboarding`.

- **Antes**: `origin/2.3` en `00c4ab2e75` (la base de este lote), sin cambios.
- **Después**: la misma base con los cambios de este lote. **Sin** el lote 2 (animaciones), que entró en `2.3` después:
  las cifras aíslan este lote.

## Resultado

Diez ciclos «irse a otra app 5-30 s y volver» con Time Profiler, Hitches y Thermal State. Tras cada vuelta, 2 s quieta,
6 deslizamientos hacia abajo y 3 hacia arriba, 4 s quieta.

| Por vuelta (ciclos 2-10) | Antes | Después |
|---|---|---|
| Bloque continuo con el hilo principal ≥ 90 % | **9 s** (los 9) | **0 s** (los 9) |
| CPU del hilo principal en los 20 s siguientes | 10,8-15,8 s (mediana 11,5 s) | 2,4-3,6 s (mediana 2,9 s) |
| CPU del hilo principal en los 36 s siguientes | 11,1-22,8 s | 2,6-5,4 s |
| Cuelgues con Yala delante (vuelta → siguiente salida) | 1 por vuelta, 7,3-7,8 s | **0** |
| Recálculo del Panel al volver | 10 de 10, ~7 s cada uno | **0** |
| Reconciliación de Spotlight | 17,6 s en la pasada | 2,9 s (solo la primera) |
| Tirones de render > 250 ms | 2 (uno de 7,3 s) | 0 (máx. 17 ms) |

El ciclo 1 de «después» todavía trae 3 s de bloque y un cuelgue de 1,6 s: es el trabajo del arranque (los dos cálculos
del Panel del arranque en frío, ~16 s, siguen corriendo cuando el guion sale por primera vez) y la primera reconciliación
de Spotlight del proceso. A partir de la segunda vuelta, ninguna vuelta recalcula.

Contra la mejora esperada del informe (de ~33 s de CPU en 36 s a ~1,5 s en 20 s, sin bloque y sin tirones > 250 ms):
**se cumple el bloque (0 s) y los tirones (ninguno)**. La CPU que queda tras volver (~2,9 s en 20 s) no es recálculo:
es el pulso de la gráfica de tendencia, que este lote no toca (lo quita el lote 2, ya en `2.3`), y el render del scroll
del guion. El informe midió su ~1,5 s con el pulso apagado y sin scroll en esa ventana.

## Qué cambió entre las dos pasadas que valen

La primera pareja (`antes`, `despues` en `datos/`) usó el guion de siempre: 6 deslizamientos abajo y 6 arriba. El sexto
hacia arriba llega al tope del Panel y dispara **«tirar para actualizar»**, que recarga y recalcula el Panel entero
(~7,5 s). Con eso, el «después» seguía teniendo 8 cuelgues de ~7,5 s y parecía que la vuelta seguía recalculando. Una
copia instrumentada solo para medir (`datos/consola_tirar_para_actualizar.log`, con la pila de cada petición; no está en
el código del PR) lo confirmó: la vuelta decía «sin cambios, no recarga» y la petición venía de `PanelView.refreshData`,
el gesto de tirar. Es un gesto real de la persona y su costo es el del lote 4 (el recálculo bloquea), no de este. La
pareja que vale (`antes2`, `despues2`) sube solo 3 veces y no llega al tope (`SUBE=3` en `scripts/ciclos.sh`).

## Lo que queda, y de quién es

- **~280 ms al IRSE** de Yala en cada ciclo, 2,3 s después de pasar a otra app: la foto de los widgets
  (`WidgetDataCache.flushPendingUpdate`, al pasar a segundo plano). El informe ya lo había descartado como causa de calor;
  no es de este lote.
- **Tirar para actualizar** sigue costando un recálculo completo: lote 4.
- **El arranque en frío** hace dos cálculos completos del Panel seguidos (~16 s con 16 k): lote 4.

## Archivos

- `datos/antes2.*`, `datos/despues2.*`: la pareja que vale. `*.tirones.txt` (hitches y cuelgues en los 36 s tras cada
  vuelta; cuenta también lo que cae al irse en el ciclo siguiente), `*.cuelgues_por_vuelta.txt` (solo con Yala delante),
  `*.matriz_vuelve.json` y `*.matriz_vuelve20.json` (ms de hilo principal por segundo tras cada vuelta, 36 y 20 s),
  `*.perfil.txt` (perfil por ventanas: fuera, volver, scroll), `*.ciclos.csv` (eventos con hora de Lima).
- `datos/antes.*`, `datos/despues.*`: la primera pareja, con «tirar para actualizar» dentro.
- `scripts/ciclos.sh` (con `SUBE`), `scripts/tirones.py`, `scripts/cuelgues_por_vuelta.py`, `scripts/donde.py` (en qué
  ventana cae cada muestra de una función). Los demás guiones son los de `../scripts/`.
- Las trazas completas (`.trace`, 100-200 MB) quedan en la Max:
  `~/Claude/entregas/2026-11-26-eficiencia-1-volver-sin-recalcular/trazas/`.
