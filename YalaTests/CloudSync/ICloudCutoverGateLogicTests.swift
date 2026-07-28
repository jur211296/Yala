//
//  ICloudCutoverGateLogicTests.swift
//  YalaTests / CloudSync
//
//  Tabla COMPLETA del veredicto puro del canal iCloud (bug C-1, molde GroupAcceptShareErrorLogicTests).
//  Pure-logic: sin SwiftData, sin CloudKit real, sin `Date.now`.
//
//  Lo que estas pruebas defienden, en una línea: el cutover no puede quedarse esperando PARA SIEMPRE a
//  que un marcador exporte por un canal que no existe (sin cuenta iCloud) o que ya dijo que no (cuota
//  llena) — y, simétricamente, la ambigüedad (offline, rate-limit) JAMÁS puede abortar una migración.
//

import CloudKit
import Testing

@testable import Yala

@Suite("ICloudCutoverGateLogic · veredicto del canal iCloud (C-1)")
struct ICloudCutoverGateLogicTests {

    // MARK: - El WAIVER (la fila que hace posible "dejar de usar iCloud sin iCloud")

    /// Sin cuenta Y sin huella CloudKit ⇒ no hay copia del corpus en la nube de Apple, así que el
    /// marcador es indeliverable Y prescindible. NO bloquea la entrada: si bloqueara, el usuario que
    /// nunca usó iCloud tendría el modo nube vetado de forma PERMANENTE (ningún reintento lo curaría).
    /// El `stallCause` es `.unknown` a propósito → presupuesto LARGO si el paso 4 llegara a medirse.
    @Test func sinCuentaYSinHuella_esWaiver_noBloqueaEntrada() {
        let verdict = ICloudCutoverGateLogic.decide(
            accountPresent: false, hasCloudKitFootprint: false, lastExportErrorCode: nil
        )
        #expect(verdict == .noChannelNoFootprint)
        #expect(verdict.blocksCutoverEntry == false)
        #expect(verdict.stallCause == .unknown)
    }

    // MARK: - Las filas que abortan ANTES de tocar nada durable

    /// Sin cuenta pero CON huella ⇒ existe una copia viva del corpus en CloudKit a la que no podemos
    /// avisar del cutover. Bloquea la ENTRADA (todavía no hay `.cloud` persistido ni marcador escrito,
    /// así que el rollback deja el device idéntico) y clasifica `.definitive`: esperar no arregla nada.
    @Test func sinCuentaPeroConHuella_bloqueaEntrada_yEsDefinitivo() {
        let verdict = ICloudCutoverGateLogic.decide(
            accountPresent: false, hasCloudKitFootprint: true, lastExportErrorCode: nil
        )
        #expect(verdict == .noAccountWithFootprint)
        #expect(verdict.blocksCutoverEntry)
        #expect(verdict.stallCause == .definitive)
    }

    /// `quotaExceeded` es la ÚNICA señal real de "iCloud lleno" que expone la plataforma (no hay API de
    /// espacio disponible), y es post-hoc. Con cuenta presente manda sobre todo lo demás: el write del
    /// marcador ya se sabe rechazado ⇒ bloquear la entrada y presupuesto CORTO en el paso 4.
    @Test func cuentaPresenteConCuotaLlena_bloqueaEntrada_yEsDefinitivo() {
        let verdict = ICloudCutoverGateLogic.decide(
            accountPresent: true, hasCloudKitFootprint: true, lastExportErrorCode: .quotaExceeded
        )
        #expect(verdict == .quotaExceeded)
        #expect(verdict.blocksCutoverEntry)
        #expect(verdict.stallCause == .definitive)
    }

    /// Tabla de códigos NO retriables (espeja `iCloudSyncService.isRetriable` sin tocarla): la cuenta
    /// existe pero CloudKit está inutilizable ⇒ mismo trato que la cuota. Si alguien moviera uno de
    /// estos códigos a la rama `default`, el cutover volvería a poder entrar sabiendo que no puede cerrar.
    @Test("códigos no retriables con cuenta → accountUnusable (bloquea, definitivo)", arguments: [
        CKError.Code.notAuthenticated,
        .managedAccountRestricted,
        .userDeletedZone,
    ])
    func cuentaPresenteConCodigoNoRetriable_esAccountUnusable(_ code: CKError.Code) {
        let verdict = ICloudCutoverGateLogic.decide(
            accountPresent: true, hasCloudKitFootprint: true, lastExportErrorCode: code
        )
        #expect(verdict == .accountUnusable)
        #expect(verdict.blocksCutoverEntry)
        #expect(verdict.stallCause == .definitive)
    }

    // MARK: - FAIL-OPEN (la propiedad más importante del gate)

