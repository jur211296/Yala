---
id: panel-fresh-seed-reads-the-icloud-drive-token
status: qa
priority: low
area: "icloud, panel, preferencias"
created: 2026-11-05
updated: 2026-11-06
source: "review adversarial del lote N4 (iCloud Drive y preferencias), lente de las esperas"
---

# Con iCloud Drive apagado, un dispositivo nuevo puede devolver el Panel de los otros a su configuración inicial

## Qué pasa, en lenguaje de usuario

Tengo el Panel ordenado a mi gusto en el iPhone. Instalo Yala en el iPad, con la sesión de iCloud abierta pero iCloud
Drive apagado, y el Panel del iPhone vuelve al orden de fábrica.

## Lo medido (leído, 2026-11-05, rama 2.3)

- `PanelPreferencesMigration.freshSeedDecision` decide en `AppPreferences.init` si siembra ya o difiere al paso 8.5 del
  arranque, con `SwiftDataConfiguration.isICloudAvailable()` (token de iCloud Drive). Con Drive apagado el token falta y
  siembra en el acto; `setupDefaultsForNewUser()` escribe los valores por defecto en el iCloud-KV y, por LWW, pisa la
  configuración que estaba por bajar.
- El paso 8.5 ya decide con `hasICloudAccount` desde el lote N4. En el `init` no se puede: CloudKit aún no contestó.

## Lo que falta medir antes (device)

- ¿Viaja el iCloud-KV (`NSUbiquitousKeyValueStore`) con iCloud Drive apagado y la sesión abierta? Si no viaja, no hay
  daño y el ticket se descarta.

## Si viaja

Diferir siempre que se pida diferir (el 8.5 re-invoca la migración ya con la respuesta de CloudKit), comprobando que
los tests que construyen `AppPreferences` sobre un almacén limpio no dependan de la siembra en el `init`.

## Resolución (2026-11-06, lote de cuenta e iCloud)

- **Decisión:** la segunda salida del «hecho cuando» — la siembra se difiere SIEMPRE al arranque —, sin medir si el
  iCloud-KV viaja con Drive apagado: con la siembra diferida da igual, porque el paso 8.5 decide con la cuenta de iCloud
  (`hasICloudAccount`, token de Drive O CloudKit) y espera a que lo de iCloud baje antes de sembrar.
- **Qué cambia para el usuario:** instalar Yala en un dispositivo nuevo con iCloud Drive apagado ya no devuelve el Panel
  de los otros dispositivos a la configuración inicial. En un dispositivo sin iCloud, el Panel inicial llega en cuanto
  CloudKit contesta (techo de 5 s), no en el `init`.
- **Cómo:** `PanelPreferencesMigration.freshSeedDecision(deferRequested:)` ya no recibe el token de Drive: desde
  `AppPreferences.init` difiere siempre. `AppPreferencesTests.set_panelPrefsMigratedV2_persistsToUserDefaults` cambió
  con ello (el `init` ya no escribe la marca).
- **Tests:** `PanelPreferencesMigrationTests.freshSeedDecision_matriz` y `freshSeedDecision_noLeeElTokenDeDrive`
  (source-scan); `PanelDashboardUITests` en verde (el Panel de un arranque limpio sigue saliendo con los valores iniciales).

## Guion de device-QA (iPad + iPhone de pruebas, Yala Dev)

1. En el iPhone 14 (sesión de iCloud abierta), cambia el orden del Panel: Configurar panel → mueve una sección y oculta
   un widget. Anota cómo quedó.
2. En el iPad, en Ajustes del sistema → tu nombre → iCloud → apaga iCloud Drive (la sesión de iCloud sigue abierta).
3. Borra Yala Dev del iPad e instálala desde Xcode. Entra con la misma cuenta y espera a que cargue el Panel.
4. Vuelve al iPhone, abre Yala y mira el Panel: debe seguir como lo dejaste en el paso 1.
5. Vuelve a encender iCloud Drive en el iPad.
