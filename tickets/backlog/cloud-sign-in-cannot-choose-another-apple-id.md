---
id: cloud-sign-in-cannot-choose-another-apple-id
status: backlog
priority: medium
area: "modo-nube, auth"
created: 2026-09-16
updated: 2026-09-17
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