    /// Los códigos RETRIABLES caen a `.healthy`: red caída, rate-limit o zona ocupada son ambigüedad,
    /// no un veto. Pinnea el fail-open — un error transitorio NUNCA debe abortar una migración que ya
    /// subió y verificó el snapshot completo; de eso se encarga el tope por tiempo del paso 4, no esto.
    @Test("códigos retriables con cuenta → healthy (no bloquea, unknown)", arguments: [
        CKError.Code.networkUnavailable,
        .networkFailure,
        .serviceUnavailable,
        .requestRateLimited,
        .zoneBusy,
        .limitExceeded,
    ])
    func cuentaPresenteConCodigoRetriable_esHealthy(_ code: CKError.Code) {
        let verdict = ICloudCutoverGateLogic.decide(
            accountPresent: true, hasCloudKitFootprint: true, lastExportErrorCode: code
        )
        #expect(verdict == .healthy)
        #expect(verdict.blocksCutoverEntry == false)
        #expect(verdict.stallCause == .unknown)
    }

    /// `nil` = "no sabemos nada" (el `lastExportError` vive EN MEMORIA: tras un boot fresco siempre es
    /// `nil`) ⇒ también `.healthy`. Es el caso MÁS común en producción, y es exactamente por eso que
    /// este probe es una muestra y no la autoridad: la red de seguridad real es el tope por tiempo.
    @Test func cuentaPresenteSinErrorConocido_esHealthy() {
        let sinHuella = ICloudCutoverGateLogic.decide(
            accountPresent: true, hasCloudKitFootprint: false, lastExportErrorCode: nil
        )
        let conHuella = ICloudCutoverGateLogic.decide(
            accountPresent: true, hasCloudKitFootprint: true, lastExportErrorCode: nil
        )
        #expect(sinHuella == .healthy)
        #expect(conHuella == .healthy)
        #expect(sinHuella.blocksCutoverEntry == false)
        #expect(conHuella.blocksCutoverEntry == false)
    }

    // MARK: - Precedencia: la ausencia de cuenta se decide ANTES del código de error

    /// Sin cuenta, el `lastExportErrorCode` es irrelevante: sin canal no hay export cuyo error clasificar
    /// (el código que quedó en memoria es de la sesión anterior). Solo la HUELLA decide entre waiver y
    /// bloqueo. Sin esta precedencia, un `.networkFailure` viejo convertiría un bloqueo legítimo
    /// (`noAccountWithFootprint`) en `.healthy` y el cutover entraría a atascarse.
    @Test("sin cuenta, el código de error no cambia el veredicto", arguments: [
        CKError.Code.quotaExceeded,
        .notAuthenticated,
        .managedAccountRestricted,
        .userDeletedZone,
        .networkFailure,
        .requestRateLimited,
    ])
    func sinCuenta_elCodigoDeErrorNoManda(_ code: CKError.Code) {
        #expect(ICloudCutoverGateLogic.decide(
            accountPresent: false, hasCloudKitFootprint: false, lastExportErrorCode: code
        ) == .noChannelNoFootprint)
        #expect(ICloudCutoverGateLogic.decide(
            accountPresent: false, hasCloudKitFootprint: true, lastExportErrorCode: code
        ) == .noAccountWithFootprint)
    }

    // MARK: - Contrato WIRE de los rawValues (se journalean)

    /// Los 5 rawValues literales. El veredicto se persiste en `MigrationState.cutoverICloudVerdictRaw`,
    /// así que renombrar un case rompería la LECTURA de un journal en vuelo (el device que se mató a
    /// mitad del cutover leería `nil` y perdería el rastro del waiver / la causa del fallo).
    /// Se pinnea también la dirección de lectura: `init(rawValue:)` sobre el literal exacto.
    @Test func rawValues_sonWireEstables_yRoundTrip() {
        #expect(ICloudChannelVerdict.healthy.rawValue == "healthy")
        #expect(ICloudChannelVerdict.noChannelNoFootprint.rawValue == "noChannelNoFootprint")
        #expect(ICloudChannelVerdict.noAccountWithFootprint.rawValue == "noAccountWithFootprint")
        #expect(ICloudChannelVerdict.quotaExceeded.rawValue == "quotaExceeded")
        #expect(ICloudChannelVerdict.accountUnusable.rawValue == "accountUnusable")

        #expect(ICloudChannelVerdict(rawValue: "healthy") == .healthy)
        #expect(ICloudChannelVerdict(rawValue: "noChannelNoFootprint") == .noChannelNoFootprint)
        #expect(ICloudChannelVerdict(rawValue: "noAccountWithFootprint") == .noAccountWithFootprint)
        #expect(ICloudChannelVerdict(rawValue: "quotaExceeded") == .quotaExceeded)
        #expect(ICloudChannelVerdict(rawValue: "accountUnusable") == .accountUnusable)
    }
}
