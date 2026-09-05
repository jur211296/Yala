//
//  GroupsExportBuilder.swift
//  Yala
//
//  G5-D2: export ampliado con grupos. Construye un CSV APARTE (`Yala_Grupos_<timestamp>.csv`)
//  con, por cada grupo activo del usuario: sus gastos (fecha, descripción, total, MI parte vía
//  shares, quién pagó, moneda), sus liquidaciones (de/para/monto/moneda/fecha) y un resumen de MI
//  balance neto por moneda.
//
//  IMPORTANTE:
//  - Read-only: NO muta SwiftData ni CloudKit. Los grupos existen HOY vía CloudKit (sin gate por
//    flag — el gate natural es "solo si hay grupos activos").
//  - "Mi member" se identifica SIEMPRE por el patrón `isCurrentUser` (molde
//    `GroupsViewModel.currentUserMemberIDs`), JAMÁS por userID directo — consistencia CloudKit/backend.
//  - El sentinel `__deleted_user__` se mapea vía `SplitMember.resolvedDisplayName`.
//  - Este archivo es SEPARADO del export personal: `TransactionsExportService` queda intacto.
//

import Foundation
import SwiftData

// MARK: - Bundle de datos por grupo (unidad testeable)

/// Datos ya fetcheados de UN grupo, para alimentar la generación pura del CSV.
/// Los tests construyen bundles con `@Model` directos (sin contexto).
@MainActor
struct GroupExportBundle {
    let group: SplitGroup
    let members: [SplitMember]
    let expenses: [SplitExpense]
    let shares: [SplitShare]
    let settlements: [SplitSettlement]
}

// MARK: - Builder

@MainActor
enum GroupsExportBuilder {

    // MARK: Detección de grupos exportables (gate de visibilidad del toggle)

    /// `true` si hay al menos un grupo activo (no archivado) que exportar.
    /// Un fetch fallido degrada a `false` (sin toggle) — nunca aborta el wizard.
    static func hasExportableGroups(in modelContext: ModelContext) -> Bool {
        !fetchActiveGroups(in: modelContext).isEmpty
    }

    // MARK: Escritura a archivo temporal

    /// Genera el CSV de grupos y lo escribe a un archivo temporal. Devuelve la URL, o `nil`
    /// si no hay grupos activos (nada que exportar). Usa `completeFileProtection` igual que el
    /// export personal (dato financiero protegido con el device bloqueado).
    static func exportGroupsCSV(in modelContext: ModelContext) throws -> URL? {
        guard let data = makeGroupsCSVData(in: modelContext) else { return nil }
        return try writeToTemporaryFile(data: data)
    }

    // MARK: Construcción de bundles desde el contexto

    /// Fetchea los grupos activos y sus datos, y genera el CSV. `nil` si no hay grupos.
    static func makeGroupsCSVData(in modelContext: ModelContext) -> Data? {
        let bundles = fetchBundles(in: modelContext)
        return makeGroupsCSVData(bundles: bundles)
    }

