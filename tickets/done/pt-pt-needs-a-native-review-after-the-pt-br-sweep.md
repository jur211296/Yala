---
id: pt-pt-needs-a-native-review-after-the-pt-br-sweep
status: done
priority: low
area: l10n
created: 2026-10-16
updated: 2026-10-25
source: barrido del pt-BR del encargo 2026-10-16-capturas-video-app-store-en-pt · card `tablero-pt-pt-su-bloque-de-respaldo-quedo-con-el-j1be`
---

# pt-PT: su bloque de respaldo quedó con el pt-BR viejo

`pt-PT.lproj` lleva debajo de sus overrides un «Fallback materializado del padre (pt-BR)»: copia de los valores de
pt-BR para que un usuario con el sistema en pt-PT no vea claves crudas. Esa copia es del pt-BR **anterior** al barrido
del 16-oct, que tenía ~170 cadenas sin acentos («Orcamentos», «Estatisticas», «Este mes»…), ~180 en tuteo de Portugal
y 16 en inglés.

El 16-oct se le aplicaron solo las correcciones que eran **únicamente de acento** (241 cadenas), porque valen igual
en Portugal. No se regeneró el bloque desde el pt-BR nuevo a propósito: eso le habría metido el «você» y el
vocabulario de Brasil a un usuario de Portugal.

## Qué falta

- Las 16 cadenas que siguen en inglés en el respaldo (`inbox.editDraft`, `inbox.cannotApprove`, `inbox.source*`,
  `inbox.errorNo*`, `inbox.duplicateWarning*`, `inbox.createAnyway`, `inbox.deleteConfirmMessage`).
- Una pasada nativa pt-PT del bloque: hoy mezcla formas de Brasil y de Portugal.
- Comprobar que la ficha de la App Store en pt-PT (Lola) usa las mismas palabras que la app.

## Resuelto (lote 12.4, 2026-10-25)

Pasada nativa pt-PT con Sonnet (`qa/l10n-review`, catálogo entero, guía de Portugal): 943 cadenas en la primera pasada, 8 en la segunda y 53 en una dirigida a lo que quedaba con «você», «o seu», «tela», «assinatura», «compartilhar». La pestaña ya dice «Registos» y los plurales tienen su propio `.stringsdict` en pt-PT.
- Las 16 en inglés de `inbox.*` estaban ya traducidas en este árbol; las tres que siguen iguales al inglés son nombres («Manual», «Apple Pay», «Siri»).
- Quedan dos con «você», y es a propósito: `subcategory.system.openingBalanceOwed/Debt` son nombres de sistema de Grupos que la app empareja por texto; cambiarlos pide migrar el nombre guardado (ticket `pt-pt-group-system-names-keep-the-brazilian-voce`).
- Lo fija `TranslationLot124GuardTests.europeanPortuguese_*`.
- Sin comprobar: que la ficha de la App Store en pt-PT (Lola, `marketing/`) use las mismas palabras. Fuera de mi territorio; va en el parte.
