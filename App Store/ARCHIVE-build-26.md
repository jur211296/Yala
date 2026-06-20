# Archive build 26 (Yala 2.0) → TestFlight — en la Mac estable

Mismo motivo que el build 25: la Mac principal está en **macOS 27 beta + Xcode 26.5**, y Apple
rechaza los binarios archivados ahí (**ITMS-90111**). El **archive + export** van en la **Mac
estable**; el **upload** es transporte puro y puede hacerse en cualquiera.

Estado al 2026-06-19:
- Build 25 → **VALID en TestFlight** (subido 2026-06-18). Builds 18–25 todos VALID.
- Build 26 = build 25 + 2 fixes de hoy en `origin/2.0`:
  - `a847e7c6` **fix(budgets)**: backfill eager del CSV-mirror — recupera filtros de presupuesto perdidos tras un restore lento de iCloud (el presupuesto "se deseleccionaba" y contaba todo el periodo).
  - `27971d41` **fix(sync)**: el spinner de "Forzar sincronización" deja de colgarse cuando no hay nada que exportar.
  - + `chore(release): bump build 26`.
- Destino: **TestFlight** (testing). NO requiere attach-build ni submit a la store — basta subir el binario VALID.

---

## 1. Prerequisitos en la Mac estable
- [ ] **macOS estable (26.x), NO beta.**
- [ ] **Xcode = el que Apple exige HOY** (verifica https://developer.apple.com/news/releases; en junio era **26.6 RC (17F109)**). Las betas (Xcode 27) NO se aceptan.
- [ ] `git pull` en branch **2.0** → confirma build 26: `grep -m1 CURRENT_PROJECT_VERSION Yala.xcodeproj/project.pbxproj` → `= 26;`.
- [ ] **Copiar `Secrets.xcconfig` a la raíz del repo** (AirDrop/USB/scp desde la Mac principal). Está **gitignored** → NO llega por `git pull`. Sin él no compila (es el baseConfigurationReference).
- [ ] Cuenta de App Store Connect logueada en Xcode (Settings → Accounts) **o**, para CLI, `~/.appstoreconnect/private_keys/AuthKey_A8BZSYVCD2.p8`.

## 2. Archivar + EXPORTAR en la Mac estable → genera el .ipa
⚠️ **Archive (compilar) Y export deben hacerse con el Xcode que Apple acepta** — el `DTXcodeBuild`/SDK que Apple valida se hornea en esas dos fases. El **upload** (paso 3) es transporte puro: no recompila ni re-firma. **No exportar en la Mac principal (Xcode 26.5): arriesga re-rechazo de SDK (ITMS-90111).**

### GUI (recomendado)
1. Scheme **Yala** (producción, NO "Yala Dev") · destino "Any iOS Device".
2. Product → Archive.
3. Organizer → Distribute App → App Store Connect → **Export** (NO "Upload") → guarda el `.ipa`.
4. (Opcional) pasar el `.ipa` a la Mac principal para el upload.

### CLI (alternativa)
```bash
xcodebuild -scheme Yala -configuration Release \
  -archivePath ./build/Yala-26.xcarchive -allowProvisioningUpdates \
  -authenticationKeyPath ~/.appstoreconnect/private_keys/AuthKey_A8BZSYVCD2.p8 \
  -authenticationKeyID A8BZSYVCD2 -authenticationKeyIssuerID 7cf8546d-d793-484a-80f6-cd6600455951 \
  archive
xcodebuild -exportArchive \
  -archivePath ./build/Yala-26.xcarchive \
  -exportOptionsPlist .asc/artifacts/export-build24/ExportOptions.plist \
  -exportPath ./build/export-26 -allowProvisioningUpdates \
  -authenticationKeyPath ~/.appstoreconnect/private_keys/AuthKey_A8BZSYVCD2.p8 \
  -authenticationKeyID A8BZSYVCD2 -authenticationKeyIssuerID 7cf8546d-d793-484a-80f6-cd6600455951
# resultado: ./build/export-26/Yala.ipa
```

## 3. Subir el .ipa → TestFlight (Mac principal o estable — Xcode-agnóstico)
Antes de subir, opcional pero recomendado: `bash scripts/asc-preflight.sh` (aborta si el App ID de telemetría está vacío o si reaparecen claves OPENAI/EXCHANGE en el binario).
- **Transporter.app** (Mac App Store): arrastrar el `.ipa` → Deliver, **o**
- `xcrun altool --upload-app -t ios -f ./Yala.ipa --apiKey A8BZSYVCD2 --apiIssuer 7cf8546d-d793-484a-80f6-cd6600455951`, **o**
- (solo en la Mac con el Xcode correcto) `asc builds upload --app 6758253109 --wait`.

## 4. Después de subir
- Esperar `processingState: VALID` (~15–30 min): `asc builds list --app 6758253109 --limit 3`.
- TestFlight distribuye el build 26 a los testers del grupo beta automáticamente.
- **NO** hace falta attach-build ni submit a review (eso es solo para publicar a la store; ya lo cubrió el flujo del build 25).

> Credenciales y gotchas completos: `$VAULT/planning/ASC-CLI.md`. Checklist del build anterior: `App Store/ARCHIVE-build-25.md`.
