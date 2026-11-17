//
//  ChatGuidedGroupLogicTests.swift
//  YalaTests
//
//  Guiados de Grupos (encargo del 17-nov), sin almacén: qué frase abre cada uno y cuál sigue siendo un registro, lo que
//  la frase ya dice («pagué 120 de la cena con Ana y Luis»), qué preguntas se saltan y lo que se manda al crear un grupo.
//

import Foundation
import Testing

@testable import Yala

@MainActor
@Suite("Yala IA · guiados de Grupos: frases, preguntas y lo que se manda", .serialized)
struct ChatGuidedGroupLogicTests {

    // MARK: - Fixture

    private static let me = ChatGuidedGroupOption.Member(id: "me", name: "Jürgen", isMe: true)
    private static let ana = ChatGuidedGroupOption.Member(id: "ana", name: "Ana", isMe: false)
    private static let luis = ChatGuidedGroupOption.Member(id: "luis", name: "Luis Pérez", isMe: false)
    private static let sofia = ChatGuidedGroupOption.Member(id: "sofia", name: "Sofía", isMe: false)
    private static let rosa = ChatGuidedGroupOption.Member(id: "rosa", name: "Rosa", isMe: false)

    private static func group(_ id: String, _ name: String, _ members: [ChatGuidedGroupOption.Member],
                              admin: Bool = true, currency: String = "PEN") -> ChatGuidedGroupOption {
        ChatGuidedGroupOption(id: id, name: name, iconName: "airplane", colorHex: "#0EA5E9", currencyCode: currency,
                              members: members, canAddExpense: true,
                              canManageOpeningBalances: admin && members.count >= 2)
    }

    /// Dos grupos: el viaje (tú, Ana, Luis y Sofía) y la casa (tú y Rosa).
    private static let trip = group("SplitGroup-trip", "Viaje a Cusco", [me, ana, luis, sofia])
    private static let home = group("SplitGroup-home", "Depa", [me, rosa], currency: "USD")

    private var catalog: ChatGuidedCatalog {
        var catalog = ChatGuidedCatalog(mainCurrency: "PEN", accountCurrencies: ["PEN", "USD"])
        catalog.groups = [Self.trip, Self.home]
        return catalog
    }

    // MARK: - ¿Qué frase abre qué?

    @Test(arguments: [
        ("Crea un grupo para el viaje a Cusco", ChatGuidedKind.group),
        ("quiero un nuevo grupo", .group),
        ("armemos un grupo con mis amigos", .group),
        ("create a group for our trip", .group),
        ("Luis me debía 50 de antes", .groupOpeningBalance),
        ("anota una deuda de antes", .groupOpeningBalance),
        ("le debo 30 a Ana desde antes de Yala", .groupOpeningBalance),
        ("Ana owes me 40 from before", .groupOpeningBalance),
        ("gasto de grupo de 80 por el taxi", .groupExpense),
        ("divide 90 del taxi entre Ana y yo", .groupExpense),
        ("anota 45 en el grupo del viaje", .groupExpense),
        ("split 60 with Ana", .groupExpense),
    ])
    func phrasesThatAskForAGroupFlow_openIt(_ phrase: String, _ kind: ChatGuidedKind) {
        #expect(ChatGuidedIntentDetector.kind(of: phrase) == kind, "«\(phrase)» debía abrir \(kind).")
    }

    /// Lo que se registra, se pregunta o es otro guiado sigue su camino.
    @Test(arguments: [
        "pagué 120 de la cena",
        "¿cuánto me debe Luis?",
        "agrega 20 soles a la cuenta BCP",
        "agrega un gasto de 50 al súper",
        "muéstrame mis grupos",
        "gasto de grupo",
    ])
    func phrasesThatAreNotAGroupFlow_staySilent(_ phrase: String) {
        #expect(ChatGuidedIntentDetector.kind(of: phrase) == nil, "«\(phrase)» no debía abrir un guiado de Grupos.")
    }

    @Test("Una cuenta o un presupuesto siguen ganando a la palabra «grupo»")
    func otherCreateFlowsKeepTheirPhrases() {
        #expect(ChatGuidedIntentDetector.kind(of: "crea una cuenta para el grupo") == .account)
        #expect(ChatGuidedIntentDetector.kind(of: "quiero un presupuesto para el grupo") == .budget)
    }

