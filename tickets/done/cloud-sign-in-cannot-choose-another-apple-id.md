---
id: cloud-sign-in-cannot-choose-another-apple-id
status: qa
priority: medium
area: "modo-nube, auth"
created: 2026-09-16
updated: 2026-11-06
source: "review adversarial de `settings-migrate-to-cloud-adopts-silently-instead-of-migrating` (Paso 0 · D15: Jürgen, «permitir otro Apple ID»), 2026-09-16"
---

# Con Apple, Yala solo deja entrar con el Apple ID del teléfono

## El problema, en lenguaje de usuario

Quiero llevar mis finanzas a la nube con una cuenta de Apple distinta de la de este iPhone. Al elegir «Continuar con
Apple», iOS firma siempre con el Apple ID del teléfono y no me deja elegir otro. Si esa cuenta ya tiene finanzas, Yala
me para, y «Usar otra cuenta» → Apple me devuelve a la misma. Con Google sí puedo elegir.

## Lo medido (2026-09-16)

- El inicio de sesión con Apple es el nativo (`ASAuthorizationAppleIDProvider`, `CloudAuthService`): el sistema solo
  ofrece el Apple ID con el que está iniciado el dispositivo. No hay pantalla para elegir otro.
- Desde `settings-migrate-to-cloud-adopts-silently-instead-of-migrating`, la hoja del aviso de «Migrar a la nube» lo
  dice cuando la cuenta rechazada era de Apple (`storage.migrateBlock.appleSameAccountNote`): «Con Apple, Yala usa siempre
  la cuenta de este dispositivo. Para usar otra, elige Google.» Es el remedio provisional; al cerrar este ticket, la
  nota sobra.

## Decisión de Jürgen (2026-09-16)

Permitir otro Apple ID con el inicio de sesión web de Apple, en este ticket.

## Lo que hay que diseñar antes de escribir

- **La configuración del flujo web**: un Services ID con su dominio y su URL de retorno en Apple Developer, y el
  proveedor Apple de Supabase configurado para web. El flujo web necesita el secreto JWT firmado con la clave `.p8`
  (el nativo no), y ese secreto caduca cada seis meses: hace falta quién lo renueva.
- **Una premisa que se cae**: `BeaconOrphanLogic` limpia el faro con la prueba «faro de Apple y sesión de Apple» porque
  Sign in with Apple solo firma con el Apple ID del teléfono (`.claude/rules/swiftdata-cloudkit.md`, regla del faro).
  Con el flujo web esa prueba deja de valer, y limpiar el faro es irreversible.
- **Otra premisa escrita**: `beacon-routes-only-never-blocks` da por hecho que «otro Apple» no se plantea.
- **Dónde se ofrece**: solo en «Usar otra cuenta», o en todos los sitios que ofrecen Apple.
- **La identidad**: el mismo Apple ID por el flujo web y por el nativo tiene que dar la misma cuenta de Yala.

## Un caso más (2026-09-17)

El aviso nuevo de «Migrar a la nube» en un teléfono que pasó por «Empezar desde cero» manda a desasociar la cuenta de la
persona anterior y volver a activar la nube «para elegir tu cuenta» (`fresh-start-keeps-a-groups-session-that-migrate-promotes`).
Si el teléfono sigue con el Apple ID de la persona anterior y su cuenta de Yala es de Apple, elegir Apple vuelve a esa
cuenta, y como la sesión la abrió el intento, la migración sigue. La hoja de Apple enseña ese Apple ID; el aviso no lleva
la nota de Apple, porque en esa hoja no hay «Usar otra cuenta».

## Criterios de aceptación

- [ ] Desde «Usar otra cuenta» se puede entrar con un Apple ID distinto del del teléfono.
- [ ] El faro no se limpia con una sesión de Apple que no es la del Apple ID del teléfono.
- [ ] La nota provisional de la hoja se retira o se ajusta.

Triage 2026-10-08: abierto · medium → medium · no hay flujo web de Apple: el único inicio es el nativo y la nota provisional sigue (`StorageMigrationBlockedView.swift:56`); la decisión ya está tomada y falta el Services ID de Jürgen.

## Hecho (encargo «Lote nube: categorías duplicadas, Apple ID y tasa de hoy», 2026-11-06, decisión A de Jürgen)

- **Dónde se ofrece**: solo en el selector de «Usar otra cuenta» de «¿Dónde viven tus datos?», como tercer botón
  «Otra cuenta de Apple», debajo de Apple y Google y con menos peso (`StorageSignInChooserView`).
