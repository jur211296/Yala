---
id: in-app-privacy-copy-says-data-never-leaves-the-device
status: done
priority: high
area: "l10n, privacy"
created: 2026-10-10
source: "Checklist de envío de 2.1 (docs/RELEASE-CHECKLIST-2.1.md §7), medido sobre origin/2.1 6937828ff"
---

# Textos de la app dicen que los datos nunca salen del dispositivo

Con Modo Nube y Grupos en el backend, estos textos son falsos y el revisor de la App Store puede leerlos:

- `profile.privacyTitle` «Tus datos nunca salen de tu dispositivo» y `profile.privacyDesc` «Yala almacena tus datos personales únicamente en tu dispositivo…» (`Yala/Resources/es.lproj/Localizable.strings:1151-1152`).
- `common.dataPrivacy` (`:507`).
- `onboarding.privacyIcloud` «Solo tú tienes acceso a tus datos» (`:1832`).

Las cuatro claves, en los 16 idiomas. El texto nuevo sigue BRAND-VOICE §7: «Tu cuenta en tu iCloud
privado» / «Tu cuenta en la nube», sin «sesión».

## Hecho cuando

Ningún texto de la app dice que los datos no salen del dispositivo sin distinguir la cuenta en la nube, en
los 16 idiomas, antes del envío de 2.1.

## Cierre (2026-10-15)

Resuelto por el commit `587d6aa19` («la app deja de decir que los datos nunca salen del dispositivo»).
Medido sobre `origin/2.1` `a7bc39ee0`:

- Las cuatro claves cambiaron en las 16 `.lproj` (comparado contra `587d6aa19^`, 16/16 en cada una). En
  `es`: `profile.privacyTitle` y `common.dataPrivacy` = «Dónde viven tus datos»; `profile.privacyDesc`
  distingue iCloud privado, cuenta en la nube, Grupos e IA; `onboarding.privacyIcloud` = «Accedes a tus datos
  con tu cuenta».
- `rg -i "nunca salen|never leave|únicamente en tu dispositivo|only on your device|sin servidores|no servers"`
  sobre `Yala`, `YalaWidgets` y `YalaShare` (`.strings`, `.swift`, `.xcstrings`, sin tests): 0 resultados.
- Red viva: `YalaTests/PrivacyCopyForbiddenPhrasesTests.swift` falla si vuelve una frase de 2.0 en
  cualquier idioma.

La card «Textos de la app dicen que los datos nunca salen del dispositivo» ya estaba en done.
