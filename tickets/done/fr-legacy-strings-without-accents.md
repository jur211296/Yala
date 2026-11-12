---
id: fr-legacy-strings-without-accents
status: done
priority: low
area: l10n
created: 2026-10-16
updated: 2026-10-25
source: encargo 2026-10-16-textos-2-1 (Frank)
---

# Unas 260 cadenas antiguas en francés salen sin tildes

Al corregir `settings.aiPrivacy` («Confidentialite et donnees IA» → «Confidentialité et données IA») se midió todo
`fr.lproj` con un detector de palabras que en francés siempre llevan tilde. Resultado, en `2.1` el 2026-10-16:

- **Las 1.003 cadenas nuevas o cambiadas desde `v2.0.4` están bien.** Los 22 aciertos del detector en ellas son
  verbos que no llevan tilde («Enregistre», «termine», «supprime»).
- **Las antiguas no: ~260 aciertos**, y el detector no las ve todas. Ejemplos a la vista: el título de Ajustes
  («Parametres»), «Categories», «Sous-categorie», «Depenses», «Selectionner», «Termine», «Mis a jour», «Gestion des
  donnees», «Bientot disponible», «Cette action ne peut pas etre annulee».

En la rama `2.2` el lote 9 de la auditoría UX ya corrigió los 21 textos de Presupuestos (card «Bug lote 9 · B7»);
el resto sigue igual en las dos ramas.

## Antes de tocarlo

Algunas de estas cadenas son **nombres sembrados que se comparan por texto** (categorías y subcategorías de la
siembra, `subcategory.balanceAdjustment`; ver la regla de l10n). Cambiar su valor sin migrar puede duplicar
categorías de usuarios franceses. Hace falta separar primero qué claves se usan para emparejar por nombre y tratar
esas aparte.

## Hecho cuando

`fr.lproj` no tiene palabras sin tilde que la lleven (revisado a ojo, no solo con el detector), las claves de
emparejamiento por nombre conservan el emparejamiento, y `LocalizationParityTests` sigue en verde.

## Resuelto (lote 12.4, 2026-10-25)

~260 → 0. La revisión de Sonnet corrigió las tildes del catálogo entero (y, de paso, pasó a «tu» lo que estaba en «vous», que era el trato minoritario: 259 frente a 938); un detector de palabras que en francés siempre llevan tilde encontró 9 más que se corrigieron a mano («Étiquettes», «Retour aux réglages», «Top catégories»…).
- Claves de emparejamiento por nombre: no se tocaron las protegidas (`qa/l10n-review/claves-protegidas.txt`). «Non attribue» pasó a «Non attribué» con la búsqueda que acepta el nombre viejo. Los nombres de la siembra (categorías por defecto) sí se corrigieron: el deduplicador no empareja por nombre; un usuario francés que ya los tiene conserva los suyos.
- Lo fija `TranslationLot124GuardTests.french_hasNoWordsMissingTheirAccent` (`.strings`, plurales e `InfoPlist`).
