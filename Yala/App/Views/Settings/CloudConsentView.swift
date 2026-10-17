//
//  CloudConsentView.swift
//  Yala
//
//  Pantalla de consentimiento informado del Modo Nube (§2.8 / §k.6, I14 P5). SIEMPRE precede al sign-in
//  (el login envía identidad) y a la doble confirmación de migración. Dice, en lenguaje claro, QUÉ sale
//  del dispositivo, QUIÉN puede leerlo y qué NO viaja. Al aceptar emite la telemetría, registra
//  `cloudConsentAcceptedAt` + `cloudConsentTextVersion` (trazabilidad GDPR §e.6) **si el caller ya conoce
//  su ruta** y ejecuta `onAccept` (el caller sigue con la doble confirmación → migración/adopt).
//
//  M0 (ola M, §6.3 de MODO-NUBE-SPEC-M1-REVIVAL): la PERSISTENCIA es lo único condicional, y no por
//  gusto. El destino de esas dos keys lo resuelve `PreferenceSyncService` en el INSTANTE de escribir, y
//  en la RE-ENTRADA del Welcome ese instante es anterior al guard cross-cuenta ⇒ el epoch de la invitada
//  caía en el iKV del Apple ID del DUEÑO. La pantalla no se mueve de sitio (pedir permiso después del
//  sign-in sería pedirlo para algo ya hecho); lo que se difiere es la escritura, y la hace
//  `CloudConsentRegistrar` desde el punto que la tabla `CloudConsentRegistrationLogic` elige.
//
//  Distinción (§k.6): este consent es sobre PRIVACIDAD (qué sale / quién lo lee). La doble confirmación de
//  migración (patrón `DataWipeService`) es sobre la ACCIÓN (mover los datos) y la muestra `StorageSettingsView`.
//
//  W3 (decisión del owner 2026-08-11, puntos 12-14 de MODO-NUBE-REVISION-FLUJOS-NOTAS): esto es una
//  LECTURA DE TÉRMINOS, no una alerta grave — el usuario está subiendo sus datos a la nube, como en la
//  mayoría de sus aplicaciones. De ahí que no haya iconografía de alarma (fuera el `hand.raised.fill` del
//  header y los `info.circle.fill` de cada punto) y que los 7 bullets sean TRES + un pie. Qué salió y a
//  dónde, para que legal no pierda el rastro: el resumen que viaja al proveedor de IA vive en el consent
//  de IA (`aiConsent.chatMessage`) y la ubicación de los servidores en la política de privacidad, a un tap
//  de aquí. `CloudConsentText.version` se bumpeó por ese recorte.
//
//  **La MISMA pantalla sirve a los tres contextos** —alta born-cloud, migración desde iCloud y re-entrada
//  a una cuenta que ya existe—. El contrato (título, tres puntos y pie) no puede asumir ninguno de los tres: el
//  título habla de dónde viven los datos y no de «activar» nada. **Lo único que cambia con el contexto es el verbo
//  del botón** (UX 2.2 · L6-4): «Entendido, entrar a mi cuenta», «…crear mi cuenta» o «…llevar mis datos a la nube»,
//  que elige `CloudConsentCopyLogic`. Antes decía «Entiendo y quiero activar la nube» también a quien volvía a una
//  cuenta que ya usaba.
//
//  **UX 2.2 · L6-4 (variante 1 elegida por Jürgen): tres fichas y no tres viñetas.** Cada punto lleva su icono en
//  color sólido, un título que se lee de un vistazo y el detalle debajo. El detalle dice lo mismo que las viñetas
//  —qué sale, quién lo lee, qué no viaja, cómo se entra y qué pasa si se pierde el acceso—, así que el contrato no
//  cambió y `CloudConsentText.version` no sube.
//

import SwiftUI

