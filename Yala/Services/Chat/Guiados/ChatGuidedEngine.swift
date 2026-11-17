//
//  ChatGuidedEngine.swift
//  Yala
//
//  El motor de los guiados de Yala IA. Cada flujo se declara como datos (`ChatGuidedFlowSpec`: sus preguntas en orden y
//  cuándo está contestada cada una) y el motor decide lo demás, igual para todos:
//
//  - la siguiente pregunta es la primera sin contestar; si no queda ninguna, la confirmación. Así lo que la persona ya
//    dijo en su frase no se vuelve a preguntar;
//  - «Atrás» vuelve a la pregunta anterior, y «Cambiar» en la confirmación abre esa pregunta y, al contestarla, vuelve;
//  - nada se crea sin pasar por la confirmación (`canCreate`) ni dos veces (`markCreated` solo desde ella).
//
//  Un flujo nuevo (una cuenta, una meta…) es una spec más, sus campos en `ChatGuidedAnswers` y su tarjeta.
//

import Foundation

/// Un flujo guiado como datos.
nonisolated struct ChatGuidedFlowSpec: Sendable {
    let kind: ChatGuidedKind
    /// Las preguntas, en el orden en que se hacen. Sin la confirmación ni el final.
    let steps: [ChatGuidedStep]
    let isAnswered: @Sendable (ChatGuidedStep, ChatGuidedAnswers) -> Bool
}

