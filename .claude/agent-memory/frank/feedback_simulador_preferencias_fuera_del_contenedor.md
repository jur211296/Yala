---
name: simulador-preferencias-fuera-del-contenedor
description: Si `removeObject` no tiene efecto o una «instalación limpia» trae datos (el App Group sobrevive a `simctl uninstall`), es el simulador: `simctl erase`.
metadata:
  type: feedback
---

Cuando un XCUITest falle por un valor de `UserDefaults` que «no debería estar», la firma que lo delata es
esta: **`removeObject` no tiene efecto** (`antes=true despues=true`) **y la key no aparece en ningún
dominio enumerable** —`volatileDomainNames`, `persistentDomain(forName: bundleID)`— **ni en el plist del
contenedor**, y aun así `object(forKey:)` la devuelve. En cuanto veas eso, **para de buscar al escritor**.

**Why:** el 2026-09-13 perseguí ocho XCUITest rojos durante un día entero. `cloudSync.groupsOnlyNeutralMount`
estaba pegada en el simulador, el backfill del eje 1 la lee y escribía `hasPrivateSession = false` en cada
arranque ⇒ la app arrancaba con la shell reducida a Grupos y caían tres suites ajenas a Grupos. Refuté tres
hipótesis con su medición —la purga que faltaba en `-uitest-reset`, un plist de nivel dispositivo, la
contaminación entre suites (el test caía **en solitario** sobre un contenedor recién instalado)— y ninguna
era. **Lo zanjó `xcrun simctl erase` en tres minutos**, sin tocar una línea de producción.

**How to apply:**
- Ante un rojo que huele a estado pegajoso, **`simctl erase` va PRIMERO**, no al final: descarta la mitad
  del espacio de búsqueda por tres minutos. Es el gemelo de `disk-report.sh` en «antes de culpar al código,
  mira el entorno».
- Dos sitios guardan preferencias de un bundle en el simulador y la app solo alcanza uno: el contenedor
  (`simctl get_app_container <udid> <bundle> data`) y `…/Devices/<udid>/data/Library/Preferences/`. Al
  segundo no lo borra ni `simctl uninstall` ni `removeObject` desde dentro.
- **No siembres estado con `xcrun simctl spawn <udid> defaults write`**: escribe en el segundo, parece «no
  tomar» y envenena el simulador. Edita el plist del contenedor o pasa un launch arg.
- La sonda que cerró el caso imprimía **los DOMINIOS**, no el valor — [[feedback_instrumentar_gana_a_razonar]].

**Y el App Group tampoco se va con `simctl uninstall`** (medido el 2026-10-13, iOS 27.0). Reinstalé Yala Dev para
una captura de «instalación limpia» y salió «Detectamos datos previos… ¿Borrar todo?»: el contenedor
`Shared/AppGroup/<uuid>` era de mi recorrido de media hora antes, con su store dentro. En un iPhone real borrar la
app sí lo vacía; en el simulador **«limpia» exige `simctl erase`**. Antes de reportar como bug algo que solo pasa
«en una instalación nueva», mira la fecha de ese contenedor (`simctl get_app_container <udid> <bundle> groups`).
