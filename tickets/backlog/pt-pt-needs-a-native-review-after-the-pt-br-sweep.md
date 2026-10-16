---
id: pt-pt-needs-a-native-review-after-the-pt-br-sweep
status: backlog
priority: low
area: l10n
created: 2026-10-16
updated: 2026-10-16
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