struct CloudConsentView: View {
    /// Ruta que abrió el consent (para la telemetría §j.4).
    let path: CloudMigrationController.ConsentPath
    /// M0 · ¿escribe ESTA pantalla el registro GDPR al aceptar? `true` en los dos contextos que ya
    /// conocen su ruta cuando lo piden: la migración desde Ajustes y el alta born-cloud (cuyo claim
    /// además lo VERIFICA — paso 5 de `BornCloudSignUpService`). La RE-ENTRADA del Welcome lo pasa a
    /// `false` y escribe ella cuando el guard cross-cuenta dice por dónde va. La TELEMETRÍA no se
    /// difiere en ningún caso: aceptar ocurrió aquí.
    var persistsOnAccept = true
    /// Se invoca al ACEPTAR (tras el registro —cuando toca— y la telemetría). El caller sigue con la
    /// doble confirmación.
    var onAccept: () -> Void
    /// Paso 8 · qué hace «Cancelar». `nil` —todos los callers anteriores— es `dismiss()`, que cierra la
    /// presentación que lo contiene. La activación de Yala completo lo monta DENTRO de su sheet, donde cancelar
    /// el consentimiento es volver a la elección privado / nube y no cerrar la activación entera.
    var onCancel: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        Text(L10n.UXLote6.consentLead)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        ForEach(Self.points, id: \.title) { point in
                            consentPoint(point)
                        }
                    }
                    .padding(.horizontal, DS.Spacing.lg)

                    Text(L10n.Storage.Consent.footer)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, DS.Spacing.lg)

                    Button {
                        openURL(AppConstants.privacyURL)
                    } label: {
                        Text(L10n.Storage.Consent.privacyLink)
                            .font(DS.Typography.caption.weight(.medium))
                            .foregroundStyle(DS.Semantic.infoForeground)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, DS.Spacing.lg)

                    ctaSection
                }
                .padding(.vertical, DS.Spacing.xxl)
            }
            .yalaScreenBackground(.subtle)
            .navigationTitle(L10n.Storage.Consent.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.Common.cancel) {
                        if let onCancel { onCancel() } else { dismiss() }
                    }
                        .accessibilityIdentifier("storage_consent_cancel")
                }
            }
        }
    }

    /// Un punto del contrato (UX 2.2 · L6-4, variante 1 elegida por Jürgen): una ficha con su icono en color SÓLIDO,
    /// un título corto que se lee de un vistazo y el detalle completo debajo. Antes eran tres viñetas de cuatro o cinco
    /// líneas sin jerarquía, y es el paso que decide la privacidad de la persona. **El detalle no se recorta**: dice lo
    /// mismo que decían las viñetas (el contrato es el de `CloudConsentText.version`, que por eso no sube).
    private struct Point {
        let icon: String
        let fill: Color
        let title: String
        let detail: String
    }

    private func consentPoint(_ point: Point) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            SolidIconTile(systemName: point.icon, fill: point.fill)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(point.title)
                    .font(DS.Typography.subheadlineEmphasized)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(point.detail)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .accessibilityElement(children: .combine)
    }

    private var ctaSection: some View {
        VStack(spacing: DS.Spacing.md) {
            // L6-4: el botón dice lo que va a pasar al tocarlo —entrar, crear o llevar los datos—, no «activar la nube»
            // a quien vuelve a una cuenta que ya usaba. Lo decide `CloudConsentCopyLogic` con el contexto.
            YalaPrimaryButton(CloudConsentCopyLogic.acceptTitle(for: path), icon: "checkmark.icloud") {
                registerConsent()
                onAccept()
            }
            .accessibilityIdentifier("storage_consent_accept")
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    /// Registra el consentimiento: persistencia GDPR (si el caller conoce ya su ruta — M0) + telemetría.
    /// La escritura vive en `CloudConsentRegistrar`, escritor ÚNICO de las dos keys: en `.icloud` va a
    /// iKV y el drenaje del cutover la lleva al backend; en `.cloud` (adopt) va directo al outbox de
    /// prefs; en secundaria, `.localOnly`. Cuál de las tres es depende del INSTANTE, no de la pantalla.
    private func registerConsent() {
        if persistsOnAccept { CloudConsentRegistrar.register() }
        MetricsService.cloudConsentAccepted(path: path.rawValue)
    }

    /// Lo que el usuario tiene que saber ANTES de firmar, en orden: dónde acaban sus datos y
    /// quién los lee · qué NO viaja (las fotos: su ausencia es pérdida real) · cómo se entra y
    /// qué pasa si pierde ese acceso. El cuarto bloque —volver atrás es posible— va al pie:
    /// es un alivio, no una advertencia, y mezclarlo aquí lo disfrazaba de riesgo.
    private static var points: [Point] {
        [
            Point(icon: "server.rack", fill: SolidIconTilePalette.transactions,
                  title: L10n.UXLote6.consentServersTitle, detail: L10n.Storage.Consent.pointServers),
            Point(icon: "photo.on.rectangle", fill: SolidIconTilePalette.accounts,
                  title: L10n.UXLote6.consentPhotosTitle, detail: L10n.Storage.Consent.pointPhotos),
            Point(icon: "key.fill", fill: SolidIconTilePalette.categories,
                  title: L10n.UXLote6.consentAccessTitle, detail: L10n.Storage.Consent.pointAccess),
        ]
    }
}
