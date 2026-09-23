---
id: device-qa-apple-id-change-closes-private-session
status: qa
priority: high
area: "modo-nube, sesiones, swiftdata"
created: 2026-09-14
source: "device-QA del PR de `apple-id-change-should-close-the-private-session` (2026-09-14)"
updated: 2026-09-23
---

# Device-QA · Cambiar el Apple ID del teléfono cierra la sesión privada

## Qué se arregló, en lenguaje de usuario

Usaba Yala con mis datos en mi iCloud privado y **cambié la cuenta de iCloud del teléfono**. Hasta hoy
la app no se enteraba: seguía enseñando los movimientos, las cuentas y los presupuestos de la cuenta
anterior como si nada. Si el teléfono había cambiado de manos, la persona nueva veía las finanzas de la
anterior.

Ahora Yala lo detecta y **lo pregunta**: dice que esos datos son de la cuenta de iCloud anterior, que
ahí se quedan guardados, y ofrece quitarlos de este teléfono. Si digo que sí, la app cierra esa sesión
—borra la copia local y me pide reabrirla— y vuelvo a empezar de cero. Si digo «Ahora no», no se toca
nada y me lo vuelve a preguntar la próxima vez que abra Yala. **Y si vuelvo a mi cuenta de iCloud
anterior, deja de preguntármelo solo.**

## Por qué NO es simulable

El simulador **no tiene cuentas de iCloud reales**: `CKContainer.userRecordID()` devuelve
`notAuthenticated` y el predicado sale por su rama «no se pudo preguntar», que es justo la que NO
cierra. Cambiar de Apple ID es un gesto de Ajustes de iOS sobre un dispositivo real, con dos cuentas de
verdad. Lo único simulable es el predicado puro, y eso ya lo cubren 15 unit tests
(`YalaTests/CloudSync/AppleIDChangeCloseLogicTests.swift`, 3 mutantes verificados).

## Qué hace falta

- Un iPhone real con Yala instalada.
- **Dos Apple ID de verdad** (basta con uno secundario de pruebas). Cambiar de cuenta de iCloud en
  Ajustes cierra sesión en todo el sistema: hacerlo con el Apple ID personal de Jürgen es incómodo,
  pero funciona.
- Una sesión privada con datos (al menos una cuenta y unos movimientos).

## Recorridos

### 1 · El caso principal: cambio de Apple ID con sesión privada

1. Con el Apple ID **A**, terminar el onboarding personal en «mi iCloud privado». Crear una cuenta y
   2-3 movimientos. Esperar a que sincronicen (Ajustes → iCloud dice «Sincronizado»).
2. **Abrir y cerrar Yala una vez más.** Es lo que siembra el testigo de la cuenta A — sin ese arranque
   no hay con qué comparar y el recorrido no prueba nada.
3. Ajustes de iOS → cerrar sesión de iCloud → entrar con el Apple ID **B**.
4. Abrir Yala.
   - **Se espera:** el aviso «Cambiaste de cuenta de iCloud», con los botones «Cerrar sesión y
     quitarlos» y «Ahora no».
   - ¿Sale en el primer arranque, o hace falta un segundo? (La notificación del sistema puede no llegar
     si la app estaba cerrada; el arranque tiene su propia comprobación, así que debería salir al
     primero.)
5. Tocar «Ahora no». **Se espera:** no pasa nada, la app sigue como estaba.
6. Cerrar Yala del todo y volver a abrirla. **Se espera:** el aviso vuelve a salir.
7. Tocar «Cerrar sesión y quitarlos».
   - **Se espera:** la pantalla «Ya casi está — reinicia Yala».
   - Reabrir. **Se espera:** el Welcome, sin ningún dato de la cuenta A.
8. **Y la parte que más importa:** volver al Apple ID **A** en Ajustes de iOS, abrir Yala, «Ya tengo
   cuenta → iCloud». **Se espera: los datos de A siguen ahí y se restauran.** Si no están, el borrado
   se llevó el contenedor de iCloud y eso es un fallo GRAVE — el ticket entero se apoya en que sólo se
   borra la copia local.

### 2 · El control negativo que evita el falso positivo caro

Con el Apple ID **A** y la sesión privada viva:

1. Ajustes de iOS → iCloud → **apagar iCloud Drive** (sin cerrar sesión ni cambiar de cuenta).
2. Abrir Yala. **Se espera: NO sale ningún aviso de cambio de cuenta.**

Es el recorrido que prueba que la detección no se hizo con `ubiquityIdentityToken`, que mide iCloud
Drive y no CloudKit. Si aquí sale el aviso, la app le está ofreciendo borrar sus datos a gente que no
cambió de cuenta: **parar y avisar**.

3. Volver a encender iCloud Drive.

### 2-bis · «Ahora no» y el espejo — lo que nadie ha podido medir

