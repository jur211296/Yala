---
id: in-app-privacy-copy-says-data-never-leaves-the-device
status: backlog
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
