# Pulido de textos 2.1 (siete tarjetas decididas por Jürgen 2026-10-12)
## Contexto
Jürgen decidió siete tarjetas de textos/pulido para 2.1. Van juntas en una sesión y un PR.
## Qué se pide
- q218 opción A: con letra grande, la fila de entradas se parte en dos líneas.
- 75ae opción A: reescribir las tres frases de las dos pantallas seguidas del welcome.
- vs1h opción A: un solo texto verdadero para «tus datos regresan a tu iCloud».
- 7nqz opción B: el grupo archivado dice solo la verdad.
- eb09 opción A: «Registrar con foto o archivo» (acepta PDF).
- upp4 opción B: la misma regla de «≈» en todo el Panel.
- lf6e opción A: en «ver por moneda», «≈» solo para la tasa dudosa.
Lee la tarjeta y el ticket de cada una (tablero ver <id>) antes de tocar nada. Todo texto nuevo en los 16 idiomas del catálogo.
## Qué NO tocar
Lógica de datos, sync, conversión de divisas. Solo textos, layout y el símbolo «≈».
## Reglas de build y Mini
Pipeline serie, 1 simulador, nice -n 10 xcodebuild -jobs 2, carga < 8. Capturas antes/después de cada cambio visible en ~/Claude/worktrees/_capturas/<fecha>-pulido-textos-2-1/.
## Gate tras el CI del PR anterior
Arranca cuando el PR anterior de la cola tenga el CI en verde o esté mergeado.
## PR a 2.1
Un PR contra 2.1, con capturas y lista de las siete tarjetas.
## Cómo se sabe
Los siete textos/visuales cambiados en los 16 idiomas, tests verdes, capturas antes/después.

## SIMULADORES iOS EN LA MINI (regla nueva, 2026-10-12)
Si usas el simulador o XCUITest: nunca más de un simulador encendido a la vez, y al terminar (y antes de cerrar) ejecuta `xcrun simctl shutdown all`. La Mini se cayó por memoria el 2026-10-12 ~13:30.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Es MODO AUTÓNOMO (auto-merge)?** → Sí: sesión de la cola en bypass. PR en cola de auto-merge.
Por qué: `CLAUDE.md` cuenta «una sesión de la cola en bypass» como autónoma. Alternativa descartada: dejar el PR abierto.

**D2 · q218: ¿qué pantallas?** → Resumen y Tendencias de Estadísticas pasan a `AdaptiveRowStack`; el Panel y Registros ya lo usaban.
Por qué: el ticket pedía mirar todas las que comparten el hero; solo esas dos seguían con `HStack`. Alternativa descartada: solo Resumen.

**D3 · 75ae: ¿cambiar también las variantes «Generic» y el título del mismatch?** → Las genéricas sí (dicen la misma frase sin el método); el título «Esa cuenta usa otro método» no.
Por qué: la opción A nombra tres frases; las genéricas son la misma frase, el título no estaba en la propuesta.

**D4 · vs1h: ¿tocar «Vuelve al modo privado»?** → No; solo «regresan/volverán» → «pasan a vivir en».
Por qué: la opción A cambia esa media frase; el título «Volver a iCloud» seguiría chocando con otra primera frase.

**D5 · 7nqz: texto verdadero** → «Su admin lo archivó y ya no admite miembros nuevos.»
Por qué: es lo único que el servidor impide hoy (`join_group`); el resto del grupo sigue editable.

**D6 · eb09: ¿qué claves?** → Las 11 del ticket + `control.imageEntry.description` + las 3 del widget (`widget.control.photoExpense`, `.desc`, `widget.ui.scanReceipt`), que es lo que de verdad pinta el control y el widget. Forma larga en hoja, paywall, Siri y atajo; corta («Foto o archivo») en control, widget y título corto. Frase de Siri nueva añadida a `AppShortcutsProvider` (es/en) y las viejas se quedan como sinónimo.
Por qué: el control usa las claves del widget, no las `control.imageEntry.*`; sin ellas el nombre viejo seguiría en pantalla.

**D7 · upp4: fórmula del umbral** → Panorama: `Σ|convertido dudoso|` / `|saldo mostrado|`. P&L: `Σ|pnl de filas dudosas|` / `|P&L total|`. La nota de la hoja del P&L sale si alguna fila lleva «≈».
Por qué: es el contrato de `ApproximateMarkThreshold` (numerador en magnitudes, denominador el número que se muestra). Alternativa descartada: exposición sobre exposición en el P&L, que no es el número mostrado.

**D8 · lf6e: zh-Hans** → Se quita también «约», no solo «≈».
Por qué: el ticket lo pide; «约» es la misma marca en otra forma.

**D9 · eb09: el paywall usa el nombre dentro de una frase** («%@ es una función exclusiva de Yala Pro») → `featureGate.imageInput` va en sustantivo: «Registro con foto o archivo», pareja de «Registro por voz».
Por qué: «Registrar con foto o archivo es una función…» y «Add with a photo or file is a…» no se leen bien. La hoja sí lleva el verbo.

**D10 · q218: con las dos filas separadas, las cifras seguían cortadas a AX3** («S/274,…50», medido en el simulador) → con letra grande el chip de variación baja también bajo su cifra (`AmountWithChipStack`); a tamaño normal, el mismo `HStack` de siempre.
Por qué: la decisión A pide que se lea; dos líneas no bastaban en un iPhone 17 Pro. Alternativa descartada: abreviar la cifra (era la opción B).