Sale de la review adversarial y **no es simulable ni deducible**: con «Ahora no», la app sigue
funcionando con el store personal del dueño anterior montado y el espejo de CloudKit adjunto, mientras
el Apple ID del teléfono ya es otro. La pregunta es si `NSPersistentCloudKitContainer` re-vincula ese
store al contenedor de la cuenta NUEVA — si lo hace, «Ahora no» sube el corpus del dueño anterior al
iCloud del nuevo, que es el daño inverso del que este ticket arregla. `iCloudSyncService.accountDidChange`
solo invalida el ancla del export; no toca el mount.

1. Con el aviso en pantalla (Apple ID **B**, datos de **A**), tocar «Ahora no».
2. Dejar la app abierta 2-3 minutos con red.
3. Desde otro dispositivo con el Apple ID **B**, o desde iCloud.com, mirar si aparecen datos de Yala.
   - **Se espera: NO.**
   - Si aparecen, es un bug grave aparte y hay que abrirle ticket: la salida «Ahora no» tendría que
     apagar el espejo antes de dejar seguir.

### 2-ter · La celda cruzada: Drive apagado + cambio de cuenta

El disparador no-arranque es `NSUbiquityIdentityDidChange`, que la emite el mismo subsistema de
ubiquity cuyo token vale `nil` con iCloud Drive apagado. **Inferido, no medido**: con Drive OFF esa
notificación puede no llegar nunca, y entonces la única red es la comprobación del arranque.

1. Con el Apple ID **A**, sesión privada y **iCloud Drive apagado**, abrir y cerrar Yala (siembra).
2. Cambiar al Apple ID **B** con Drive todavía apagado.
3. Abrir Yala. **Se espera: el aviso sale igual** — la comprobación del arranque no depende de la
   notificación ni del token, solo de `CKContainer.userRecordID()`.
4. Variante: con la app en **segundo plano** (no cerrada), cambiar de Apple ID y volver a Yala.
   Anotar si el aviso aparece y cuándo. Si no aparece hasta matar y reabrir la app, es un residual
   aceptable — pero hay que dejarlo escrito.

### 3 · Volver atrás antes de confirmar

1. Con el aviso en pantalla, tocar «Ahora no».
2. Ajustes de iOS → volver al Apple ID **A**.
3. Abrir Yala. **Se espera: el aviso NO vuelve a salir** y los datos siguen intactos.

### 4 · Solo-grupos NO recibe nada

1. Instalación fresca → «Vengo por un grupo» → entrar con una cuenta de Yala y unirse a un grupo.
2. Cambiar el Apple ID del teléfono.
3. Abrir Yala. **Se espera: ningún aviso.** Sus grupos siguen ahí y su cuenta de Yala sigue dentro —
   esa cuenta no es del Apple ID del teléfono.

### 5 · Con cuenta de grupos asociada (celda D)

1. Sesión privada + cuenta de grupos asociada, con un gasto de grupo **sin subir** (modo avión al
   crearlo).
2. Cambiar el Apple ID y confirmar el cierre **con el modo avión aún puesto**.
   - **Se espera** (desde el 2026-09-15, `apple-id-close-blocked-has-no-visible-outcome`): la hoja pasa a
     un progreso con «Guardando tus cambios pendientes…» y, tras unos 45 s de reintentos, enseña el
     bloqueo con su motivo —«Un momento más»— y dos botones, «Reintentar» y «Ahora no». Antes el aviso
     se cerraba y no se veía nada.
   - Tocar «Ahora no» y abrir Ajustes → «Cerrar sesión». **Se espera:** su hoja de alcance, y NO un aviso
     de bloqueo de Ajustes (en esta celda sería «Un momento más»). Eso prueba que el cierre bloqueado no
     dejó el teléfono tapiado.
3. Quitar el modo avión, cerrar Yala del todo y volver a abrirla: el aviso vuelve en el arranque siguiente,
   no al volver del segundo plano. Confirmar.
   - **Se espera:** el gasto de grupo sube antes de borrar (ADR §5: la sesión privada y su cuenta de
     grupos se mueven juntas) y aparece la pantalla de reiniciar.
4. Variante sin reabrir: con el bloqueo a la vista, quitar el modo avión y tocar «Reintentar».
   **Se espera:** el mismo final que el paso 3.

## Criterios

- [ ] Recorrido 1: el aviso sale, «Ahora no» no borra, confirmar cierra, y **los datos de A se
      restauran después** (paso 8).
- [ ] Recorrido 2: apagar iCloud Drive **no** dispara el aviso.
- [ ] Recorrido 3: volver al Apple ID anterior lo apaga solo.
- [ ] Recorrido 4: una sesión solo-grupos no ve nada.
- [ ] Recorrido 5: sin red, la hoja enseña el bloqueo con «Reintentar» y «Ahora no», y Ajustes no queda
      tapiado; con red, lo que quedaba sin subir sube antes de borrar.

## Barrido de `qa` · 2026-09-23 · se queda para el iPhone

Está en la lista corta de device-QA del 2026-09-23 (`qa/guion-tanda.md`). Se prueba con **Yala Dev compilado desde `2.1`**: el TestFlight 13 es del 9-sep y no lleva los arreglos posteriores. Para cerrarlo basta con solo el recorrido 2: apagar iCloud Drive NO debe sacar el aviso de cambio de Apple ID. El resto pide un segundo Apple ID.
