---
id: copy-names-this-phone-outside-groups
status: backlog
priority: low
area: "copy, l10n, ipad"
created: 2026-10-26
updated: 2026-10-26
source: "medido al cerrar copy-names-the-iphone-outside-groups-storage (card hxah)"
---

# Unas 80 frases dicen «este teléfono» y también salen en el iPad

## Qué ve el usuario

En un iPad, avisos de Grupos, del Welcome y del cierre de sesión hablan de «este teléfono»: «Este teléfono no puede
sincronizar tus grupos», «Ya hay datos en este teléfono», «Este teléfono no tiene iCloud activo»…

## Lo medido (2026-10-26)

- `grep -c -i "teléfono" Yala/Resources/es.lproj/Localizable.strings` → 79 líneas (alguna es de otra cosa:
  `devseed.spPhone`, «cambiar de teléfono»).
- Es el mismo fallo que hxah (que cubrió solo «iPhone»), con otra palabra. En japonés 4 de esas claves dicen «iPhone»
  (`icloud.appleIDChanged.groupsLine`, `welcome.privateICloud.discardUnverifiedNoAccountBody`,
  `welcome.privateICloud.foundBody`, `welcome.privateICloud.noAccountProceedTitle`) y se quedaron fuera a propósito.

## Por dónde va

«este dispositivo» en los 16 idiomas con el término de i9r1, por script de textos (molde de hxah). Ojo con las que
hablan de cambiar de aparato («antes de cambiar de teléfono»): ahí «teléfono» puede ser correcto.
