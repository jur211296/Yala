import SwiftUI

/// Overlay de carga con blur de fondo
/// Uso: Operaciones asíncronas, guardando datos, cargando
struct YalaLoadingOverlay: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let message: String?
    let isPresented: Bool

    init(isPresented: Bool, message: String? = nil) {
        self.isPresented = isPresented
        self.message = message
    }

    var body: some View {
        ZStack {
            if isPresented {
                // Backdrop blur
                Color.black.opacity(DS.Opacity.overlay)
                    .ignoresSafeArea()

                // Loading card
                VStack(spacing: DS.Spacing.lg) {
                    ProgressView()
                        .scaleEffect(1.2)


                    if let message {
                        Text(message)
                            .font(DS.Typography.label)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(DS.Spacing.xxl)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .dsAnimation(.easeInOut(duration: DS.Animation.normal), value: isPresented, reduceMotion: reduceMotion)
    }
}

// MARK: - View Modifier

extension View {
    /// Aplica un overlay de carga sobre la vista
    func yalaLoading(_ isLoading: Bool, message: String? = nil) -> some View {
        self.overlay {
            YalaLoadingOverlay(isPresented: isLoading, message: message)
        }
    }
}

// MARK: - Inline Loading

/// Indicador de carga inline para botones y elementos pequeños
struct YalaLoadingInline: View {
    let text: String?

    init(_ text: String? = nil) {
        self.text = text
    }

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            ProgressView()
                .tint(.secondary)

            if let text {
                Text(text)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var isLoading = true

        var body: some View {
            VStack(spacing: DS.Spacing.xxxl) {
                // Toggle
                Toggle("Loading", isOn: $isLoading)
                    .padding()

                Divider()

                // Inline loading
                YalaLoadingInline("Cargando datos...")

                Divider()

                // Content with overlay
                VStack {
                    Text("Contenido de la app")
                    Text("Con overlay de carga")
                }
                .frame(maxWidth: .infinity, maxHeight: 200)
                .background(.thCard)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                .yalaLoading(isLoading, message: "Guardando...")
            }
            .padding()
            .background(.thBackground)
        }
    }

    return PreviewWrapper()
}
