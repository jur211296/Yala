//
//  NetoApp.swift
//  Neto
//
//  Punto de entrada principal de la aplicación.
//

import SwiftUI
import SwiftData

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
            ExchangeRate.self
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
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // Adjunta el contenedor de modelos a la escena principal.
        .modelContainer(sharedModelContainer)
    }
}