    // MARK: - Un gasto de grupo por las personas nombradas

    @Test("«pagué 120 de la cena con Ana y Luis» es un gasto de grupo: Ana y Luis son de tus grupos")
    func namedPeople_openTheExpense() {
        let phrase = "pagué 120 de la cena con Ana y Luis"
        #expect(ChatGuidedIntentDetector.kind(of: phrase) == nil, "Sin catálogo no se sabe: lo decide la gente nombrada.")
        #expect(ChatGuidedIntentDetector.groupExpenseByPeople(phrase, catalog: catalog))
        #expect(ChatGuidedIntentDetector.detect(phrase, catalog: catalog)?.kind == .groupExpense)
    }

    @Test(arguments: [
        "pagué 120 de la cena con mi mamá",
        "Ana me pasó 50",
        "almorcé con Ana",
        "¿cuánto gasté con Ana?",
    ])
    func peopleOutsideYourGroupsOrWithoutAmount_stayARecord(_ phrase: String) {
        #expect(!ChatGuidedIntentDetector.groupExpenseByPeople(phrase, catalog: catalog), "«\(phrase)»")
    }

    @Test("Lo que la frase dice: grupo por sus personas, qué fue, cuánto, quién pagó y entre quiénes")
    func expenseSentence_fillsEverythingItSays() throws {
        let detection = try #require(ChatGuidedIntentDetector.detect("pagué 120 de la cena con Ana y Luis", catalog: catalog))
        let answers = detection.answers
        #expect(answers.groupZoneID == Self.trip.id)
        #expect(answers.amount == 120)
        #expect(answers.expenseDescription == "Cena")
        #expect(answers.payerMemberID == "me")
        #expect(answers.splitMode == .equalSome)
        #expect(answers.participantIDs == ["me", "ana", "luis"], "Tú, Ana y Luis; Sofía no fue.")
        #expect(detection.prefilled.isSuperset(of: [.group, .amount, .description, .payer, .participants]))
    }

    @Test("Con todo el grupo nombrado, el reparto es entre todos")
    func everyoneNamed_isEqualAll() throws {
        let detection = try #require(ChatGuidedIntentDetector.detect("pagué 60 del taxi con Rosa", catalog: catalog))
        #expect(detection.answers.groupZoneID == Self.home.id)
        #expect(detection.answers.splitMode == .equalAll)
        #expect(detection.answers.participantIDs == nil)
    }

