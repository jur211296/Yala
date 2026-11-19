---
id: 2026-11-18-sentry-cuelgues-hero-y-widget
status: done
priority: medium
area: "panel, widgets, rendimiento"
created: 2026-11-18
updated: 2026-11-18
card: tablero-el-panel-se-cuelga-unos-segundos-al-reca-wwjc, tablero-la-app-se-cuelga-unos-segundos-al-actual-7ral
source: "Sentry YALA-IOS-N y YALA-IOS-M (TestFlight 2.3 (3), iPhone 18 Pro con iOS 27.3 beta)"
---

# El hero del Panel y la foto de los widgets dejaban la app sin responder unos segundos

Dos «App Hang» de Sentry, un evento cada uno, en el mismo iPhone y con un minuto de diferencia (17-nov, tras un pull de
la nube). Las dos pilas acaban en el getter de una propiedad `@Model` (`amountInPreferredCurrency`, `date`) instanciando
su keypath: el coste es recorrer el historial entero en el hilo principal, leyendo cada movimiento.

## Hecho cuando

Se encontró la causa, el arreglo tiene test (el cálculo pesado no bloquea el hilo principal) y los dos issues quedaron
resueltos en Sentry.

## Causa, medida

Con 20.000 movimientos en el simulador (iOS 27.2, Debug), bloque más largo del hilo principal:

| | antes | después |
|---|---|---|
| Foto de los widgets (`WidgetDataCache.buildSnapshot`) | 3,1 s de un tirón | 0,89 s (17 etapas; la más larga, el resumen de «Todo el tiempo») |
| Hero del Panel (`HeroBucketsCalculator`) | 0,25 s dentro del recálculo | ~9 ms por tramo (20 tramos de 1.000) |

El flujo proyectado del widget, que es donde cayó la pila de YALA-IOS-M, cuesta solo 0,18 s: la foto entera recorría el
historial unas quince veces. El coste por lectura de iOS 27.3 beta (la instanciación del keypath que sale en las pilas)
no se reproduce en el simulador 27.2.

## Resolución (2026-11-18)

- **Hero**: `HeroBucketsCalculator.Accumulator` suma por tramos y `calculate` lo usa, así que las cifras son las mismas
  por construcción. El Panel, con más de 1.000 movimientos, recorre el hero en tramos y cede 1 ms entre uno y otro; un
  cálculo nuevo o salir del Panel cortan el que está a medias (y lo apuntan para la vuelta). Lo borrado mientras espera
  se salta.
- **Widget**: la foto se arma por etapas (`buildSnapshot(context:now:stages:)`). La foto pedida (`updateCache`, la del
  segundo de espera) las corre cediendo el hilo entre una y otra y se publica por el camino de siempre (`updateCacheNow`,
  con su puerta del borrado armado). Si algo se guarda a mitad, la foto se tira y se pide otra. El paso a segundo plano y
  las tareas de fondo la siguen haciendo de una vez.
- **Lo que funde el espejo de iCloud** no pasa por `ModelContext.didSave` (lo cazó la review): `StoreRemoteChangeCounter`
  cuenta `NSPersistentStoreRemoteChange`, y con un aviso a mitad la foto se tira y se pide otra, y el hero se corta y
  pide una recarga. El contador del hero se lee al copiar los movimientos, no al arrancar la tarea (un aviso entre medias
  pasaba sin verse; lo destapó su test).
- Pins: `YalaTests/CuelguesHeroWidget/HeroPorTramosTests` y `FotoWidgetPorEtapasTests` (los dos casos del espejo, con
  mutante: sin la guarda, rojos).
- Fuera de lo declarado: `YalaTests/PeriodEndsBeforeTomorrowMidnightTests` anclaba su escaneo en el texto
  `let buckets = HeroBucketsCalculator.calculate(`; ahora ancla en el acumulador y fija lo mismo (al calculador llega el
  mes cerrado).

## Lo que queda (card aparte)

El cuelgue del Panel no es solo el hero: el recálculo entero (`performCalculation`) es un solo bloque. Medido con 20.000
movimientos: contexto de cálculo 0,68 s · tendencia 0,49 · pagos y nota de salud 0,35 · hero 0,25 · categorías,
subcategorías, flujo, necesidad, día de la semana, etiquetas, saldo y gasto por cuenta entre 0,1 y 0,2 s cada uno. ~2,9 s
en total; con el hero por tramos quedan ~2,6 s seguidos. Escalonarlo entero toca la pantalla principal de arriba abajo
y va en su propia card.
