---
id: privacy-manifest-misses-cloud-account-data
status: done
priority: high
area: "privacy, release"
created: 2026-10-10
source: "Checklist de envío de 2.1 (docs/RELEASE-CHECKLIST-2.1.md §1), medido sobre origin/2.1 6937828ff"
---

# El manifiesto de privacidad no declara lo que recoge la cuenta en la nube

## Qué pasa

`Yala/Resources/PrivacyInfo.xcprivacy` declara audio, fotos, información financiera, historial de compras
e ID de dispositivo (`:11-70`). Con Modo Nube y Grupos en el backend, la app recoge además:

- **Nombre y email** de Apple o Google, guardados en `auth.users` (`Yala/Services/CloudSync/CloudAuthService.swift:318`; `qa/cloud/g12_01_delete_account_auth_users.sql:4`), y el alias de miembro de grupo (`supabase-groups-staging.ddl:147`).
- **ID de usuario**, el `sub` de Supabase en todas las tablas (`supabase-staging.ddl`) y en `appAccountToken` (`Yala/App/Services/StoreKitManager.swift:240-243`).
- **Otro contenido del usuario**: notas y texto en bruto de la Bandeja (`supabase-staging.ddl:215-246,391-398`).
- **Uso del producto y diagnósticos**: ping, alta y avisos técnicos (`Yala/Services/Metrics/MetricsEvent.swift:23-41`).

Y el **ID de dispositivo** figura como no vinculado y solo para Analytics (`:59-70`), cuando el IDFV queda en
`profiles.leader_device_id` (`Yala/Services/CloudSync/MigrationWorkExecutor.swift:343-347`) y la clave de App
Attest en `attest_keys.user_id` (`supabase-staging.ddl:438-446`).

## Motivos de API

- Falta `1C8F.1` para los ajustes del App Group: 21 ficheros usan `UserDefaults(suiteName:)`. Solo está `CA92.1`.
- El widget usa `UserDefaults(suiteName:)` y no tiene manifiesto propio.

## Qué hacer

Alinear el manifiesto con las etiquetas que Jürgen deje en App Store Connect (tabla de §1.2 del checklist).
Que digan lo mismo es lo que pide `docs/DECISIONS.md:1115`.

## Hecho cuando

El manifiesto declara lo mismo que las etiquetas de App Store Connect para 2.1, y el archive no da avisos de
motivos de API.

## Cierre (2026-10-15)

Resuelto en el repo por PR #446 (commit `9b7915b35`, merge `4eed5365a`). Medido sobre `origin/2.1` `a7bc39ee0`:

- `Yala/Resources/PrivacyInfo.xcprivacy` declara nombre, email, ID de usuario, otro contenido, uso del producto y
  diagnósticos; el ID de dispositivo pasa a vinculado (App Functionality + Analytics). `plutil -lint`: OK.
- Motivos de API: `UserDefaults` con `CA92.1` y `1C8F.1`; `FileTimestamp` con `C617.1`.
- `YalaWidgets/PrivacyInfo.xcprivacy` existe con `1C8F.1`. La carpeta es un grupo sincronizado y la única
  excepción de membresía del widget es `Info.plist`, así que el manifiesto entra en el target.

**Fuera del repo, sigue en Jürgen** (card `tablero-el-manifiesto-de-privacidad-no-declara-l-kgqv`, que no se
mueve): etiquetas de App Privacy en App Store Connect, la decisión de fotos/audio vinculados y el Privacy
Report del Organizer. El «Hecho cuando» completo depende de eso; lo que tocaba al código está hecho.

Encontrado al cerrar: `YalaShare` no tiene manifiesto propio. No usa `UserDefaults(suiteName:)` (grep vacío),
así que no le hace falta motivo de API.
