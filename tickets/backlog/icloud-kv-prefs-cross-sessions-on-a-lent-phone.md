---
id: icloud-kv-prefs-cross-sessions-on-a-lent-phone
status: backlog
priority: high
area: "sesiones, modo-nube, settings"
created: 2026-09-14
source: "review adversarial de `remote-wipe-signal-honored-by-any-session`, lente de producto"
---

# Las 37 preferencias siguen cruzando entre el dueño del teléfono y quien lo usa

## El síntoma, en lenguaje de usuario

Uso el móvil que me prestaron, con mi cuenta de grupos. La app me llega con el **idioma, la moneda, los
ajustes del panel y el interruptor de avisos de pagos del dueño**. Y si yo los cambio, **se los cambio a
él** en su iPad.

## Lo medido (2026-09-14)

`PreferenceSyncService.applyRemoteValues()` aplica las 37 keys del iCloud-KV del Apple ID a los
`UserDefaults` locales siempre que `behavior == .icloudKeyValue` —o sea, siempre hoy— y los `set(…)`
escriben de vuelta al KV. **Ninguno de los dos sentidos mira el eje de sesión.**

Lo notable es que el repo ya conoció este daño y creyó haberlo cerrado. La cabecera de
`OwnerKeyValueStore` documenta que la fachada nació como guard por el ticket
`secundaria-la-visita-escribe-en-el-dominio-del-dueno` —seis vías medidas, más dos que aparecieron
después: «el idioma que elegía la visita, y el interruptor maestro de avisos de pagos»— y que el guard
**se retiró** con esta premisa:

> «desde la retirada de la sesión de visita (ADR 2026-09-09) solo hay una sesión por teléfono y el KV
> siempre es suyo»

**La celda F del mismo ADR contradice esa premisa**: el móvil prestado con una sesión solo-grupos es
justo el caso de dos identidades sobre un mismo KV, y es el caso motivador del ticket del vaciado
remoto. El propio fichero deja escrito dónde reponerlo: «Si algún día vuelven a convivir dos identidades
sobre este store, el guard se repone AQUÍ y en ningún otro sitio.»

## Por qué no se hizo en el PR del vaciado

Es otro objeto —las preferencias, no la señal de vaciado— y su alcance es de 37 keys en los dos sentidos.
Pero es el mismo eje y la misma premisa caída, así que sale de ahí.

## Criterios de aceptación

- [ ] Decidido si el guard de `OwnerKeyValueStore` se repone y con qué predicado.
- [ ] Si se repone: las preferencias del dueño no se aplican ni se pisan desde una sesión que no es la suya.
- [ ] La premisa escrita en la cabecera de `OwnerKeyValueStore` queda al día en cualquier caso.