nonisolated enum ChatGuidedEngine {

    // MARK: - Los flujos

    static func spec(for kind: ChatGuidedKind) -> ChatGuidedFlowSpec {
        switch kind {
        case .budget: budgetSpec
        case .scheduledPayment: scheduledPaymentSpec
        case .account: accountSpec
        case .category: categorySpec
        case .favorite: favoriteSpec
        case .group: groupSpec
        case .groupOpeningBalance: groupOpeningBalanceSpec
        case .groupExpense: groupExpenseSpec
        }
    }

    /// Presupuesto: ¿en qué? → ¿algo que no quieras contar? → ¿cada cuánto? → (fechas) → ¿cuánto? → ¿en qué moneda? →
    /// ¿opciones avanzadas? El nombre se propone solo (se cambia en las avanzadas).
    static let budgetSpec = ChatGuidedFlowSpec(
        kind: .budget,
        steps: [.categories, .subcategories, .period, .dates, .amount, .currency, .advanced,
                .budgetName, .budgetAlerts, .budgetAccounts, .budgetTags, .budgetShared, .budgetPanel],
        isAnswered: { step, answers in
            switch step {
            case .categories:
                guard let all = answers.allExpenses else { return false }
                return all || !answers.categoryIDs.isEmpty
            case .subcategories: return answers.allExpenses == true || answers.removedSubcategoryIDs != nil
            case .period: return answers.period != nil
            case .dates:
                guard answers.period == .once else { return true }
                guard let start = answers.budgetStart, let end = answers.budgetEnd else { return false }
                return end >= start
            case .amount: return isValidAmount(answers.amount)
            case .currency: return answers.currencyCode != nil
            case .advanced: return answers.wantsAdvanced != nil
            default: return isAdvancedAnswered(step, answers)
            }
        }
    )

    /// Pago planificado: ¿es uno de estos cobros? → nombre → monto → cada cuánto → cuándo → cuenta → categoría →
    /// ¿opciones avanzadas?. La moneda sale de la cuenta (o de la frase) y se cambia en la confirmación.
    static let scheduledPaymentSpec = ChatGuidedFlowSpec(
        kind: .scheduledPayment,
        steps: [.suggestion, .name, .amount, .frequency, .when, .account, .subcategory, .currency, .advanced,
                .paymentSubscription, .paymentReminder, .paymentEnd, .paymentNote, .paymentTags, .paymentPanel],
        isAnswered: { step, answers in
            switch step {
            case .suggestion: return answers.suggestionKey != nil
            case .name: return !(answers.paymentName ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            case .amount: return isValidAmount(answers.amount)
            case .frequency: return answers.frequency != nil
            case .when:
                switch answers.frequency {
                case .monthly: return answers.dayOfMonth.map(isValidMonthDay) ?? false
                case .weekly: return answers.weekday.map { (1...7).contains($0) } ?? false
                case .yearly, .once, .daily: return answers.date != nil
                case nil: return false
                }
            case .account: return answers.accountID != nil
            case .subcategory: return answers.subcategoryID != nil
            case .currency: return answers.currencyCode != nil
            case .advanced: return answers.wantsAdvanced != nil
            // Un pago de una sola vez no tiene «hasta cuándo».
            case .paymentEnd: return answers.frequency == .once || isAdvancedAnswered(step, answers)
            default: return isAdvancedAnswered(step, answers)
            }
        }
    )

    /// Cuenta (las preguntas de Primeros pasos): tipo → monedas → nombre → saldo de cada moneda → en tarjeta, cierre,
    /// pago y recordatorio → ¿opciones avanzadas? (últimos números, ¿cuenta en tus reportes?).
    static let accountSpec = ChatGuidedFlowSpec(
        kind: .account,
        steps: [.accountKind, .accountCurrencies, .accountName, .accountBalance, .accountStatementDay,
                .accountPaymentDay, .accountReminder, .advanced, .accountNumber, .accountStats],
        isAnswered: { step, answers in
            if isSkipped(step, answers) { return true }
            switch step {
            case .accountKind: return accountKind(answers) != nil
            case .accountCurrencies: return !(answers.accountCurrencies ?? []).isEmpty
            case .accountName: return !trimmed(answers.accountName).isEmpty
            case .accountBalance:
                guard let balances = answers.accountBalances else { return false }
                return (answers.accountCurrencies ?? []).allSatisfy { balances[$0]?.isFinite == true }
            case .accountStatementDay: return answers.accountStatementDay.map(isDayAnswer) ?? false
            case .accountPaymentDay: return answers.accountPaymentDay.map(isDayAnswer) ?? false
            case .accountReminder: return answers.accountReminderLead != nil
            case .advanced: return answers.wantsAdvanced != nil
            default: return isAdvancedAnswered(step, answers)
            }
        }
    )

    /// Categoría: ¿nueva o dentro de una que ya tienes? → (nueva: nombre, ícono y color | existente: cuál) →
    /// subcategorías → ¿opciones avanzadas? (necesidad de cada una).
    static let categorySpec = ChatGuidedFlowSpec(
        kind: .category,
        steps: [.categoryMode, .categoryParent, .categoryName, .categoryLook, .categorySubcategories, .advanced,
                .categoryNeeds],
        isAnswered: { step, answers in
            if isSkipped(step, answers) { return true }
            switch step {
            case .categoryMode: return answers.categoryMode != nil
            case .categoryParent: return answers.parentCategoryID != nil
            case .categoryName: return !trimmed(answers.categoryName).isEmpty
            case .categoryLook: return answers.categoryIcon != nil && answers.categoryColorHex != nil
            case .categorySubcategories:
                return !(answers.subcategoryNames ?? []).filter { !trimmed($0).isEmpty }.isEmpty
            case .advanced: return answers.wantsAdvanced != nil
            default: return isAdvancedAnswered(step, answers)
            }
        }
    )

    /// Favorito: ¿gasto, ingreso o transferencia? → subcategoría → cuenta (y destino) → monto → nombre → ¿opciones
    /// avanzadas? (necesidad, etiquetas, nota).
    static let favoriteSpec = ChatGuidedFlowSpec(
        kind: .favorite,
        steps: [.favoriteType, .favoriteSubcategory, .favoriteAccount, .favoriteDestination, .favoriteAmount,
                .favoriteName, .advanced, .favoriteNeed, .favoriteTags, .favoriteNote],
        isAnswered: { step, answers in
            if isSkipped(step, answers) { return true }
            switch step {
            case .favoriteType: return favoriteType(answers) != nil
            case .favoriteSubcategory: return answers.subcategoryID != nil
            case .favoriteAccount: return answers.accountID != nil
            case .favoriteDestination:
                guard let destination = answers.destinationAccountID else { return false }
                return destination != answers.accountID
            case .favoriteAmount: return answers.favoriteWithoutAmount == true || isValidAmount(answers.amount)
            case .favoriteName: return !trimmed(answers.favoriteName).isEmpty
            case .advanced: return answers.wantsAdvanced != nil
            default: return isAdvancedAnswered(step, answers)
            }
        }
    )

    /// Grupo: ¿para qué es? → nombre → tu nombre (si Yala no lo sabe) → ¿cómo llevamos las monedas? → moneda (con
    /// «todo en una») → ¿cómo suelen dividir? → ¿opciones avanzadas? (menos pagos). Los miembros se invitan al terminar.
    static let groupSpec = ChatGuidedFlowSpec(
        kind: .group,
        steps: [.groupPurpose, .groupName, .groupYourName, .groupCurrencyMode, .groupCurrency, .groupSplit, .advanced,
                .groupSimplify],
        isAnswered: { step, answers in
            if isSkipped(step, answers) { return true }
            switch step {
            case .groupPurpose: return answers.groupPurpose != nil
            case .groupName: return !trimmed(answers.groupName).isEmpty
            case .groupYourName: return !trimmed(answers.groupDisplayName).isEmpty
            case .groupCurrencyMode: return answers.groupSingleCurrency != nil
            case .groupCurrency: return answers.currencyCode != nil
            case .groupSplit: return answers.groupSplitType.map(groupSplitTypes.contains) ?? false
            case .advanced: return answers.wantsAdvanced != nil
            default: return isAdvancedAnswered(step, answers)
            }
        }
    )

    /// Deuda de antes: grupo → ¿quién debía? → ¿a quién? → ¿cuánto? → moneda (la del grupo; se cambia en la
    /// confirmación) → ¿opciones avanzadas? (desde cuándo).
    static let groupOpeningBalanceSpec = ChatGuidedFlowSpec(
        kind: .groupOpeningBalance,
        steps: [.groupPick, .debtDebtor, .debtCreditor, .debtAmount, .currency, .advanced, .debtDate],
        isAnswered: { step, answers in
            if isSkipped(step, answers) { return true }
            switch step {
            case .groupPick: return !trimmed(answers.groupZoneID).isEmpty
            case .debtDebtor: return !trimmed(answers.debtorMemberID).isEmpty
            case .debtCreditor:
                guard let creditor = answers.creditorMemberID, !creditor.isEmpty else { return false }
                return creditor != answers.debtorMemberID
            case .debtAmount: return isValidAmount(answers.amount)
            case .currency: return answers.currencyCode != nil
            case .advanced: return answers.wantsAdvanced != nil
            default: return isAdvancedAnswered(step, answers)
            }
        }
    )

    /// Gasto de grupo: grupo → ¿qué fue? → ¿cuánto? → ¿Quién pagó? → ¿Cómo lo dividen? → moneda (la del grupo; se cambia
    /// en la confirmación) → cuenta (si pagaste tú y se refleja en tus cuentas) → ¿opciones avanzadas? (categoría,
    /// fecha). La moneda va antes que la cuenta: sin cuenta en esa moneda, «Usar otra moneda» vuelve a preguntarla.
    static let groupExpenseSpec = ChatGuidedFlowSpec(
        kind: .groupExpense,
        steps: [.groupPick, .expenseDescription, .expenseAmount, .expensePayer, .expenseSplit, .currency,
                .expenseAccount, .advanced, .expenseCategory, .expenseDate],
        isAnswered: { step, answers in
            if isSkipped(step, answers) { return true }
            switch step {
            case .groupPick: return !trimmed(answers.groupZoneID).isEmpty
            case .expenseDescription: return !trimmed(answers.expenseDescription).isEmpty
            case .expenseAmount: return isValidAmount(answers.amount)
            case .expensePayer: return !trimmed(answers.payerMemberID).isEmpty
            case .expenseSplit: return isSplitValid(answers)
            case .expenseAccount: return answers.accountID != nil
            case .currency: return answers.currencyCode != nil
            case .advanced: return answers.wantsAdvanced != nil
            default: return isAdvancedAnswered(step, answers)
            }
        }
    )

    /// Un monto redondeado al céntimo.
    static func cents(_ value: Double) -> Double { (value * 100).rounded() / 100 }

    /// Los `SplitType.rawValue` de un grupo (el enum vive con la UI).
    static let groupSplitTypes: Set<String> = ["equal", "percentage", "exact", "shares"]

    /// ¿El reparto está completo? En «solo entre algunos», alguien elegido; en «un monto a cada uno», que las partes
    /// cuadren con el total al céntimo (la misma tolerancia del formulario).
    static func isSplitValid(_ answers: ChatGuidedAnswers) -> Bool {
        switch answers.splitMode {
        case .equalAll: return true
        case .equalSome: return !(answers.participantIDs ?? []).isEmpty
        case .exact:
            guard let total = answers.amount, isValidAmount(total) else { return false }
            let participants = answers.participantIDs ?? []
            let parts = participants.compactMap { answers.exactShares?[$0] }
            guard !participants.isEmpty, parts.count == participants.count,
                  parts.allSatisfy({ $0.isFinite && $0 >= 0 && $0 == cents($0) }) else { return false }
            // Al céntimo, como el formulario: lo que se guarda son partes con dos decimales.
            return abs(parts.reduce(0, +) - cents(total)) < 0.005
        case nil: return false
        }
    }

    /// Lo que no toca con estas respuestas: no se pregunta y cuenta como contestado. Las opciones avanzadas que no
    /// tocan se saltan igual aunque se quisieran revisar.
    static func isSkipped(_ step: ChatGuidedStep, _ answers: ChatGuidedAnswers) -> Bool {
        switch step {
        // Cuenta: los días y el recordatorio son de una tarjeta; sin día de pago no hay qué recordar; el efectivo y
        // «todo junto» no tienen número.
        case .accountStatementDay, .accountPaymentDay: return accountKind(answers)?.isCard != true
        case .accountReminder: return accountKind(answers)?.isCard != true || answers.accountPaymentDay == 0
        case .accountNumber:
            guard let kind = accountKind(answers) else { return false }
            return kind == .cash || kind == .general
        // Categoría: la existente no tiene nombre ni ícono propios; la nueva no tiene «en cuál».
        case .categoryParent: return answers.categoryMode != .subcategories
        case .categoryName, .categoryLook: return answers.categoryMode != .newCategory
        // Favorito: una transferencia no lleva categoría, necesidad ni etiquetas, y solo ella lleva destino.
        case .favoriteSubcategory, .favoriteTags: return favoriteType(answers) == .transfer
        case .favoriteDestination: return favoriteType(answers) != .transfer
        case .favoriteNeed: return favoriteType(answers) != .expense
        // Grupos: el grupo no se pregunta con uno solo, ni tu nombre si Yala ya lo sabe, ni la moneda con «cada gasto
        // en su moneda». La cuenta del gasto solo si la pide el formulario (`expenseAccountRequired`, que pone la
        // tarjeta al contestar quién pagó).
        case .groupPick, .groupYourName, .groupCurrencyMode: return answers.isNotApplicable(step)
        case .groupCurrency: return answers.groupSingleCurrency != true
        case .expenseAccount: return answers.expenseAccountRequired != true
        default: return false
        }
    }

    static func accountKind(_ answers: ChatGuidedAnswers) -> FirstAccountFlowLogic.Kind? {
        answers.accountKind.flatMap(FirstAccountFlowLogic.Kind.init(rawValue:))
    }

    /// El tipo del favorito.
    static func favoriteType(_ answers: ChatGuidedAnswers) -> ChatGuidedFavoriteType? {
        answers.favoriteType.flatMap(ChatGuidedFavoriteType.init(rawValue:))
    }

    /// 1…31, o 0 = «No lo sé».
    static func isDayAnswer(_ day: Int) -> Bool { day == 0 || isValidMonthDay(day) }

    static func trimmed(_ text: String?) -> String {
        (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Una opción avanzada está contestada si no se quisieron revisar, si ya se contestó o saltó, o si no toca.
    static func isAdvancedAnswered(_ step: ChatGuidedStep, _ answers: ChatGuidedAnswers) -> Bool {
        guard step.isAdvancedOption else { return true }
        return answers.wantsAdvanced == false || answers.isDone(step) || answers.isNotApplicable(step)
    }

    /// Las preguntas que de verdad se le hacen a esta persona: las avanzadas solo con «Sí», y nunca las que no tocan.
    static func askedSteps(_ kind: ChatGuidedKind, answers: ChatGuidedAnswers) -> [ChatGuidedStep] {
        spec(for: kind).steps.filter { step in
            if step.isAdvancedOption {
                return answers.wantsAdvanced == true && !answers.isNotApplicable(step)
                    && !(step == .paymentEnd && answers.frequency == .once) && !isSkipped(step, answers)
            }
            if isSkipped(step, answers) { return false }
            switch step {
            case .subcategories: return answers.allExpenses != true
            case .dates: return answers.period == .once
            default: return true
            }
        }
    }

    // MARK: - Reglas sueltas

    static func isValidAmount(_ amount: Double?) -> Bool {
        guard let amount else { return false }
        return amount.isFinite && amount > 0
    }

    static func isValidMonthDay(_ day: Int) -> Bool {
        (1...31).contains(day)
    }

    // MARK: - El recorrido

    /// La primera pregunta sin contestar, o la confirmación.
    static func firstPending(_ kind: ChatGuidedKind, answers: ChatGuidedAnswers) -> ChatGuidedStep {
        let spec = spec(for: kind)
        return spec.steps.first { !spec.isAnswered($0, answers) } ?? .confirm
    }

    /// Empieza un guiado con lo que ya se sabe: va directo a lo que falta.
    static func start(
        _ kind: ChatGuidedKind,
        answers: ChatGuidedAnswers,
        prefilled: Set<ChatGuidedField> = [],
        id: UUID = UUID()
    ) -> ChatGuidedFlowState {
        ChatGuidedFlowState(id: id, kind: kind, step: firstPending(kind, answers: answers), answers: answers,
                            prefilled: prefilled)
    }

    /// Tras contestar la pregunta de ahora (las respuestas ya escritas en `answers`): la siguiente pendiente. Contestar
    /// algo que la persona dijo en su frase quita la marca «lo dijiste tú». Una opción avanzada contestada o saltada
    /// («Saltar» contesta sin cambiar nada) queda hecha.
    static func answer(
        _ state: ChatGuidedFlowState,
        with answers: ChatGuidedAnswers,
        clearing fields: Set<ChatGuidedField> = []
    ) -> ChatGuidedFlowState {
        guard state.status == .inProgress, state.step != .confirm, state.step != .done else { return state }
        // Una opción avanzada solo se contesta si se quisieron revisar: si no, el valor de siempre no se toca.
        if state.step.isAdvancedOption, state.answers.wantsAdvanced != true { return state }
        var next = state
        var answers = answers
        if state.step.isAdvancedOption, !answers.isDone(state.step) {
            answers.advancedDone = (answers.advancedDone ?? []) + [state.step]
        }
        next.answers = answers
        next.prefilled.subtract(fields)
        next.history.append(state.step)
        next.step = firstPending(state.kind, answers: answers)
        if next.step == .confirm { next.returnsToConfirm = false }
        return next
    }

    /// «Atrás»: la pregunta anterior. En la primera no hace nada (el guiado se cancela con su botón).
    static func back(_ state: ChatGuidedFlowState) -> ChatGuidedFlowState {
        guard state.status == .inProgress, !state.history.isEmpty else { return state }
        var next = state
        // Lo que ya no se pregunta (una opción avanzada tras «No», las fechas tras cambiar el período) se salta.
        let asked = Set(askedSteps(state.kind, answers: state.answers))
        var previous = next.history.removeLast()
        while previous != .confirm, !asked.contains(previous), let earlier = next.history.popLast() {
            previous = earlier
        }
        guard previous == .confirm || asked.contains(previous) else { return state }
        next.step = previous
        if previous == .confirm { next.returnsToConfirm = false }
        return next
    }

    /// «Cambiar» desde la confirmación: abre esa pregunta; al contestarla se vuelve a la confirmación (o a lo que
    /// quede por contestar, si el cambio deja otra pregunta pendiente).
    static func edit(_ state: ChatGuidedFlowState, step: ChatGuidedStep) -> ChatGuidedFlowState {
        guard state.status == .inProgress, state.step == .confirm,
              spec(for: state.kind).steps.contains(step) else { return state }
        var next = state
        next.history.append(.confirm)
        next.step = step
        next.returnsToConfirm = true
        return next
    }

    /// ¿Se puede crear? Solo desde la confirmación y con todo contestado.
    static func canCreate(_ state: ChatGuidedFlowState) -> Bool {
        state.status == .inProgress && state.step == .confirm
            && firstPending(state.kind, answers: state.answers) == .confirm
    }

    /// Lo guardado: el guiado termina en su tarjeta de éxito. Solo desde una confirmación válida.
    static func markCreated(
        _ state: ChatGuidedFlowState,
        id: UUID,
        name: String,
        dueDate: Date? = nil,
        zoneID: String? = nil
    ) -> ChatGuidedFlowState {
        guard canCreate(state) else { return state }
        var next = state
        next.createdZoneID = zoneID
        next.status = .created
        next.step = .done
        next.history = []
        next.createdID = id
        next.createdName = name
        next.createdDueDate = dueDate
        return next
    }

    /// «¿Quieres revisar las opciones avanzadas?». «Sí» las pregunta todas otra vez (con lo ya elegido marcado); «No»
    /// las devuelve a los valores de siempre.
    static func answerAdvanced(_ state: ChatGuidedFlowState, wants: Bool) -> ChatGuidedFlowState {
        guard state.step == .advanced else { return state }
        var answers = state.answers
        answers.wantsAdvanced = wants
        if wants { answers.advancedDone = [] } else { answers.resetAdvancedOptions() }
        return answer(state, with: answers)
    }

    static func cancel(_ state: ChatGuidedFlowState) -> ChatGuidedFlowState {
        guard state.status == .inProgress else { return state }
        var next = state
        next.status = .cancelled
        next.history = []
        return next
    }

    // MARK: - Progreso

    /// Cuántas preguntas tiene el flujo y cuántas están contestadas, para los puntos de la cabecera. Solo cuentan las
    /// que se le hacen a esta persona.
    static func progress(_ state: ChatGuidedFlowState) -> (answered: Int, total: Int) {
        let spec = spec(for: state.kind)
        let asked = askedSteps(state.kind, answers: state.answers)
        let answered = asked.filter { spec.isAnswered($0, state.answers) }.count
        return (answered, asked.count)
    }
}
