# CI rojo · Lote UI VoiceOver y etiquetas (CurrencyConverter)
toca: unit CurrencyConverter del PR 832

Rama base: la del PR https://github.com/jur211296/Yala/pull/832 (o origin/2.3 + cherry del arreglo). Un solo PR que desbloquee el merge (push al mismo PR o PR de arreglo), un solo cierre. Máquina: la libre. Si la prueba va mejor en el celular que en el simulador, usa el iPhone 14 conectado por DeviceMCP. Si corres en la Max y otra sesión de otro proyecto ya usa un simulador, puedes abrir un segundo (tope 2 en la Max) o usar el iPhone 14 conectado por DeviceMCP. En la Mini el tope de simuladores es 1. Cierre autónomo. Termina con `/cerrar-total`. Commits y PR sin firma de IA.

## Contexto
Card blocked: CI rojo del lote UI 2.3 (VoiceOver y etiquetas) por un unit de CurrencyConverter (tablero-ci-rojo-el-pr-del-lote-ui-2-3-voiceover-3zik). El PR 832 no mergea.

## Qué se pide
Arreglar el unit (o flaky) que deja rojo el job tests; empujar al mismo PR o abrir uno que lo desbloquee; dejar el PR en verde y mergeable; card a done o in qa según toque.

## Qué NO hay que tocar
marketing/, reescrituras ajenas al fallo del unit.

## Cómo se sabe que está bien
Job tests verde en el PR 832 (o el de arreglo mergeado encima); card del CI rojo cerrada; `/cerrar-total`.
