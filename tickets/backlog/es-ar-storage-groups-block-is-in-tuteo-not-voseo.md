---
id: es-ar-storage-groups-block-is-in-tuteo-not-voseo
status: backlog
priority: low
area: "l10n"
created: 2026-09-11
source: "review adversarial de `detach-failure-looks-like-success` (lente de producto y copy)"
updated: 2026-10-08
---

# El bloque `storage.groups.*` de es-AR está en tuteo y el resto del idioma está en voseo

## El problema, en lenguaje de usuario

Quien tiene la app en español de Argentina lee «vos» en toda la app y de pronto «tú» en la pantalla de
«¿Dónde viven tus datos?». No rompe nada; suena a traducción de otro sitio.

## Lo medido (2026-09-11)

`Yala/Resources/es-AR.lproj/Localizable.strings` usa voseo en **124 sitios** (por ejemplo
`groups.errors.actionFailed` → «Volvé a intentarlo»), y **todo** el bloque `storage.groups.*` está en
tuteo: lo copió `add-l10n-key.sh`, que para `es-AR` copia el valor real de `es-419` en vez de dejar un
placeholder. BRAND-VOICE §9.4 manda voseo para es-AR.

## Lo que hay que hacer

Pasar el bloque entero a voseo, no una línea suelta: arreglar solo la última key añadida deja el bloque
más incoherente que antes. Y revisar si otros bloques nuevos heredaron lo mismo — el mecanismo del
script los produce a todos igual, así que probablemente no es el único.

## Cómo se prueba

`LocalizationParityTests` no lo ve (mide presencia de keys, no registro). Un escáner que busque formas
de tuteo (`tú `, `Vuelve`, `Inténtalo`, `tienes`) en `es-AR.lproj` daría la lista.

## Medido en 2.1 (triage 2026-10-08)

- Siguen en tuteo, entre otras: `storage.groups.detachBlockedTransient` («Inténtalo de nuevo…»), `storage.groups.detachBlockedPermanent` («Revisa tu conexión y vuelve a intentarlo») y `storage.groups.detachBlockedSession` («Entra otra vez…»).
- La deuda no es solo de este bloque: en `es-AR.lproj/Localizable.strings` hay unas 148 líneas con formas de tuteo («Vuelve», «Inténtalo», «Revisa», «tienes», «puedes»…) frente a unas 321 con voseo (grep aproximado del triage). El barrido tiene que ser del idioma entero.
- Ningún commit desde el 2026-09-11 se dedica a pasar es-AR a voseo.

## Fusionado de `es-ar-detach-and-signout-copy-lost-the-voseo` (triage 2026-10-08)

- `groups.errors.sessionExpired` (fuera de `storage.groups.*`) también está en tuteo: «Tu sesión caducó. Vuelve a iniciar
  sesión e inténtalo de nuevo.». Desde el 2026-09-25 la enseña también el paso 1 del cierre en la nube con cambios
  personales y la sesión caducada.
- `groups.errors.channelPaused` nació en voseo, así que las pantallas de bloqueo del desasociar mezclan los dos registros
  según el motivo.

Triage 2026-10-08: abierto · low → low · el tuteo sigue en `storage.groups.*` y en ~148 líneas más de es-AR; incoherencia de registro sin efecto sobre los datos.