    private static func fetchActiveGroups(in modelContext: ModelContext) -> [SplitGroup] {
        let descriptor = FetchDescriptor<SplitGroup>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\.name)]
        )
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            #if DEBUG
            print("GroupsExportBuilder: fetch de grupos falló: \(error)")
            #endif
            return []
        }
    }

    private static func fetchBundles(in modelContext: ModelContext) -> [GroupExportBundle] {
        fetchActiveGroups(in: modelContext).compactMap { group -> GroupExportBundle? in
            let zoneID = group.cloudKitZoneID
            do {
                let members = try modelContext.fetch(FetchDescriptor<SplitMember>(
                    predicate: #Predicate { $0.groupZoneID == zoneID }))
                let expenses = try modelContext.fetch(FetchDescriptor<SplitExpense>(
                    predicate: #Predicate { $0.groupZoneID == zoneID },
                    sortBy: [SortDescriptor(\.date, order: .forward)]))
                let shares = try modelContext.fetch(FetchDescriptor<SplitShare>(
                    predicate: #Predicate { $0.groupZoneID == zoneID }))
                let settlements = try modelContext.fetch(FetchDescriptor<SplitSettlement>(
                    predicate: #Predicate { $0.groupZoneID == zoneID },
                    sortBy: [SortDescriptor(\.date, order: .forward)]))
                return GroupExportBundle(
                    group: group,
                    members: members,
                    expenses: expenses,
                    shares: shares,
                    settlements: settlements
                )
            } catch {
                #if DEBUG
                print("GroupsExportBuilder: fetch de datos del grupo \(zoneID) falló: \(error)")
                #endif
                return nil
            }
        }
    }

    // MARK: - Generación pura del CSV (testeable)

    /// Orden de columnas del CSV de grupos. `amount` es el número principal de cada fila
    /// (total del gasto / monto de la liquidación / balance neto); `myShare` es el extra
    /// solo para gastos.
    static var headerKeys: [String] {
        [
        L10n.Export.Groups.headerGroup,
        L10n.Export.Groups.headerType,
        L10n.Export.Groups.headerDate,
        L10n.Export.Groups.headerDescription,
        L10n.Export.Groups.headerFrom,
        L10n.Export.Groups.headerTo,
        L10n.Export.Groups.headerPaidBy,
        L10n.Export.Groups.headerAmount,
        L10n.Export.Groups.headerMyShare,
        L10n.Export.Groups.headerCurrency
        ]
    }

    /// Genera el CSV completo (Data con BOM UTF-8) a partir de los bundles ya fetcheados.
    /// Devuelve `nil` si no hay bundles (sin grupos = sin archivo).
    static func makeGroupsCSVData(bundles: [GroupExportBundle]) -> Data? {
        guard !bundles.isEmpty else { return nil }

        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let amountFormatter = NumberFormatter()
        amountFormatter.locale = Locale(identifier: "en_US_POSIX")
        amountFormatter.numberStyle = .decimal
        amountFormatter.minimumFractionDigits = 2
        amountFormatter.maximumFractionDigits = 2
        amountFormatter.groupingSeparator = ""

        func fmt(_ value: Double) -> String {
            amountFormatter.string(from: NSNumber(value: value)) ?? "0.00"
        }

        var lines: [String] = []
        lines.append(headerKeys.map { TransactionsExportService.csvEscaped($0) }.joined(separator: ","))

        let typeExpense = L10n.Export.Groups.typeExpense
        let typeSettlement = L10n.Export.Groups.typeSettlement
        let typeBalance = L10n.Export.Groups.typeBalance

        for bundle in bundles {
            let groupName = bundle.group.name

            // memberID (uuidString) → display name (resolviendo el sentinel de cuenta eliminada).
            let nameByMemberID = Dictionary(
                bundle.members.map { ($0.id.uuidString, $0.resolvedDisplayName) },
                uniquingKeysWith: { first, _ in first }
            )
            func name(_ memberID: String) -> String {
                nameByMemberID[memberID] ?? memberID
            }

            // "Mis members" = molde EXACTO de GroupsViewModel.currentUserMemberIDs, resolución canónica
            // incluida: sin ella el CSV del recién llegado no marcaba ninguna fila como suya.
            var myMemberIDs = Set(
                bundle.members
                    .filter { $0.isCurrentUser && $0.isActive }
                    .map { $0.id.uuidString }
            )
            // Resolver sobre los ACTIVOS — gemelo del de `GroupsViewModel.currentUserMemberIDs`.
            if let resolved = GroupExpenseService.resolveCurrentUserMember(
                from: bundle.members.filter(\.isActive)) {
                myMemberIDs.insert(resolved.id.uuidString)
            }

            let sharesByExpense = Dictionary(grouping: bundle.shares, by: \.expenseID)

            // --- Gastos ---
            for expense in bundle.expenses {
                let expenseShares = sharesByExpense[expense.id] ?? []
                let myShareValue: String
                if myMemberIDs.isEmpty {
                    myShareValue = ""   // no soy member activo del grupo → "mi parte" indefinida
                } else {
                    let mine = expenseShares
                        .filter { myMemberIDs.contains($0.memberID) }
                        .reduce(0.0) { $0 + $1.amount }
                    myShareValue = fmt(mine)
                }

                lines.append(row([
                    groupName,
                    typeExpense,
                    dateFormatter.string(from: expense.date),
                    expense.expenseDescription,
                    "",                              // from
                    "",                              // to
                    name(expense.paidByMemberID),    // paidBy
                    fmt(expense.amount),             // amount (total)
                    myShareValue,                    // myShare
                    normalizeCurrencyCode(expense.currencyCode)
                ]))
            }

            // --- Liquidaciones ---
            for settlement in bundle.settlements {
                lines.append(row([
                    groupName,
                    typeSettlement,
                    dateFormatter.string(from: settlement.date),
                    "",                              // description
                    name(settlement.fromMemberID),   // from
                    name(settlement.toMemberID),     // to
                    "",                              // paidBy
                    fmt(settlement.amount),          // amount
                    "",                              // myShare
                    normalizeCurrencyCode(settlement.currencyCode)
                ]))
            }

            // --- Mi balance neto por moneda ---
            if !myMemberIDs.isEmpty {
                let balances = GroupBalanceService.calculateBalances(
                    expenses: bundle.expenses,
                    shares: bundle.shares,
                    members: bundle.members,
                    settlements: bundle.settlements
                )
                // Neteo por moneda sumando todos MIS members (defensa contra duplicados).
                var netByCurrency: [String: Double] = [:]
                for balance in balances where myMemberIDs.contains(balance.memberID) {
                    netByCurrency[balance.currencyCode, default: 0] += balance.netBalance
                }
                for currency in netByCurrency.keys.sorted() {
                    let net = (netByCurrency[currency] ?? 0)
                    lines.append(row([
                        groupName,
                        typeBalance,
                        "",                          // date
                        "",                          // description
                        "",                          // from
                        "",                          // to
                        "",                          // paidBy
                        fmt(net),                    // amount (neto, con signo)
                        "",                          // myShare
                        normalizeCurrencyCode(currency)
                    ]))
                }
            }
        }

        let csvString = lines.joined(separator: "\n")
        var csvData = Data([0xEF, 0xBB, 0xBF])  // UTF-8 BOM (compat Excel)
        csvData.append(Data(csvString.utf8))
        return csvData
    }

    /// Escapa cada valor y los une con coma. Reusa el escaping CSV del export personal.
    private static func row(_ values: [String]) -> String {
        values.map { TransactionsExportService.csvEscaped($0) }.joined(separator: ",")
    }

    // MARK: - Escritura de archivo

    private static func writeToTemporaryFile(data: Data) throws -> URL {
        let tempDirectory = FileManager.default.temporaryDirectory

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date.now)

        let fileName = "Yala_Grupos_\(timestamp).csv"
        let fileURL = tempDirectory.appendingPathComponent(fileName)

        try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        return fileURL
    }
}
