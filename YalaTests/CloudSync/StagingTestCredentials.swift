//
//  StagingTestCredentials.swift
//  YalaTests
//
//  Punto ÚNICO de lectura de las credenciales de los usuarios sintéticos del Supabase de
//  staging, para los tests E2E que hablan con el backend real.
//
//  NUNCA escribir aquí (ni en los tests) una contraseña literal. Estuvieron en claro en el
//  árbol de un repo público hasta el 2026-09-01; ver el ticket
//  `staging-test-credentials-in-public-repo`. Las contraseñas se leen del entorno y no tienen
//  valor por defecto: sin ellas, los tests que las necesitan aparecen SKIPPED, no rojos.
//
//  Cómo correrlos por línea de comandos — xcodebuild entrega al runner las variables con el
//  prefijo `TEST_RUNNER_`, que el runner retira antes de exponerlas:
//
//      TEST_RUNNER_YALA_CLOUD_E2E=1 \
//      TEST_RUNNER_USER_A_PASS='…' TEST_RUNNER_USER_B_PASS='…' \
//      xcodebuild test -scheme Yala -destination '…' -only-testing:YalaTests/…
//
//  Desde Xcode: mismas variables, sin prefijo, en el scheme (Test → Arguments →
//  Environment Variables).
//

import Foundation

enum StagingTestCredentials {

    /// Los usuarios sintéticos del molde I5 en el Supabase de staging.
    enum User: String {
        case a = "A"
        case b = "B"
        case c = "C"

        /// Email de la cuenta. Cuenta sintética de staging: no es un secreto, así que conserva
        /// valor por defecto. Override opcional con `USER_<X>_EMAIL`.
        var email: String {
            stagingEnv("USER_\(rawValue)_EMAIL")
                ?? "i5-user-\(rawValue.lowercased())@test.yala"
        }

        /// Contraseña de la cuenta. **Sin valor por defecto a propósito**: si no está en el
        /// entorno, no hay login y el test se salta.
        var password: String? {
            stagingEnv("USER_\(rawValue)_PASS")
        }
    }

    enum CredentialError: Error, CustomStringConvertible {
        case missingPassword(User)

        var description: String {
            switch self {
            case .missingPassword(let user):
                return """
                Falta la contraseña del usuario de test \(user.rawValue) en el entorno. \
                Exporta USER_\(user.rawValue)_PASS (o TEST_RUNNER_USER_\(user.rawValue)_PASS \
                si lanzas con xcodebuild). Ver qa/cloud/README.md.
                """
            }
        }
    }

    /// ¿Están en el entorno las contraseñas de todos estos usuarios? Se usa en los gates
    /// `@Test(.enabled(if:))` para que la ausencia de credenciales sea un SKIP y no un fallo
    /// de red incomprensible.
    static func areAvailable(_ users: User...) -> Bool {
        users.allSatisfy { $0.password?.isEmpty == false }
    }

    /// Cuerpo del password-grant de Supabase para ese usuario.
    ///
    /// Se serializa con `JSONSerialization` **a propósito**: escribirlo como texto
    /// interpolado (`"password":"\(pass)"`) reintroduciría en el árbol el mismo patrón
    /// literal que este ticket vino a quitar, y volvería a disparar el escáner de secretos.
    static func passwordGrantBody(for user: User) throws -> Data {
        guard let password = user.password, !password.isEmpty else {
            throw CredentialError.missingPassword(user)
        }
        return try JSONSerialization.data(
            withJSONObject: ["email": user.email, "password": password]
        )
    }
}

/// Lectura de una variable de entorno, tratando la cadena vacía como ausencia.
private func stagingEnv(_ key: String) -> String? {
    guard let value = ProcessInfo.processInfo.environment[key], !value.isEmpty else {
        return nil
    }
    return value
}
