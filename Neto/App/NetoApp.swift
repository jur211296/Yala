//
//  NetoApp.swift
//  Neto
//
//  Punto de entrada principal de la aplicación.
//

import SwiftData
import SwiftUI

@main
struct NetoApp: App {

    /// ModelContainer compartido para toda la app.
    /// Incluye todas las entidades base definidas en FIN-17.
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Category.self,
            Subcategory.self,
            Tag.self,
            Account.self,
            TransactionItem.self,
            Budget.self,
            ExchangeRate.self,
            FavoritePayment.self,
        ])

        // Nombre lógico del contenedor / base de datos
        let configuration = ModelConfiguration("NetoModel")

        do {
            return try ModelContainer(
                for: schema,
                configurations: configuration
            )
        } catch {
            // En una app final deberías manejar el error de forma más robusta.
            fatalError("Error al inicializar ModelContainer de Neto: \(error)")
        }
    }()

    @AppStorage("userTheme") private var userThemeRaw: Int = AppTheme.system.rawValue

    @State private var sessionState = SessionState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(AppTheme(rawValue: userThemeRaw)?.colorScheme)
                .task {
                    // Update exchange rates on app launch
                    let context = sharedModelContainer.mainContext

                    // First get today's rate
                    await ExchangeRateService.shared.updateTodayIfNeeded(context: context)

                    // Then preload historical data if needed (first launch or after data wipe)
                    await ExchangeRateService.shared.preloadHistoricalIfNeeded(context: context)

                    // Update any transactions with provisional exchange rates
                    await TransactionUpdateService.updateProvisionalTransactions(context: context)
                }
        }
        // Adjunta el contenedor de modelos a la escena principal.
        .modelContainer(sharedModelContainer)
        .environment(sessionState)
    }
}
