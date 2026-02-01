//
//  SwiftDataConfiguration.swift
//  Yala
//
//  Configuración centralizada de SwiftData para aislamiento entre builds.
//

import Foundation
import SwiftData

enum SwiftDataConfiguration {
    /// Database name diferenciado por build.
    /// Usa APP_GROUP_IDENTIFIER de Info.plist (consistente con SharedContainerService).
    static var databaseName: String {
        if let appGroup = Bundle.main.object(forInfoDictionaryKey: "APP_GROUP_IDENTIFIER") as? String,
           appGroup.hasSuffix(".dev") {
            return "YalaModel-Dev"
        }
        return "YalaModel"
    }

    /// Schema completo de la app.
    static var schema: Schema {
        Schema([
            Category.self,
            Subcategory.self,
            Tag.self,
            Account.self,
            TransactionItem.self,
            Budget.self,
            ExchangeRate.self,
            FavoritePayment.self,
            ScheduledPayment.self,
            InboxDraft.self,
            MerchantMemory.self,
            NotificationItem.self,
        ])
    }

    /// ModelConfiguration lista para usar.
    static var configuration: ModelConfiguration {
        ModelConfiguration(databaseName)
    }
}
