# Archive build 25 (Yala 2.0) — en la Mac estable

Este build se debe archivar en **otra Mac** porque la principal está en macOS 27.0 beta
y Apple rechaza binarios archivados con el Xcode que esa beta permite (ITMS-90111).

Estado al 2026-06-18:
- Código en `origin/2.0` @ commit `1814117e` (build 25, MARKETING 2.0). Build verde verificado.
- Versión 2.0 en App Store Connect está en `INVALID_BINARY` (residuo del build rechazado en junio).
- **Metadata 100% lista** en los 9 locales (texto + screenshots). No hay nada que tocar ahí.
- Único bloqueo real: subir un binario válido (build 25) y reenviar.

---

## 1. Prerequisitos en la Mac estable

- [ ] **macOS estable (26.x), NO beta.**
- [ ] **Xcode = la versión que Apple exige HOY para envíos.** En junio era **Xcode 26.6 RC (17F109)**;
      verifica en https://developer.apple.com/news/releases por si ya salió la GA. Las betas (Xcode 27) NO se aceptan.
- [ ] `git pull` en la branch **2.0** → debe quedar en `1814117e` o posterior (confirma build 25 con:
      `grep -m1 CURRENT_PROJECT_VERSION Yala.xcodeproj/project.pbxproj` → `= 25;`).
- [ ] **Copiar `Secrets.xcconfig` a la raíz del repo** (AirDrop/USB/scp desde la Mac principal).
      Está **gitignored** → NO llega por `git pull`. Sin él el build no compila (es el baseConfigurationReference).
- [ ] Tener la cuenta de App Store Connect logueada en Xcode (Settings → Accounts) **o**, si usas CLI,
      copiar `~/.appstoreconnect/private_keys/AuthKey_A8BZSYVCD2.p8`.

## 2. Archivar y subir

### Opción A — Xcode GUI (recomendada para un archive puntual)
1. Scheme **Yala** (producción, NO "Yala Dev") · destino "Any iOS Device".
2. Product → Archive.
3. Organizer → Distribute App → App Store Connect → Upload (signing automático).

### Opción B — CLI
```bash
xcodebuild -scheme Yala -configuration Release \
  -archivePath ./build/Yala.xcarchive \
  -allowProvisioningUpdates \
  -authenticationKeyPath ~/.appstoreconnect/private_keys/AuthKey_A8BZSYVCD2.p8 \
  -authenticationKeyID A8BZSYVCD2 \
  -authenticationKeyIssuerID 7cf8546d-d793-484a-80f6-cd6600455951 \
  archive

xcodebuild -exportArchive \
  -archivePath ./build/Yala.xcarchive \
  -exportOptionsPlist .asc/artifacts/export-build24/ExportOptions.plist \
  -exportPath ./build/export \
  -allowProvisioningUpdates \
  -authenticationKeyPath ~/.appstoreconnect/private_keys/AuthKey_A8BZSYVCD2.p8 \
  -authenticationKeyID A8BZSYVCD2 \
  -authenticationKeyIssuerID 7cf8546d-d793-484a-80f6-cd6600455951
# subir el .ipa exportado con altool o Transporter
```

## 3. Después de subir (esto lo cierra Claude vía `asc`, o tú en la web)
Una vez el build 25 termine de procesar (~15–30 min, estado VALID):
1. Adjuntar build 25 a la versión 2.0 (`asc versions attach-build`) → la versión sale de `INVALID_BINARY`.
2. `asc submit preflight` (9 checks).
3. `asc submit create --confirm` → `WAITING_FOR_REVIEW`.

> Credenciales y gotchas completos: `$VAULT/planning/ASC-CLI.md`.