- **Cómo entra**: `CloudAuthService.signInWithAppleOnTheWeb()` abre la página de Apple en una sesión del navegador del
  sistema SIN las cookies de Safari, y Supabase hace el intercambio (PKCE) con el Services ID web `pe.yala.app.web`. La
  vuelta es `yaladev://auth-callback` (`yala://` en producción), y está en la lista permitida del Supabase de **staging**
  (añadida el 2026-11-06; producción no se tocó).
- **El interruptor**: `CloudRemoteFlags.appleWebSignInEnabled`, flag de `/config` (`APPLE_WEB_SIGN_IN_ROLLOUT_PERCENT`).
  Ausente vale encendido en Yala Dev y apagado en producción; en el gateway, staging 100 y producción 0 (lo fija
  `gateway/test/config.test.ts`). Con el interruptor apagado todo queda como antes, nota provisional incluida.
- **El faro**: una sesión de Apple abierta por la web deja la marca `cloudauth.appleOnTheWeb` y ya no sirve de prueba 2
  para limpiar el faro (`storedProviderProvingThisDevicesAppleID`, por defecto en `CloudIdentityDiscovery`). La prueba 1
  (mismo hash) sigue. Todo otro inicio de sesión y el cierre retiran la marca.
- **La identidad**: el mismo Apple ID por la web y por el nativo da la misma cuenta de Yala si el Services ID está
  agrupado con el App ID (Apple da el mismo identificador al equipo) — **sin medir con una cuenta real**: es el primer
  punto del QA.
- **La nota provisional** se retira con el interruptor encendido.
- **Lo que el inicio web deja distinto, a propósito**: no guarda el `appleUserID` (con el de otro Apple ID, la comprobación
  de credencial al volver a primer plano diría «no existe» y cerraría la sesión), y no canjea el código de Apple (lo
  consume Supabase).
- Tests: `AppleOnTheWebSignInTests` (9), el caso nuevo de `StorageMigrationSignInLogicTests`, y en
  `StorageMigrationIdentityBlockUITests` el caso con el interruptor encendido (sin nota, con «Otra cuenta de Apple») y el
  de siempre con el interruptor apagado. Capturas en `~/Claude/entregas/2026-11-06-lote-bugs-nube-duplicados-apple-tasa/evidencia/`.

## Residuales

- **Producción**: falta añadir al Services ID `pe.yala.app.web` (Apple Developer) la URL de vuelta
  `https://kefvaiymtgytemwbltlz.supabase.co/auth/v1/callback`, y en el Supabase de producción: `pe.yala.app.web` delante
  en los Client IDs de Apple, el secreto JWT web (`~/Secrets/yala-siwa/client-secret-jwt-web.txt`, caduca el
  2027-05-03: hay que renovarlo cada seis meses) y `yala://auth-callback` en las URL permitidas. Después,
  `APPLE_WEB_SIGN_IN_ROLLOUT_PERCENT = "100"` en producción y desplegar el gateway.
- **Borrar la cuenta** de una sesión abierta por la web no revoca el token de Apple (no hay código que canjear). Igual que
  hoy con una sesión cuyo canje falló.
- El caso del 2026-09-17 (aviso de «Migrar» tras «Empezar desde cero», sin «Usar otra cuenta») sigue sin la salida web: no
  se pidió ahí.

## Guion de QA (Jürgen, iPhone 14 con Yala Dev, contra staging)

Hace falta tu mano: escribir un Apple ID que NO sea el del iPhone 14, con su contraseña y su código.

1. En el iPhone 14, abre Yala Dev. Si tiene sesión en la nube, ciérrala: Ajustes › Tu cuenta de Yala › Cerrar sesión.
2. Ve a Ajustes › ¿Dónde viven tus datos? › Migrar a la nube y entra con **Apple** (el Apple ID del iPhone).
   - Si esa cuenta ya tiene finanzas, sale la hoja «Esta cuenta ya tiene datos» con **Usar otra cuenta**: sigue al paso 3.
   - Si no sale la hoja, avísame y te dejo el teléfono en ese estado.
3. Comprueba que la hoja **ya no** dice «Con Apple, Yala usa siempre la cuenta de este dispositivo».
4. Toca **Usar otra cuenta**. Debe salir el selector con tres botones; el tercero es **Otra cuenta de Apple**.
5. Tócalo. Se abre la página de Apple. **Bien** si te deja escribir otro Apple ID. Escribe el otro y termina.
6. **Bien** si vuelve sola a Yala y sigue con «Activando la nube…». **Mal** si se queda en blanco, vuelve al mismo Apple ID
   del teléfono o sale «No se pudo iniciar sesión».
7. Cierra Yala Dev del todo y vuelve a abrirla. **Bien** si la sesión sigue en la nube (no te saca al volver).
8. (Identidad) Si ese otro Apple ID ya tenía cuenta de Yala por el nativo en otro iPhone, debe ser la MISMA cuenta: los
   mismos datos.
