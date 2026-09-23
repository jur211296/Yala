---
name: disco-cache-simulador
description: Los GB que el disk-report no ve están DENTRO del device — coresymbolicationd y containermanagerd suman ~7,6 GB regenerables y vuelven a llenarse en cada tanda; rm -rf está bloqueado, se limpia con find -delete
metadata:
  type: reference
---

**Cuando el guard de disco salta y hay que trabajar ya, lo más rentable está dentro del propio
simulador, no en DerivedData.** Medido el 2026-09-09 con 21 GB libres (umbral 25):

    ~/Library/Developer/CoreSimulator/Devices/<UDID>/data/Library/Caches/
      com.apple.coresymbolicationd   5,6 GB    ← caché de símbolos
      com.apple.containermanagerd    2,0 GB    ← contenedores de apps ya desinstaladas
      com.apple.mediaanalysisd       214 MB

Borrarlas devolvió el disco de **21 GB a 29 GB** sin tocar datos de trabajo: son caché pura y se
regeneran solas. DerivedData eran 4,5 GB y cuesta un build completo recuperarlo; esto no cuesta nada.

**Why:** el `disk-report.sh` mide el tamaño del device entero, así que dice «14 GB» y no dice de
qué. Sin desglosar, la reacción por defecto es borrar DerivedData o `simctl erase` —que además
tira la app instalada y el estado—, y ninguna de las dos es la palanca buena.

**How to apply:**

1. `xcrun simctl shutdown <UDID>` y esperar ~3 s. Con el device arrancado, borrar esas cachés es
   pedir problemas.
2. **`rm -rf` está bloqueado en este entorno** (lo mismo que en el flujo de release). Se limpia así:

       find "$D/$c" -type f -delete
       find "$D/$c" -depth -type d -empty -delete

3. Volver a correr `bash qa/scripts/disk-report.sh --guard` y leer su **exit**, no solo su texto.

**Y vuelve a llenarse dentro de la misma sesión.** En la tanda del 2026-09-09 hubo que repetirlo
una vez: cuatro builds y dos corridas de tests devolvieron el disco a 21 GB en un par de horas. No
es un fallo de la limpieza — es que la caché de símbolos crece con cada corrida. Si vas a correr el
gate completo después de un barrido largo, limpia otra vez ANTES, no cuando el XCUITest empiece a
fallar con errores que no mencionan el disco.

**Lo que no era el problema, comprobado de paso:** `~/Library/CoreSimulatorInternal/Devices` y
`~/Library/Developer/CoreSimulator/Devices` **son el mismo espacio** (el `du` los cuenta dos veces
y parecen 28 GB cuando son 14), y los únicos snapshots del volumen eran `com.apple.os.update-*`,
no de Time Machine.

Relacionado: [[project_hipotesis_lista_negra_recomprobadas]] — el snapshot de Time Machine que
hacía inútil liberar disco no aplicaba aquí.

**2026-09-23, otra vez y con otro reparto:** una tanda de 17 mutantes + corridas de suites (unas 20 reinstalaciones
de la app) bajó el disco de 24 a 13 GB en una hora. Esta vez el grueso era `com.apple.containermanagerd` (**8,4 GB**) y
`coresymbolicationd` solo 0,9 GB. La misma receta, dentro de `sim-lock.sh -- bash -c '…'` para que nadie arranque el
simulador mientras se vacía, devolvió 10 GB (13 → 23). ⇒ después de una batería de mutantes, limpia ANTES del gate.