    @Test("«pagó Ana» deja a Ana como quien pagó")
    func otherPayer() throws {
        let detection = try #require(ChatGuidedIntentDetector.detect("Ana pagó 90 del taxi, divídelo entre Ana y yo",
                                                                     catalog: catalog))
        #expect(detection.answers.payerMemberID == "ana")
    }

    @Test("«Anota un gasto de grupo de 60»: la palabra «gasto» no es lo que fue, se pregunta")
    func expenseWord_isNotTheDescription() throws {
        let detection = try #require(ChatGuidedIntentDetector.detect("Anota un gasto de grupo de 60", catalog: catalog))
        #expect(detection.kind == .groupExpense)
        #expect(detection.answers.expenseDescription == nil)
        #expect(detection.answers.amount == 60)
        #expect(ChatGuidedIntentDetector.expenseDescription("la cena de 120", groupName: nil) == "Cena")
    }

    @Test("El nombre del grupo en la frase lo elige")
    func groupByItsName() throws {
        let detection = try #require(ChatGuidedIntentDetector.detect("anota 45 de pizza en el grupo Depa", catalog: catalog))
        #expect(detection.kind == .groupExpense)
        #expect(detection.answers.groupZoneID == Self.home.id)
        #expect(detection.answers.expenseDescription == "Pizza")
    }

    // MARK: - Deuda de antes

    @Test("«Luis me debía 50 de antes»: debe Luis, a ti")
    func debtOwedToMe() throws {
        let detection = try #require(ChatGuidedIntentDetector.detect("Luis me debía 50 de antes", catalog: catalog))
        #expect(detection.kind == .groupOpeningBalance)
        #expect(detection.answers.groupZoneID == Self.trip.id)
        #expect(detection.answers.debtorMemberID == "luis")
        #expect(detection.answers.creditorMemberID == "me")
        #expect(detection.answers.amount == 50)
    }

    @Test("«le debo 30 a Ana de antes»: debes tú, a Ana")
    func debtIOwe() throws {
        let detection = try #require(ChatGuidedIntentDetector.detect("le debo 30 a Ana de antes", catalog: catalog))
        #expect(detection.answers.debtorMemberID == "me")
        #expect(detection.answers.creditorMemberID == "ana")
    }

    @Test("«Ana le debía 20 a Luis de antes»: entre otras dos personas")
    func debtBetweenOthers() throws {
        let detection = try #require(ChatGuidedIntentDetector.detect("Ana le debía 20 a Luis de antes", catalog: catalog))
        #expect(detection.answers.debtorMemberID == "ana")
        #expect(detection.answers.creditorMemberID == "luis")
    }

    @Test("«A Luis le debo 50 de antes»: el verbo en primera persona manda, debes tú (revisión)")
    func debtFirstPersonWithTheNameFirst() throws {
        let detection = try #require(ChatGuidedIntentDetector.detect("A Luis le debo 50 de antes", catalog: catalog))
        #expect(detection.answers.debtorMemberID == "me")
        #expect(detection.answers.creditorMemberID == "luis")
    }

    @Test("«Ana pagó 90 del taxi con Luis»: tú no entras si no pagaste ni te nombran (revisión)")
    func otherPayerWithCompany_doesNotAddMe() throws {
        let detection = try #require(ChatGuidedIntentDetector.detect("Ana pagó 90 del taxi con Luis", catalog: catalog))
        #expect(detection.answers.payerMemberID == "ana")
        #expect(detection.answers.participantIDs == ["ana", "luis"])
        let withMe = try #require(ChatGuidedIntentDetector.detect("Ana pagó 90 del taxi con Luis y conmigo", catalog: catalog))
        #expect(withMe.answers.participantIDs == ["me", "ana", "luis"])
    }

    // MARK: - Crear un grupo

    @Test("«Crea un grupo para el viaje a Cusco»: nombre y para qué es")
    func createGroupSentence() throws {
        let detection = try #require(ChatGuidedIntentDetector.detect("Crea un grupo para el viaje a Cusco", catalog: catalog))
        #expect(detection.answers.groupName == "Viaje a Cusco")
        #expect(detection.answers.groupPurpose == .trip)
        #expect(detection.prefilled.contains(.name))
    }

    @Test("Con una moneda nombrada, el grupo va todo en esa moneda")
    func createGroupWithCurrency() throws {
        let detection = try #require(ChatGuidedIntentDetector.detect("crea un grupo en dólares", catalog: catalog))
        #expect(detection.answers.groupSingleCurrency == true)
        #expect(detection.answers.currencyCode == "USD")
    }

    // MARK: - Lo que ya se sabe antes de preguntar

    @Test("Crear un grupo: tu nombre del perfil y, con una sola moneda en Yala, «cada gasto en su moneda»")
    func groupStart_skipsWhatYalaKnows() {
        let oneCurrency = ChatGuidedCatalog(mainCurrency: "PEN", accountCurrencies: ["PEN"])
        let start = ChatGuidedDataSource.prepareGroupStart(
            ChatGuidedDetection(kind: .group, answers: ChatGuidedAnswers(), prefilled: []),
            catalog: oneCurrency, profileName: "Jürgen")
        #expect(start.answers.groupDisplayName == "Jürgen")
        #expect(start.answers.isNotApplicable(.groupYourName))
        #expect(start.answers.groupSingleCurrency == false)
        let asked = ChatGuidedEngine.askedSteps(.group, answers: start.answers)
        #expect(asked == [.groupPurpose, .groupName, .groupSplit, .advanced])
    }

    @Test("Crear un grupo sin nombre en el perfil y con dos monedas: pregunta tu nombre y las monedas")
    func groupStart_asksWhatItDoesNotKnow() {
        let start = ChatGuidedDataSource.prepareGroupStart(
            ChatGuidedDetection(kind: .group, answers: ChatGuidedAnswers(), prefilled: []),
            catalog: catalog, profileName: "  ")
        let asked = ChatGuidedEngine.askedSteps(.group, answers: start.answers)
        #expect(asked == [.groupPurpose, .groupName, .groupYourName, .groupCurrencyMode, .groupSplit, .advanced])
        var single = start.answers
        single.groupSingleCurrency = true
        #expect(ChatGuidedEngine.askedSteps(.group, answers: single).contains(.groupCurrency),
                "Con «todo en una moneda», se pregunta cuál.")
    }

    @Test("Deuda o gasto con un solo grupo donde cabe: ese grupo, sin preguntarlo, con su moneda")
    func onlyOneGroup_isNotAsked() {
        var oneGroup = catalog
        oneGroup.groups = [Self.home]
        let start = ChatGuidedDataSource.prepareGroupStart(
            ChatGuidedDetection(kind: .groupExpense, answers: ChatGuidedAnswers(), prefilled: []),
            catalog: oneGroup, profileName: nil)
        #expect(start.answers.groupZoneID == Self.home.id)
        #expect(start.answers.currencyCode == "USD")
        #expect(!ChatGuidedEngine.askedSteps(.groupExpense, answers: start.answers).contains(.groupPick))
    }

    @Test("En un grupo de dos, quien no debe es la otra persona")
    func twoPersonDebt_fillsTheCreditor() {
        var answers = ChatGuidedAnswers()
        answers.debtorMemberID = "rosa"
        let completed = ChatGuidedDataSource.completeTwoPersonDebt(answers, group: Self.home)
        #expect(completed.creditorMemberID == "me")
        let notTwo = ChatGuidedDataSource.completeTwoPersonDebt(answers, group: Self.trip)
        #expect(notTwo.creditorMemberID == nil)
    }

    @Test("Sin grupo donde anotar, Yala IA lo dice y no abre la tarjeta")
    func blocks() {
        let noAdmin = Self.group("SplitGroup-x", "X", [Self.me, Self.ana], admin: false)
        #expect(ChatGuidedDataSource.groupBlock(.groupOpeningBalance, groups: [noAdmin], route: .backend)
                == .noGroupForOpeningBalance)
        #expect(ChatGuidedDataSource.groupBlock(.groupExpense, groups: [], route: .backend) == .noGroupForExpense)
        #expect(ChatGuidedDataSource.groupBlock(.groupExpense, groups: [noAdmin], route: .needsSignIn) == nil)
        #expect(ChatGuidedDataSource.groupBlock(.group, groups: [], route: .needsConsent) == .needsGroupsAccount)
        #expect(ChatGuidedDataSource.groupBlock(.group, groups: [], route: .channelOff) == .channelOff)
        #expect(ChatGuidedDataSource.groupBlock(.group, groups: [], route: .backend) == nil)
    }

    // MARK: - El motor

    @Test("¿Cómo lo dividen?: un monto a cada uno tiene que cuadrar con el total, al céntimo")
    func exactSplitMustAddUp() {
        var answers = ChatGuidedAnswers()
        answers.amount = 100
        answers.splitMode = .exact
        answers.participantIDs = ["me", "ana"]
        answers.exactShares = ["me": 60, "ana": 39.99]
        #expect(!ChatGuidedEngine.isSplitValid(answers))
        answers.exactShares = ["me": 60, "ana": 40]
        #expect(ChatGuidedEngine.isSplitValid(answers))
        answers.exactShares = ["me": 100]
        #expect(!ChatGuidedEngine.isSplitValid(answers), "Cada elegido necesita su monto.")
        answers.splitMode = .equalSome
        answers.participantIDs = []
        #expect(!ChatGuidedEngine.isSplitValid(answers), "«Solo entre algunos» sin nadie no vale.")
        // Más de dos decimales no se guardan: el formulario los redondearía y no cuadraría (revisión).
        answers.splitMode = .exact
        answers.participantIDs = ["me", "ana", "luis"]
        answers.exactShares = ["me": 33.333, "ana": 33.333, "luis": 33.334]
        #expect(!ChatGuidedEngine.isSplitValid(answers))
    }

    @Test("Sin cuenta en la moneda del gasto, «Usar otra moneda» vuelve a preguntarla antes que la cuenta (revisión)")
    func currencyIsAskedBeforeTheAccount() {
        var answers = ChatGuidedAnswers()
        answers.groupZoneID = Self.trip.id
        answers.expenseDescription = "Taxi"
        answers.amount = 30
        answers.payerMemberID = "me"
        answers.splitMode = .equalAll
        answers.expenseAccountRequired = true
        answers.currencyCode = "USD"
        #expect(ChatGuidedEngine.firstPending(.groupExpense, answers: answers) == .expenseAccount)
        answers.currencyCode = nil
        #expect(ChatGuidedEngine.firstPending(.groupExpense, answers: answers) == .currency)
    }

    @Test("La cuenta del gasto solo se pregunta cuando el formulario la pediría")
    func expenseAccount_onlyWhenRequired() {
        var answers = ChatGuidedAnswers()
        answers.groupZoneID = Self.trip.id
        answers.expenseAccountRequired = false
        #expect(!ChatGuidedEngine.askedSteps(.groupExpense, answers: answers).contains(.expenseAccount))
        answers.expenseAccountRequired = true
        #expect(ChatGuidedEngine.askedSteps(.groupExpense, answers: answers).contains(.expenseAccount))
    }

    @Test("Un gasto completo va directo a «Revisa antes de crear», y la moneda se puede cambiar allí")
    func fullExpense_goesToConfirm() throws {
        let detection = try #require(ChatGuidedIntentDetector.detect("pagué 120 de la cena con Ana y Luis", catalog: catalog))
        var prepared = ChatGuidedDataSource.prepareGroupStart(detection, catalog: catalog, profileName: nil)
        prepared.answers.expenseAccountRequired = false
        prepared.answers.wantsAdvanced = false
        var state = ChatGuidedEngine.start(.groupExpense, answers: prepared.answers, prefilled: prepared.prefilled)
        #expect(state.step == .confirm)
        state = ChatGuidedEngine.edit(state, step: .currency)
        #expect(state.step == .currency)
    }

    // MARK: - Lo que se manda al crear un grupo

    @Test("El grupo nuevo: ícono y color por para qué es, tu nombre, la moneda elegida y menos pagos por defecto")
    func groupRequest() throws {
        var answers = ChatGuidedAnswers()
        answers.groupPurpose = .couple
        answers.groupName = " Nosotros "
        answers.groupSingleCurrency = true
        answers.currencyCode = "usd"
        answers.groupSplitType = "percentage"
        let request = try ChatGuidedCreator.groupRequest(answers, preferredCurrency: "PEN", profileName: "Jürgen")
        #expect(request.name == "Nosotros")
        #expect(request.iconName == ChatGuidedGroupPurpose.couple.iconName)
        #expect(request.colorHex == ChatGuidedGroupPurpose.couple.colorHex)
        #expect(request.currencyCode == "USD")
        #expect(request.showDebtsInSingleCurrency)
        #expect(request.displayName == "Jürgen")
        #expect(request.defaultSplitType == "percentage")
        #expect(request.simplifyDebts == GroupFormDefaults.simplifyDebtsForNewGroup)
    }

    @Test("Con «cada gasto en su moneda», el grupo lleva tu moneda principal; tu nombre dicho gana al del perfil")
    func groupRequest_eachCurrency() throws {
        var answers = ChatGuidedAnswers()
        answers.groupPurpose = .trip
        answers.groupName = "Viaje"
        answers.groupSingleCurrency = false
        answers.currencyCode = "EUR"
        answers.groupDisplayName = "Jur"
        answers.groupSimplifyDebts = false
        let request = try ChatGuidedCreator.groupRequest(answers, preferredCurrency: "pen", profileName: "Jürgen")
        #expect(request.currencyCode == "PEN")
        #expect(!request.showDebtsInSingleCurrency)
        #expect(request.displayName == "Jur")
        #expect(!request.simplifyDebts)
        #expect(request.defaultSplitType == "equal")
    }

    @Test("Sin la cuenta de Yala no se crea nada: sale el texto de Grupos")
    func createGroup_withoutAccount_saysSo() async {
        var answers = ChatGuidedAnswers()
        answers.groupPurpose = .trip
        answers.groupName = "Viaje"
        var called = false
        do {
            _ = try await ChatGuidedCreator.createGroup(
                answers, context: try makeTestContext(), preferredCurrency: "PEN", profileName: nil,
                route: .needsSignIn, create: { _ in
                    called = true
                    return SplitGroup(name: "x", currencyCode: "PEN", isOwner: true)
                })
            Issue.record("Sin cuenta no debía crearse.")
        } catch ChatGuidedCreationError.message(let text) {
            #expect(text == L10n.IAGuiados.groupNeedsAccount)
        } catch {
            Issue.record("Error inesperado: \(error)")
        }
        #expect(!called)
    }
}
