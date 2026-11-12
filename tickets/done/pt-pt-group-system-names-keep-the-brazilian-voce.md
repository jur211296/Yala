---
id: pt-pt-group-system-names-keep-the-brazilian-voce
status: done
priority: very-low
area: "l10n, groups"
created: 2026-10-26
updated: 2026-10-26
source: "card tablero-pt-pt-dos-subcategorias-de-sistema-de-gr-bxds"
---

# pt-PT: dos subcategorías de sistema de Grupos dicen «você»

## Qué ve el usuario

Con el iPhone en portugués de Portugal, las subcategorías de saldo inicial de Grupos se llaman «Saldo inicial (devem a
você)» y «Saldo inicial (você deve)»: trato de Brasil.

## Por qué no bastaba cambiar el texto

La subcategoría se guarda con el texto del idioma y el seed de Grupos (`seedSystemGroupCategoriesIfNeeded`) la busca
por ese nombre exacto. Con el texto nuevo, quien ya la tenía con el viejo recibía una segunda al volver a sembrar
(reinstalación, otro aparato).

## Hecho (2026-10-26)

- Texto pt-PT: «Saldo inicial (devem-te)» y «Saldo inicial (deves)» (tú, como it).
- `SystemSubcategoryNameLogic` acepta el nombre viejo por rol (molde de «Sin asignar», lote 12.4); lo usan el seed y
  `GroupBridgeSystemEntities`. Lo guardado no se renombra: un aparato pt-BR del mismo usuario dejaría de reconocerla.
  Quien ya la tenía la sigue viendo con el nombre viejo; los nuevos ven el nuevo.
- Test: `SystemSubcategoryLegacyNameTests` (texto, emparejamiento, seed sin duplicar con su control).
- Medido por el camino: la premisa «son las dos únicas de pt-PT con trato de Brasil» no es cierta. Quedan ~190 claves con
  «você» en el bloque de respaldo pt-BR de `pt-PT.lproj`; son de `pt-pt-needs-a-native-review-after-the-pt-br-sweep`.
