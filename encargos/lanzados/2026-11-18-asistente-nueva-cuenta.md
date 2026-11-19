Yala
# Nueva cuenta por pasos con preguntas y opción «Prefiero formulario»
---
toca: Yala/App/Views/Settings/AccountsSettingsListView.swift,Yala/App/Views/Panel/PanelSheetsModifier.swift,Yala/App/Views/Accounts/AccountFormView.swift,Yala/App/Views/Accounts/AccountFormComponents.swift,Yala/App/Views/Onboarding/PrimerosPasos/FirstAccountFlowView.swift,Yala/Resources/de.lproj/AsistenteCuenta.strings,Yala/Resources/en-GB.lproj/AsistenteCuenta.strings,Yala/Resources/en.lproj/AsistenteCuenta.strings,Yala/Resources/es-419.lproj/AsistenteCuenta.strings,Yala/Resources/es-AR.lproj/AsistenteCuenta.strings,Yala/Resources/es-ES.lproj/AsistenteCuenta.strings,Yala/Resources/es.lproj/AsistenteCuenta.strings,Yala/Resources/fr.lproj/AsistenteCuenta.strings,Yala/Resources/it.lproj/AsistenteCuenta.strings,Yala/Resources/ja.lproj/AsistenteCuenta.strings,Yala/Resources/nl.lproj/AsistenteCuenta.strings,Yala/Resources/pl.lproj/AsistenteCuenta.strings,Yala/Resources/pt-BR.lproj/AsistenteCuenta.strings,Yala/Resources/pt-PT.lproj/AsistenteCuenta.strings,Yala/Resources/pt.lproj/AsistenteCuenta.strings,Yala/Resources/zh-Hans.lproj/AsistenteCuenta.strings,YalaTests/AsistenteCuenta/,YalaUITests/AsistenteCuenta/,tickets/done/2026-11-17-asistente-nueva-cuenta.md
esfuerzo: medium
cierre: cierra-sola
depende: Yala/asistente-nuevo-presupuesto
---

Pedido de Jürgen del 17-nov (20:51 Lima), con captura de Planificación. Base 2.3, un PR. Sesión enfocada solo en esta vista (una vista por sesión). Es parte de una serie: presupuesto (crea el patrón), pago planificado, grupo, cuenta y favorito.

## Qué quiere
- Al tocar crear, en vez del formulario, se abre un **proceso por pasos con preguntas** (una pregunta clara por pantalla, en lenguaje simple, con valores sugeridos y progreso arriba).
- Arriba, siempre visible, una opción para quien prefiere lo de siempre, por ejemplo «Prefiero formulario» (elige el texto más claro y corto). Al tocarla se muestra el formulario actual, con lo ya respondido pasado al formulario.
- Al final, un resumen breve y el botón de crear. Nunca un botón debajo del otro. X nativa para salir; si ya respondió algo, pregunta antes de descartar, igual que el formulario.
- No hace falta recordar la elección «Prefiero formulario» entre usos salvo que sea trivial; si lo haces, que se pueda volver al asistente.

## Esta vista
- Tocar «Nueva cuenta» en Ajustes › Cuentas y en el Panel. Hoy abre `AccountFormView`. Reúsa el flujo de primeros pasos `FirstAccountFlowView` si sirve, sin romperlo. Cuando la cuenta se crea desde dentro de otro flujo (selector de cuenta en Nuevo registro, `MissingStepExit`), no lo toques y anótalo en el cierre por si conviene después. Editar una cuenta existente sigue en el formulario.
- Reúsa el patrón compartido de `Yala/App/Views/Shared/AsistenteCreacion/` que dejó la sesión del presupuesto, sin modificarlo (no está en tu toca). Si le falta algo, resuélvelo en tu vista y anótalo como pendiente.

## Cómo entregar
- Tests de la lógica de pasos y del paso a formulario con lo respondido en `YalaTests/AsistenteCuenta/`; prueba de UI del recorrido completo y de «Prefiero formulario» en `YalaUITests/AsistenteCuenta/`.
- Capturas de cada paso y del formulario (iPhone 17 y SE, también con letra grande, claro y oscuro, y iPad).
- Puedes usar un segundo simulador en la Max además del de otra sesión, o el iPhone 14 por DeviceMCP. En la Mini, solo uno.
- Entregable visual: artifact de Claude con el recorrido paso a paso y el antes y después.
- Commits y PR sin firma de IA. Toca solo lo declarado; lo menor, con la opción recomendada, anotado en «Decidido sin consultar». Textos nuevos en `AsistenteCuenta.strings` de cada `.lproj`, nunca en `Localizable.strings`.
- Lo vital, según el modo fijado al arrancar (semi: pregunta y espera viva; nocturno: checkpoint recuperable y card «Espera decisión», sin mergear lo incompleto).
- Cierre: completo y CI verde, `/cerrar-total` con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», y el link del artifact.

## Paso 0

Decidido sin consultar (menor y reversible):
- **Preguntas**: tipo → moneda → nombre → saldo → (tarjeta: día de cierre → día de pago → recordatorio, este solo si se sabe el pago) → resumen. Son las de «Primera cuenta» (`FirstAccountFlowLogic`), con sus textos ya traducidos; solo el tipo y la moneda llevan pregunta nueva («¿Qué tipo de cuenta es?»: «¿Cuál creamos primero?» no vale fuera de Primeros pasos).
- **Una sola moneda**, como el formulario: el formulario no admite líneas al crear, así que varias monedas no podrían pasar a «Usar formulario» sin perder respuestas. La tarjeta sigue ofreciendo otra divisa después, desde su ficha.
- **Valores sugeridos**: tipo «Cuenta corriente», moneda la principal, nombre el del tipo, saldo 0, días «No lo sé», recordatorio un día antes (o el mismo día sin cierre).
- **Guardado**: `FirstAccountCreator` (el de Primeros pasos), que deja tipo, color, saldo inicial y días de tarjeta igual que el formulario.
- **Texto del botón**: «Usar formulario», el del contenedor compartido (no se toca).
- **Ficheros nuevos** en `Yala/App/Views/Accounts/AsistenteCuenta/` (el `toca` no reserva una carpeta; nuevos no chocan con nadie).
- **Formulario desde el asistente**: abre grande y, con lo respondido, pregunta antes de descartar.
- Fuera: crear cuenta desde Nuevo registro y `MissingStepExit` (siguen en el formulario); editar sigue en el formulario.
