import SwiftUI
import Foundation
import SwiftData
import UniformTypeIdentifiers
#if canImport(TabularData)
import TabularData
#endif

struct ContentView: View {
    @Query private var itemsRaw: [TransactionItem]
    @Environment(\.modelContext) private var ctx
    
    @State private var amount: String = ""
    @State private var currency: String = "PEN"
    @State private var note: String = ""
    @State private var isIncome: Bool = false
    @State private var categoryName: String = "General"
    @State private var showCSVImporter = false
    @State private var importError: String? = nil
    
    private var items: [TransactionItem] { itemsRaw.sorted { $0.date > $1.date } }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                GroupBox("Registrar movimiento") {
                    HStack {
                        TextField("Monto", text: $amount).keyboardType(.decimalPad)
                        TextField("Moneda (ISO)", text: $currency).frame(width: 80)
                        Toggle("Ingreso", isOn: $isIncome).labelsHidden()
                    }
                    TextField("Categoría", text: $categoryName)
                    TextField("Nota (opcional)", text: $note)
                    Button("Agregar") { addTransaction() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canSubmit)
                }
                .padding(.horizontal)
                
                List {
                    ForEach(items) { item in
                        HStack {
                            Text(item.date, format: .dateTime.year().month().day())
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text(currencyString(item.amount, code: item.currencyCode))
                                    .foregroundStyle(item.amount >= 0 ? .green : .red)
                                Text(item.category?.name ?? "Sin categoría")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { idx in
                        for i in idx { ctx.delete(items[i]) }
                        try? ctx.save()
                    }
                }
            }
            .navigationTitle("Finaria")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Importar CSV") { showCSVImporter = true }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
            .onAppear { seedCategoriesIfNeeded() }
            .fileImporter(
                isPresented: $showCSVImporter,
                allowedContentTypes: [.commaSeparatedText, .plainText]
            ) { result in
                guard case .success(let url) = result else { return }
                importCSV(from: url)
            }
            .alert("Error importando CSV", isPresented: Binding(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(importError ?? "")
            }
        }
    }
    
    private var canSubmit: Bool {
        Decimal(string: amount.replacingOccurrences(of: ",", with: ".")) != nil && !currency.isEmpty
    }
    
    private func addTransaction() {
        guard let value = Decimal(string: amount.replacingOccurrences(of: ",", with: ".")) else { return }
        let cat = fetchOrCreateCategory(named: categoryName, isIncome: isIncome)
        let signed = isIncome ? value : -abs(value)
        let item = TransactionItem(date: Date(), amount: signed, currencyCode: currency.uppercased(),
                                   note: note.isEmpty ? nil : note, category: cat)
        ctx.insert(item)
        try? ctx.save()
        amount = ""; note = ""
    }
    
    private func fetchOrCreateCategory(named name: String, isIncome: Bool) -> Category {
        if let existing = try? ctx.fetch(FetchDescriptor<Category>(predicate: #Predicate { $0.name == name })).first {
            return existing
        }
        let c = Category(name: name, colorHex: isIncome ? "#2A9D8F" : "#1D3557", isIncome: isIncome)
        ctx.insert(c); return c
    }
    
    private func seedCategoriesIfNeeded() {
        let current = (try? ctx.fetch(FetchDescriptor<Category>())) ?? []
        guard current.isEmpty else { return }
        for n in ["Alimentación","Transporte","Hogar","Salud","Ocio","Ingresos"] {
            ctx.insert(Category(name: n, colorHex: "#8E8E93", isIncome: n == "Ingresos"))
        }
        try? ctx.save()
    }
    
    /// Normaliza y parsea montos con diferentes formatos ("1,234.56", "1.234,56", "(1.234,56)", "S/ 1 234,56", "-1234,56-", etc.)
    private func parseDecimal(from rawInput: String) -> Decimal? {
        var s = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        // Espacios no separables y variantes de guion
        s = s.replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "−", with: "-")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
        // Remueve símbolos de moneda comunes
        ["US$", "S/", "$", "€", "£"].forEach { sym in s = s.replacingOccurrences(of: sym, with: "") }
        
        // Determina signo por paréntesis o guiones
        var isNegative = false
        if s.contains("(") && s.contains(")") { isNegative = true; s = s.replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "") }
        if s.hasPrefix("-") { isNegative.toggle(); s.removeFirst() }
        if s.hasSuffix("-") { isNegative.toggle(); s.removeLast() }
        
        // Deja solo dígitos y separadores "," y "." para decidir el decimal
        let allowed = Set("0123456789,.")
        let filtered = s.filter { allowed.contains($0) }
        var result = ""
        
        // Elegimos el **último** separador como decimal y eliminamos los demás
        let lastDot = filtered.lastIndex(of: ".")
        let lastComma = filtered.lastIndex(of: ",")
        let lastSepIndex: String.Index?
        if let d = lastDot, let c = lastComma { lastSepIndex = (d > c) ? d : c }
        else if let d = lastDot { lastSepIndex = d }
        else if let c = lastComma { lastSepIndex = c }
        else { lastSepIndex = nil }
        
        if let sepIndex = lastSepIndex {
            // Recorremos y construimos: guardamos dígitos; sólo en el índice final del separador ponemos "."
            var i = filtered.startIndex
            while i < filtered.endIndex {
                let ch = filtered[i]
                if i == sepIndex {
                    result.append(".")
                } else if ch.unicodeScalars.allSatisfy({ CharacterSet.decimalDigits.contains($0) }) {
                    result.append(ch)
                }
                i = filtered.index(after: i)
            }
        } else {
            // Sin separadores: sólo dígitos
            result = filtered.filter { $0.unicodeScalars.allSatisfy { CharacterSet.decimalDigits.contains($0) } }
        }
        
