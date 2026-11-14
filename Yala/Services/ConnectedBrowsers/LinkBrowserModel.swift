//
//  LinkBrowserModel.swift
//  Yala
//
//  «Vincular un navegador» (Yala web, lote 2): el iPhone lee el código QR que enseña la web (o la persona lo escribe),
//  enseña qué navegador lo pidió y desde dónde, pide Face ID (o el código del iPhone) y lo aprueba. El servidor hace el
//  resto (`webapp/src/worker/pairing.ts`): ese navegador entra con una sesión de solo lectura, sin que la sesión del
//  iPhone salga de aquí.
//
//  Contra el «QR que te enseña otro» (alguien te pide que escanees SU pantalla para entrar en tu cuenta), la
//  confirmación enseña el navegador y la ciudad antes de Face ID y dice que solo se escanee lo que se ve en la propia
//  pantalla.
//

import Foundation
import LocalAuthentication
import Observation

/// El código de la web tal como lo da la cámara (la dirección `…/v/K7Q4MD2X`) o el teclado («k7q4-md2x»). Mismas reglas
/// que `normalizeCode` del Worker: 8 símbolos de un alfabeto sin 0/O ni 1/I.
nonisolated enum WebLinkCode {
    static let alphabet = Set("23456789ABCDEFGHJKLMNPQRSTUVWXYZ")

    static func normalize(_ raw: String) -> String? {
        guard raw.count <= 200 else { return nil }
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = text.range(of: "/v/", options: .backwards) {
            text = String(text[range.upperBound...]).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        // Solo letras y dígitos: el separador que ponga el teclado («-», «'», «·», un espacio) no cuenta.
        let code = text.uppercased().filter { $0.isLetter || $0.isNumber }
        guard code.count == 8, code.allSatisfy({ alphabet.contains($0) }) else { return nil }
        return code
    }

    /// «K7Q4-MD2X», como lo enseña la web.
    static func display(_ code: String) -> String {
        guard code.count == 8 else { return code }
        return "\(code.prefix(4))-\(code.suffix(4))"
    }
}

/// Lo que pide la confirmación: Face ID, Touch ID o el código del iPhone.
enum LinkBrowserAuthResult: Equatable {
    case confirmed
    case cancelled
    /// El iPhone no tiene código: no hay nada más que pedir, la app ya está abierta.
    case noPasscode
    case failed
}

@MainActor
@Observable
final class LinkBrowserModel {
    enum Phase: Equatable {
        /// Escaneando o escribiendo el código.
        case entering
        case checking
        case confirm(WebLinkRequest)
        case approving(WebLinkRequest)
        case linked(WebLinkRequest)
    }

    enum Problem: Equatable {
        case invalidCode
        case expired
        case noCloud
        case sessionExpired
        case network
    }

    private(set) var phase: Phase = .entering
    private(set) var problem: Problem?
    /// Sube con cada vuelta a escanear: la pantalla monta un escáner nuevo (el anterior ya entregó su código).
    private(set) var attempt = 0

    private let client: ConnectedBrowsersClient
    private let authenticate: @MainActor (String) async -> LinkBrowserAuthResult

    init(client: ConnectedBrowsersClient, authenticate: @escaping @MainActor (String) async -> LinkBrowserAuthResult = LinkBrowserModel.deviceOwnerAuthentication) {
        self.client = client
        self.authenticate = authenticate
    }

    /// Lo que llega de la cámara o del campo de texto.
    func submit(_ raw: String) async {
        guard phase == .entering else { return }
        guard let code = WebLinkCode.normalize(raw) else {
            problem = .invalidCode
            DS.Haptic.error()
            return
        }
        problem = nil
        phase = .checking
        do {
            let request = try await client.peekLink(code: code)
            phase = .confirm(request)
        } catch {
            fail(with: error)
        }
    }

    /// «Confirmar con Face ID».
    func confirm(reason: String) async {
        guard case .confirm(let request) = phase else { return }
        switch await authenticate(reason) {
        case .confirmed, .noPasscode:
            break
        case .cancelled:
            return
        case .failed:
            DS.Haptic.error()
            return
        }
        phase = .approving(request)
        do {
            try await client.approveLink(code: WebLinkCode.normalize(request.codigo) ?? request.codigo)
            phase = .linked(request)
            DS.Haptic.success()
        } catch {
            fail(with: error)
        }
    }

    /// Volver a escanear (tras un error o al cancelar la confirmación).
    func restart() {
        phase = .entering
        problem = nil
        attempt += 1
    }

    private func fail(with error: Error) {
        #if DEBUG
        print("LinkBrowserModel: Error: \(error)")
        #endif
        switch error as? ConnectedBrowsersClientError {
        case .rejected(status: 404)?: problem = .expired
        case .rejected(status: 409)?: problem = .noCloud
        case .rejected(status: 400)?: problem = .invalidCode
        case .sessionExpired?: problem = .sessionExpired
        default: problem = .network
        }
        phase = .entering
        attempt += 1
        DS.Haptic.error()
    }

    /// Face ID / Touch ID con el código del iPhone como respaldo (`deviceOwnerAuthentication`).
    static func deviceOwnerAuthentication(reason: String) async -> LinkBrowserAuthResult {
        let context = LAContext()
        var policyError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &policyError) else {
            #if DEBUG
            print("LinkBrowserModel: Error: \(String(describing: policyError))")
            #endif
            return policyError?.code == LAError.passcodeNotSet.rawValue ? .noPasscode : .failed
        }
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) ? .confirmed : .failed
        } catch let error as LAError where [.userCancel, .appCancel, .systemCancel].contains(error.code) {
            return .cancelled
        } catch {
            #if DEBUG
            print("LinkBrowserModel: Error: \(error)")
            #endif
            return .failed
        }
    }
}
