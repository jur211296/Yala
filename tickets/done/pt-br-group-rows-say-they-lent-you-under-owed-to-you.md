---
id: pt-br-group-rows-say-they-lent-you-under-owed-to-you
status: done
priority: medium
area: l10n
created: 2026-10-16
updated: 2026-10-16
source: revisión de Lola de las capturas App Store 2.1 en pt-BR (16-oct, lámina 06 y vídeo) · card del tablero enlazada en el PR
---

# En pt-BR, las filas de un grupo decían «Te emprestaram» bajo un total «Te devem»

## Qué se veía

En el detalle de un grupo en portugués de Brasil, la cabecera dice «Te devem R$ 380,00» y cada gasto que pagó otro
dice «Te emprestaram R$ 80,00». Las dos cosas son ciertas —en ese gasto debes tú, en el total te deben a ti—, pero
«te devem» y «te emprestaram» suenan a lo mismo y la pantalla parece contradecirse. En inglés no pasa: «Owed to you»
arriba y «You owe» / «You lent» en las filas, con el sujeto explícito.

## Qué se cambió

`pt-BR.lproj` y su alias `pt.lproj` (copia idéntica obligatoria: la vigila
`LocalizationParityTests.aliases_haveIdenticalValues_toTheirBase`): `groups.expense.youOwe` «Te emprestaram» → «Você
deve» y su pareja `groups.expense.youAreOwed` «Emprestou» → «Você emprestou», espejo de «You owe» / «You lent». La cabecera (`groups.summary.owedToMe`, «Te devem»)
no cambia: es lo que dice el texto de la ficha.

## Lo que queda igual

El español tiene la misma pareja («Te deben» arriba, «Te prestaron» en la fila) y nadie la ha marcado: no se tocó.
pt-PT tampoco (su revisión nativa es `pt-pt-needs-a-native-review-after-the-pt-br-sweep`).
