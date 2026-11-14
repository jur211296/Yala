---
id: icloud-return-stuck-and-empty-icloud
status: done
priority: very-high
area: "modo-nube, vuelta a iCloud, welcome"
created: 2026-11-13
updated: 2026-11-13
source: "recorrido de la bienvenida en el iPhone 14 con Jürgen (13-nov), escenarios E07 y E03; cards tablero-volver-a-tu-icloud-se-queda-en-traer-tus-atde y tablero-icloud-recien-vaciado-yala-dice-ya-tiene-zy1d"
qa-status: needs-testing
---

# «Volver a tu iCloud» sin quedarse trabado, y un iCloud recién vaciado se trata como vacío

## Qué veía la persona

1. **E07.** Con unos 2.300 registros de prueba recién cargados, «Volver a tu iCloud» se quedaba más de 6 minutos en
   «Traer tus datos de tu cuenta de Yala», sin cifra, también tras reabrir, y «Cancelar y seguir en tu cuenta de Yala»
   estaba apagado. No podía avanzar ni salir; hubo que reinstalar.
2. **E03.** Tras «Vaciar datos», «Entrar con mi iCloud» tardaba 34 s y decía «Ya tienes datos en tu iCloud — 62
   categorías» (solo las de serie). Después, 54 s más y la nota «Esta copia de iCloud es de antes de que pasaras tus datos
   a tu cuenta de Yala», que ya no era cierta.

## Causa (medido en el código)

- **El atasco no era la espera del import.** Con los datos en la cuenta de Yala el espejo de iCloud está apagado y
  `awaitQuiescence` pasa al instante; la card lo había inferido sin medir. Lo que tardaba era el drenaje de la vuelta
  (`MigrationWorkExecutor.reverseDrainOnce`): subía la cola ENTERA (3090 cambios en el teléfono) en una sola llamada y solo
  la purgaba al final. El Worker aplica cada cambio en serie (`gateway/src/sync/routes.ts`), así que eran minutos sin
  cifra; cerrar Yala a mitad no dejaba nada purgado y la pasada siguiente empezaba otra vez desde el primero.
- **«Cancelar» colgaba de `isWorking`**, que está en `true` durante todo el drenaje, y `cancelReverse()` esperaba a que
  terminara.
- **«62 categorías»**: la puerta del Welcome decidía con `ICloudPersonalCorpus.hasAnyData`, que cuenta las subcategorías
  que no son de sistema. Tras «Vaciar datos» la app vuelve a sembrar las de serie y el espejo las sube a iCloud.
- **La nota de «copia de antes»** solo miraba el faro del iCloud-KV (`CloudBeacon.isCloudAccountLinked`), que sobrevive a
  «Vaciar datos».
- **El nombre («¿Te llamo Jurgen?»)** sale de `AppPreferences.userName`, una preferencia que viaja por el iCloud-KV, no del
  store de SwiftData. Por eso sobrevive al vaciado del iCloud: no es un dato que «Vaciar datos» borre del contenedor.

## Qué cambió

- **El drenaje sube por tandas de 50**, ordenadas por HLC antes de partirlas (el servidor recibe el mismo orden de
  siempre), y purga cada tanda al confirmarla: lo subido sobrevive a cerrar Yala y a cancelar.
- **«Traer tus datos de tu cuenta de Yala» enseña «X de Y» con su barra**, con el texto que ya usaba «Subir tus datos» de
  la ida (sin textos nuevos).
- **«Cancelar y seguir en tu cuenta de Yala» ya no se apaga mientras espera**: solo mientras un «sí» está en camino. El
  «sí» llega al runner antes de esperar y el drenaje corta entre tandas; lo confirmado queda guardado.
- **Rastro en Console** (`com.yala` / `MigrationRunner`): entrada y salida de `awaitQuiescence`, de cada pasada del
  drenaje y de cada tanda (cuántos, de cuántos, milisegundos).
- **La puerta del Welcome trata como vacío un iCloud sin movimientos ni cuentas** (`WelcomePrivateICloudGateLogic.iCloudHasUserData`).
  Seguir no borra nada: el espejo baja lo que haya y el deduplicador funde las categorías de serie repetidas. Con eso E03
  sigue el camino de E03b (directo a «reabre Yala»), sin la revisión de «Conectando con iCloud…».
- **La nota de «copia de antes» sale solo con el faro puesto y movimientos o cuentas en la copia.**

## Lo que no cambió, a propósito

- `ICloudPersonalCorpus.hasAnyData` sigue contando categorías y presupuestos: lo lee también el aviso del espejo tardío,
  que **borra**, y ahí el criterio es otro.
- La pantalla de restaurar sigue enseñando «Encontramos tus datos» con solo categorías si alguien llega a ella por otra
  entrada; con la puerta arreglada, el camino del recorrido ya no pasa por ahí.
- El motor normal de la nube (`CloudSyncRuntime`) también sube toda su cola y purga al final: no está en este encargo.

## Pruebas

- `YalaTests/ICloudReturnAndEmpty/ReverseDrainBatchesTests`: purga antes de la tanda siguiente, cifra por tanda, corte
  por cancelar conservando lo subido, y el orden HLC a través de las tandas.
- `YalaTests/ICloudReturnAndEmpty/ICloudEmptyAndReverseScreenTests`: puerta con solo categorías o presupuestos, nota de
  copia antigua, cifra del paso y el cableado de «Cancelar».
- Device-QA en el iPhone 14: ver «Guion de QA».

## Guion de QA (iPhone 14, Yala Dev)

1. Con una cuenta de Yala (Google) y «Cargar datos de prueba» recién hecho, abrir Ajustes › Dónde viven tus datos ›
   «Volver a tu iCloud» › «Empezar sin ellos» (o «Sumarlos») y seguir.
2. En «Traer tus datos de tu cuenta de Yala» tiene que aparecer la barra con «X de Y» y avanzar cada ~15 s.
3. «Cancelar y seguir en tu cuenta de Yala» tiene que estar activo. Tocarlo y confirmar: en menos de ~20 s vuelve a la
   tarjeta de la nube, y la cifra de cambios pendientes ha bajado (lo subido no se repite).
4. Repetir el paso 1, cerrar Yala a mitad de la cifra y abrirla: la cifra sigue desde donde iba, no desde cero.
5. Tras «Vaciar datos» en modo iCloud, «Entrar con mi iCloud» va directo a «reabre Yala», sin «Ya tienes datos».
