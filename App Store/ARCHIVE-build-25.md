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

## 2. Archivar + EXPORTAR en la Mac estable (Xcode 26.6 RC) → genera el .ipa

⚠️ **El archive (compilar) Y el export deben hacerse con el Xcode 26.6 RC.** El `DTXcodeBuild`/SDK que Apple valida (el del rechazo ITMS-90111) queda horneado en esas dos fases. El **upload** (paso 2b) es transporte puro — no recompila ni re-firma — y puede hacerse en la Mac principal. **No exportar en la Mac principal (Xcode 26.5): arriesga re-rechazo de SDK.**

### GUI (recomendado)
1. Scheme **Yala** (producción, NO "Yala Dev") · destino "Any iOS Device".
2. Product → Archive.
3. Organizer → Distribute App → App Store Connect → **Export** (NO "Upload") → guarda el `.ipa`.
4. Pasar el `.ipa` a la Mac principal (AirDrop/USB) — más chico que el `.xcarchive`.

### CLI (alternativa)
```bash
xcodebuild -scheme Yala -configuration Release \
  -archivePath ./build/Yala.xcarchive -allowProvisioningUpdates \
  -authenticationKeyPath ~/.appstoreconnect/private_keys/AuthKey_A8BZSYVCD2.p8 \
  -authenticationKeyID A8BZSYVCD2 -authenticationKeyIssuerID 7cf8546d-d793-484a-80f6-cd6600455951 \
  archive
xcodebuild -exportArchive \
  -archivePath ./build/Yala.xcarchive \
  -exportOptionsPlist .asc/artifacts/export-build24/ExportOptions.plist \
  -exportPath ./build/export -allowProvisioningUpdates \
  -authenticationKeyPath ~/.appstoreconnect/private_keys/AuthKey_A8BZSYVCD2.p8 \
  -authenticationKeyID A8BZSYVCD2 -authenticationKeyIssuerID 7cf8546d-d793-484a-80f6-cd6600455951
# resultado: ./build/export/Yala.ipa  → pasar a la Mac principal
```

## 2b. Subir el .ipa (en la Mac principal — Xcode-agnóstico)
El upload solo transporta el binario ya compilado; el `DTXcodeBuild` (26.6) embebido es lo que Apple valida.
- **Transporter.app** (Mac App Store): arrastrar el `.ipa` → Deliver, **o**
- CLI: `xcrun altool --upload-app -t ios -f ./Yala.ipa --apiKey A8BZSYVCD2 --apiIssuer 7cf8546d-d793-484a-80f6-cd6600455951`

## 3. Después de subir (esto lo cierra Claude vía `asc`, o tú en la web)
Una vez el build 25 termine de procesar (~15–30 min, estado VALID):
1. Adjuntar build 25 a la versión 2.0 (`asc versions attach-build`) → la versión sale de `INVALID_BINARY` y queda **editable**.
2. **Añadir los 4 locales nuevos** (nl-NL, pl, ja, zh-Hans). Ya traducidos y validados, pero ASC bloquea crear localizations mientras la versión está en `INVALID_BINARY` (`A relationship cannot be created in current state`). Tras el paso 1 ya se puede:
   - `asc metadata pull --app 6758253109 --version 2.0 --app-info <ID-editable> --dir ./meta`
   - `python3 "App Store/asc-extra-locales-2.0.py" ./meta`  (inyecta los 4 locales en ./meta)
   - `asc metadata push --app 6758253109 --version 2.0 --app-info <ID> --dir ./meta --dry-run` → debe mostrar **4 adds, 0 deletes**; repetir sin `--dry-run` para aplicar.
   - Screenshots de los 4: copiar el set en **inglés** (`asc screenshots download` de en-US → `upload` a cada locale nuevo, IPHONE_67 + IPAD_PRO_3GEN_129).
   - Textos revisables en `App Store/metadata-2.0-extra-locales.md`.
3. `asc submit preflight` (9 checks).
4. `asc submit create --confirm` → `WAITING_FOR_REVIEW`.

> Credenciales y gotchas completos: `$VAULT/planning/ASC-CLI.md`.
