# Revisión por vistas 2.3 · Grupos en el uso diario (zona 37)

Revisión de UX y eficiencia de Grupos con el caso de un viaje de 4 personas: apuntar un gasto, partirlo desigual, ver
quién le debe a quién (en soles y dólares) y saldar. No implementa nada y no elige: cada problema prioritario trae de tres
a cuatro alternativas maquetadas y una recomendación. Decide Jürgen. Fuera de alcance: invitación, consentimiento y
entrada a Grupos.

- **Abrir:** `index.html` (se abre en el móvil y en la Mac; capturas y estilo van al lado, en `capturas/` y `estilo.css`).
- **Respaldo:** `revision-grupos.pdf` (67 páginas, ~8 MB).
- **Regenerar:** `cd fuente && python3 build.py` (con `--todo <ruta>` deja la página única para imprimir el PDF).

## Vistas cubiertas

GroupsContainerView, GroupCardView, GroupDetailView, GroupRecordsView, GroupBalancesView, GroupStatsView,
GroupMembersView, GroupSettingsView, GroupsGlobalSettingsView, GroupFormView, GroupExpenseComposerView,
GroupExpenseFormView, GroupExpenseSuccessView, GroupSplitSelectorView, GroupTwoPersonSplitView, GroupReceiptSplitView,
MemberPickerView, SettlementFormView y GroupOpeningBalanceFormView. 72 capturas del simulador (de 110 tomadas; iPhone 17 Pro e iPad Pro 13,
iOS 27.2) con datos ficticios, incluidas texto grande (AX3) e iPad. Para tener cuatro personas se añadió a la semilla de
prueba, solo en local, una cuarta (Carla) y la cena partida desigual (`fuente/semilla-viaje-de-4.patch`; no va en el PR).

Dos matices: `GroupSplitSelectorView` no está en el camino de Grupos (solo lo usa el editor de pagos planificados); se capturó
su entrada y la hoja se documenta desde el código. «Cargando», «error» y «sin conexión» no se ven en el simulador: el
detalle no tiene estado de error (un fallo se ve como «Sin gastos») ni de sin conexión; leído en el código.

## Problemas, por severidad

| | Problema | Recomendada |
|---|---|---|
| 1 · alta | «¿Cuánto debo y a quién?» tiene cuatro respuestas: Saldos dice «Tú no le debes nada a nadie» encima de «Tú pagas a Ana S/ 40.00»; la lista, «Debes S/ 0.00»; 7 pagos para 4 personas («Menos pagos» viene apagado); «Beto paga a Tú» | A1: «Menos pagos entre ustedes» encendido por defecto en grupos de 3+ (+ el texto de A4) |
| 2 · alta | Partir desigual cuesta 11 toques; los campos llegan en «100.00» y borrar y escribir 150 dejó «1,100.00» (medido con toques sintéticos); se puede guardar un reparto que suma 399,99 | B2: escribe solo lo distinto y el resto se reparte solo (+ B1, tocar un importe lo selecciona) |
| 3 · media-alta | Saldar: solo quien debe o cobra puede apuntarlo; pagar de más se acepta sin aviso; al guardar no se confirma nada; con dos monedas, dos pagos | C2 + C3: «Todo / Una parte» con lo que queda, y aviso con «Deshacer» |
| 4 · media-alta | Con soles y dólares cada deuda son dos («S/ 150.00 + $ 42.50»), las cruzadas no se compensan y la moneda del grupo no se ve al crearlo | D1: chip «Todo en S/ ≈» en Saldos (+ D4 para pagar en una moneda) |
| 5 · alta | Con texto grande se corta lo que hay que leer para decidir («Cena de des…», «en parte…», «S/ 82.…»); la cifra no crece; VoiceOver lee el importe como «0.00» | E1 + E4: filas con texto grande y etiquetas de VoiceOver (E2 ya, barato) |
| 6 · media | La X o deslizar tiran el gasto a medias sin preguntar; cambiar de grupo también | F1: preguntar antes de descartar (+ F3 al tocar el selector de grupo) |
| 7 · media | En el iPad el detalle se estira de lado a lado y el reparto se ve fila a fila con el teclado | H1 + H3: ancho legible y «Nuevo gasto» a tamaño de página |

Eficiencia, medido (Debug, simulador, semilla del viaje): abrir Grupos tarda **178 ms de mediana** (150-346, 20 entradas,
marca `PERF grupos`); el Panel, 544 ms en los mismos arranques. Con los datos de un viaje la carga no es un problema. Lo
demás son hipótesis leídas en el código, con la forma de medirlas: entrar a un grupo lee y recalcula 2-3 veces y trae
todas las subcategorías; saldos y simplificación en el hilo principal, y Ajustes los recalcula otra vez; filas de la lista
recalculadas varias veces por pintado. Falta una semilla con un grupo grande para medirlas.

## Decisiones para Jürgen

1. Problema 1: ¿«Menos pagos entre ustedes» nace encendido en grupos de 3+ (A1)? ¿Solo en los nuevos? ¿Se corrigen ya la frase «no le debes nada a nadie» y «Beto paga a Tú» (A4)?
2. Problema 2: ¿reparto «escribe solo lo distinto» (B2)? ¿Seleccionar el importe al tocarlo en toda la app (B1)? ¿Se confirma el «1,100.00» con el dedo en el iPhone?
3. Problema 3: ¿«Todo / Una parte» (C2) y aviso con «Deshacer» (C3)? ¿Se reabre L13-1 para que cualquiera apunte un pago entre otros (C1)?
4. Problema 4: ¿chip «Todo en S/ ≈» (D1), con la tasa del día o la de cada gasto? ¿Saldar en un solo pago convertido (D4)?
5. Problema 5: ¿filas con texto grande (E1) y etiquetas de VoiceOver (E4)? ¿La cifra crece con el texto (E3), junto con PN-6 del Panel?
6. Problema 6: ¿preguntar antes de descartar (F1), también en «Apuntar pago» y «Saldo inicial»?
7. Problema 7: ¿ancho legible (H1) y «Nuevo gasto» a tamaño de página en el iPad (H3)? ¿Gastos y Saldos lado a lado (H2), ahora o más adelante?
8. Pendiente de la auditoría 2.2: el vocabulario de saldar (L13-5) y los nombres del puente (L13-14) siguen sin decidir y se notan en esta zona.