        if result.isEmpty { return nil }
        if isNegative { result = "-" + result }
        return Decimal(string: result)
    }
    
    /// Normaliza códigos de moneda: acepta "PEN", "S/", "US$", "$", "EUR", "€" → ISO 4217 cuando es posible.
    private func normalizeCurrencyCode(_ raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if t.contains("PEN") || t.contains("SOL") || t.contains("S/") { return "PEN" }
        if t.contains("USD") || t.contains("US$") || t == "$" { return "USD" }
        if t.contains("EUR") || t.contains("€") { return "EUR" }
        // Si ya parece un código de 3 letras, úsalo; si no, regresa por defecto "PEN"
        let letters = t.filter { $0.isLetter }
        if letters.count == 3 { return String(letters) }
        return "PEN"
    }
    
    private func importCSV(from url: URL) {
        // Acceso temporal (iOS no lo requiere, pero no afecta; en macOS sandbox sí)
        _ = url.startAccessingSecurityScopedResource()
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            // Parser CSV manual con soporte de comillas y separadores ',' o ';'
            let raw: String
            if let s = try? String(contentsOf: url, encoding: .utf8) {
                raw = s
            } else if let s = try? String(contentsOf: url, encoding: .isoLatin1) {
                raw = s
            } else {
                throw NSError(domain: "CSV", code: 2001, userInfo: [NSLocalizedDescriptionKey: "No se pudo leer el archivo como texto (UTF-8 o Latin-1)"])
            }
            
            let lines = raw.components(separatedBy: .newlines)
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            
            guard let header = lines.first else {
                throw NSError(domain: "CSV", code: 2002, userInfo: [NSLocalizedDescriptionKey: "CSV vacío"])
            }
            
            let sep: Character = header.contains(";") ? ";" : ","
            
            func splitCSVLine(_ line: String, by sep: Character) -> [String] {
                var fields: [String] = []
                var current = ""
                var inQuotes = false
                var it = line.makeIterator()
                
                while let ch = it.next() {
                    if ch == "\"" {                // <- OJO: comillas dobles
                        inQuotes.toggle()
                    } else if ch == sep && !inQuotes {
                        fields.append(current)
                        current = ""
                        continue
                    }
                    current.append(ch)
                }
                fields.append(current)
                return fields
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\"")) }
            }
            
            let headers = splitCSVLine(header, by: sep)
                .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            
            func idx(_ name: String) -> Int? { headers.firstIndex(of: name) }
            guard let iDate = idx("date"), let iAmount = idx("amount"), let iCurrency = idx("currency") else {
                throw NSError(
                    domain: "CSV",
                    code: 2003,
                    userInfo: [NSLocalizedDescriptionKey: "Faltan columnas mínimas: date, amount, currency. Detectadas: \(headers)"]
                )
            }
            let iCategory = idx("category")
            let iNote = idx("note")
            
            // Formatos de fecha soportados
            let iso = ISO8601DateFormatter()
            let d1 = DateFormatter(); d1.dateFormat = "dd/MM/yyyy"
            let d2 = DateFormatter(); d2.dateFormat = "yyyy-MM-dd"
            let d3 = DateFormatter(); d3.dateFormat = "MM/dd/yyyy"
            let d4 = DateFormatter(); d4.dateFormat = "dd-MM-yyyy"
            let d5 = DateFormatter(); d5.dateFormat = "yyyy/MM/dd"
            
            var imported = 0
            
            for line in lines.dropFirst() {
                let cols = splitCSVLine(line, by: sep)
                guard cols.count >= headers.count else { continue }
                
                let dateText = cols[iDate]
                let amountText = cols[iAmount]
                let currencyText = normalizeCurrencyCode(cols[iCurrency])
                let categoryText = (iCategory != nil && iCategory! < cols.count) ? cols[iCategory!] : "General"
                let noteText = (iNote != nil && iNote! < cols.count) ? cols[iNote!] : nil
                
                let date = iso.date(from: dateText)
                ?? d1.date(from: dateText)
                ?? d2.date(from: dateText)
                ?? d3.date(from: dateText)
                ?? d4.date(from: dateText)
                ?? d5.date(from: dateText)
                ?? Date()
                
                guard let amount = parseDecimal(from: amountText) else { continue }
                
                // Asegura categoría
                let existing = (try? ctx.fetch(FetchDescriptor<Category>(predicate: #Predicate { $0.name == categoryText })))?.first
                let category = existing ?? {
                    let c = Category(name: categoryText, colorHex: amount >= 0 ? "#2A9D8F" : "#1D3557", isIncome: amount >= 0)
                    ctx.insert(c)
                    return c
                }()
                
                // Inserta transacción
                let item = TransactionItem(
                    date: date,
                    amount: amount,
                    currencyCode: currencyText,
                    note: (noteText?.isEmpty ?? true) ? nil : noteText,
                    category: category
                )
                ctx.insert(item)
                imported += 1
            }
            
            try ctx.save()
            print("Importación CSV (fallback) completada: \(imported) filas.")
        } catch {
            importError = error.localizedDescription
            print("Error importando CSV: \(error)")
        }
    }
    
}

func currencyString(_ amount: Decimal, code: String, locale: Locale = .current) -> String {
    amount.formatted(.currency(code: code).locale(locale))
}
