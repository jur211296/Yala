---
id: revert-card-copy-says-datos-regresan-a-quien-nunca-estuvo
status: backlog
priority: low
area: "copy, l10n, modo-nube"
created: 2026-09-10
updated: 2026-10-08
source: "review del alcance de `reverse-cutover-cerrado-para-cuentas-born-cloud` (2026-09-10), decisión D6"
---

# «Tus datos regresan a tu iCloud» se lo dice también a quien nunca estuvo ahí

## El problema, en lenguaje de usuario

Creé mi cuenta de Yala con Google. Mis finanzas viven en la nube de Yala y nunca han pasado por mi
iCloud. Voy a Ajustes → «¿Dónde viven tus datos?» y leo: **«Vuelve al modo privado. Tus datos regresan
a tu dispositivo y a tu iCloud, sin perder nada.»**

No *regresan*: **van por primera vez**. Y la diferencia no es solo de estilo, porque para mí esa
operación es distinta de lo que el texto sugiere: se sube mi histórico completo a iCloud, no un delta,
así que puede tardar bastante más y consume espacio de mi cuenta de iCloud que hoy no está ocupado.

## Por qué aparece ahora

Hasta el 2026-09-10 el botón «Volver a iCloud» estaba **oculto** para las cuentas nacidas en la nube,
así que ese texto solo lo leía quien sí había migrado y para quien «regresan» era exacto.
`reverse-cutover-cerrado-para-cuentas-born-cloud` abrió la puerta, y con ella el texto empezó a
mostrarse a una población para la que la mitad de la frase es falsa.

## Dónde está

| Clave | Valor (es) | Fichero |
|---|---|---|
| `storage.revert.body` | «Vuelve al modo privado. Tus datos regresan a tu dispositivo y a tu iCloud, sin perder nada.» | `Yala/Resources/es.lproj/Localizable.strings:4672` |
| `storage.revert.confirm.message` | «Tus datos volverán a tu dispositivo y a tu iCloud. No perderás nada.» | `es.lproj:4694` |
| `storage.revert.confirm2.message` | «Se desactivará la nube en este dispositivo.» | `es.lproj:4697` (ésta sí es exacta para ambos) |

La card la pinta `Yala/App/Views/Settings/StorageSettingsView.swift:247` (`revertCard`), con el body en
`:253` y la doble confirmación en `:600-613`.

## Lo que NO se hizo, y por qué se dejó aquí

Se descartó arreglarlo dentro del ticket que abrió la puerta, por dos razones:

1. **`.claude/rules/l10n.md` dice «no reescribas copy que ya funciona».** Para la población migrada
   este texto es correcto y lleva tiempo en producción.
2. **Son 16 locales** y la decisión de fondo es de voz de producto, no técnica: hay al menos tres
   salidas razonables y elegir una es de Jürgen.

## Las tres salidas

- **A · Un texto que sea verdad para las dos poblaciones.** Cambiar «regresan a» por «pasan a vivir
  en». Un solo string por locale, sin ramas en la vista, y nadie lee nada falso. Es la más barata.
- **B · Una variante para born-cloud.** Clave nueva (`storage.revert.bodyBornCloud`) y una rama en
  `revertCard` según `hasEverMigrated` (el dato ya está: lo calcula `reverseEligibility()`). Permite
  decir lo que de verdad va a pasar —«subiremos tu histórico a tu iCloud por primera vez»— e incluso
  avisar del espacio. Es la más honesta y la más cara: 16 locales de un string nuevo, con
  `qa/scripts/add-l10n-key.sh` para materializar las 4 variantes.
- **C · No tocar nada.** Defendible si se considera que «tus datos» se lee como «el control de tus
  datos» y no como «los ficheros». Es la opción de hoy, y queda registrada como tal.

## Criterios de aceptación

- [ ] Jürgen elige A, B o C.
- [ ] Si A o B: los 16 locales al día (`LocalizationParityTests` en verde) y ninguna clave sparse.
- [ ] Si B: la rama de la vista cubierta por un test de la lógica de copy, no solo por el ojo.
- [ ] Si C: se cierra como `discarded` con el motivo, y esta ficha queda como el registro de que se
      miró y se decidió.

## Fuera de alcance

El copy de la web, la FAQ y la ficha de la App Store — eso es de Lola (`marketing/`, `Web/`) y va por
`session-redesign-web-and-store-copy`.

## Medido en 2.1 (triage 2026-10-08)

- Las coordenadas cambiaron. `storage.revert.body` está en `es.lproj/Localizable.strings:4663`. El mensaje de confirmación
  hoy se llama `storage.confirm.revertBody` (`:4685`), no `storage.revert.confirm.message`.
- `revertCard`: `StorageSettingsView.swift:450`, body en `:456`. Sin rama por born-cloud.

## Pregunta para Jürgen (triage 2026-10-08)

El copy de «Volver a iCloud» para quien nació en la nube:

- **A** · Un texto verdadero para las dos poblaciones («pasan a vivir en tu dispositivo y en tu iCloud»): un string por
  locale, en las dos claves.
- **B** · Una variante para born-cloud, con una rama en `revertCard` y un aviso de espacio.
- **C** · No tocar y cerrar como `discarded`.

**Recomendación: A.** Arregla lo falso con el mínimo de superficie: dos claves por 16 locales, sin ramas que testear.
Con A, `low`.

Triage 2026-10-08: abierto · medium → low · storage.revert.body y storage.confirm.revertBody siguen diciendo «regresan/volverán» y revertCard no distingue born-cloud; falta que Jürgen elija A, B o C.
