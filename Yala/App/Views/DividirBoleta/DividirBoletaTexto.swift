//
//  DividirBoletaTexto.swift
//  Yala
//
//  Los textos de «Dividir una boleta» (`dividirBoleta.*` en `DividirBoleta.strings`, los 16 idiomas), leídos con el
//  idioma de la app (variante → padre → main → la clave), como `L10n.ImportarLote1`.
//

import Foundation

extension L10n {
    enum DividirBoleta {
        static let tabla = "DividirBoleta"

        static func string(_ key: String, resolution: LocaleResolution = LanguageManager.resolved) -> String {
            let sentinel = "__YALA_MISSING__"
            var value = resolution.bundle.localizedString(forKey: key, value: sentinel, table: tabla)
            if value == sentinel, let parent = resolution.parentBundle {
                value = parent.localizedString(forKey: key, value: sentinel, table: tabla)
            }
            if value == sentinel {
                value = Bundle.main.localizedString(forKey: key, value: sentinel, table: tabla)
            }
            return value == sentinel ? key : value
        }

        private static func s(_ key: String) -> String { string("dividirBoleta.\(key)") }

        private static func f(_ key: String, _ args: CVarArg...) -> String {
            String(format: s(key), locale: LanguageManager.resolved.locale, arguments: args)
        }

        /// «Dividir una boleta»
        static var entryTitle: String { s("entry.title") }
        /// «Reparte con quien sea, aunque no use Yala. Registras solo tu parte.»
        static var entryHint: String { s("entry.hint") }
        /// «Sin crear un grupo, con quien sea.»
        static var entryHintGroups: String { s("entry.hintGroups") }
        /// «Toma una foto de la boleta o elígela de tus fotos o archivos.»
        static var sourceSubtitle: String { s("source.subtitle") }
        /// «Foto de la boleta»
        static var whoPhoto: String { s("who.photo") }
        /// «Yala la lee al tocar Repartir»
        static var whoPhotoPending: String { s("who.photoPending") }
        /// «Esto leí ✓»
        static var whoPhotoRead: String { s("who.photoRead") }
        /// «Total %@»
        static func whoPhotoReadDetail(_ a0: String) -> String { f("who.photoReadDetail", a0) }
        /// «Otra foto»
        static var whoOtherPhoto: String { s("who.otherPhoto") }
        /// «¿Entre quiénes?»
        static var whoPeopleSection: String { s("who.peopleSection") }
        /// «Yo»
        static var whoMe: String { s("who.me") }
        /// «Escribe un nombre…»
        static var whoNamePlaceholder: String { s("who.namePlaceholder") }
        /// «Añadir»
        static var whoAdd: String { s("who.add") }
        /// «Quitar a %@»
        static func whoRemove(_ a0: String) -> String { f("who.remove", a0) }
        /// «Tú siempre estás. Los demás no necesitan Yala.»
        static var whoPeopleFooter: String { s("who.peopleFooter") }
        /// «Ya hay alguien con ese nombre.»
        static var whoDuplicateName: String { s("who.duplicateName") }
        /// «¿Cómo lo dividimos?»
        static var whoModeSection: String { s("who.modeSection") }
        /// «Por igual»
        static var modeEqual: String { s("mode.equal") }
        /// «Por líneas»
        static var modeByLines: String { s("mode.byLines") }
        /// «¿Quién comió qué? · opcional»
        static var whoPhraseSection: String { s("who.phraseSection") }
        /// «Yo el ceviche, Carla el ají y la chicha entre todos»
        static var whoPhrasePlaceholder: String { s("who.phrasePlaceholder") }
        /// «Si no lo dices, eliges en la revisión quién comió cada línea.»
        static var whoPhraseFooter: String { s("who.phraseFooter") }
        /// «Repartir»
        static var whoSplit: String { s("who.split") }
        /// «Añade al menos a una persona más.»
        static var whoNeedsPeople: String { s("who.needsPeople") }
        /// «Escribe el total de la boleta»
        static var manualTitle: String { s("manual.title") }
        /// «Lo repartimos por igual entre todos.»
        static var manualFooter: String { s("manual.footer") }
        /// «Total de la boleta»
        static var manualLineName: String { s("manual.lineName") }
        /// «Revisa el reparto»
        static var reviewTitle: String { s("review.title") }
        /// «Lo que se pidió»
        static var reviewLinesSection: String { s("review.linesSection") }
        /// «Toca una línea para elegir quién la comió.»
        static var reviewLinesFooterByLines: String { s("review.linesFooterByLines") }
        /// «Por igual: todo se reparte entre todos.»
        static var reviewLinesFooterEqual: String { s("review.linesFooterEqual") }
        /// «Ver cuánto le toca a cada uno»
        static var reviewContinue: String { s("review.continue") }
        /// «Reparto»
        static var resultTitle: String { s("result.title") }
        /// «Listo»
        static var resultDone: String { s("result.done") }
        /// «Te deben»
        static var resultOwedToYou: String { s("result.owedToYou") }
        /// «%@ te debe»
        static func resultOneOwesYou(_ a0: String) -> String { f("result.oneOwesYou", a0) }
        /// «Le debes a %@»
        static func resultYouOwe(_ a0: String) -> String { f("result.youOwe", a0) }
        /// «Nadie le debe nada a quien pagó»
        static var resultNobodyOwes: String { s("result.nobodyOwes") }
        /// «%1$@ · total %2$@»
        static func resultSubtitle(_ a0: String, _ a1: String) -> String { f("result.subtitle", a0, a1) }
        /// «Boleta»
        static var resultMerchantFallback: String { s("result.merchantFallback") }
        /// «¿Quién pagó?»
        static var resultPaidBy: String { s("result.paidBy") }
        /// «Tu parte»
        static var resultYourPart: String { s("result.yourPart") }
        /// «Pagó»
        static var resultPaidLabel: String { s("result.paidLabel") }
        /// «Tu parte se registra como un gasto tuyo. Lo de los demás no entra en tus registros.»
        static var resultFooterPaidByMe: String { s("result.footerPaidByMe") }
        /// «Lo que le debes a %@ es tu gasto. Si lo registras ahora, no lo registres otra vez cuando le pagues.»
        static func resultFooterPaidByOther(_ a0: String) -> String { f("result.footerPaidByOther", a0) }
        /// «Aquí no se registra nada: ves el reparto y lo compartes.»
        static var resultFooterGroupsOnly: String { s("result.footerGroupsOnly") }
        /// «Imagen para compartir»
        static var imageSection: String { s("image.section") }
        /// «Qué incluye»
        static var imageKindLabel: String { s("image.kindLabel") }
        /// «Solo resumen»
        static var imageSummary: String { s("image.summary") }
        /// «Con detalle»
        static var imageDetailed: String { s("image.detailed") }
        /// «Diseño»
        static var imageStyleLabel: String { s("image.styleLabel") }
        /// «Clara»
        static var imageStyleLight: String { s("image.styleLight") }
        /// «Yala»
        static var imageStyleBrand: String { s("image.styleBrand") }
        /// «Boleta»
        static var imageStyleReceipt: String { s("image.styleReceipt") }
        /// «Compartir imagen»
        static var imageShare: String { s("image.share") }
        /// «Vista previa de la imagen»
        static var imagePreview: String { s("image.preview") }
        /// «No se pudo armar la imagen.»
        static var imageRenderFailed: String { s("image.renderFailed") }
        /// «A %@ le deben»
        static func imageOwedToOther(_ a0: String) -> String { f("image.owedToOther", a0) }
        /// «%1$@ le debe a %2$@»
        static func imageOneOwesOther(_ a0: String, _ a1: String) -> String { f("image.oneOwesOther", a0, a1) }
        /// «Pagó %1$@ · total %2$@»
        static func imagePaidByTotal(_ a0: String, _ a1: String) -> String { f("image.paidByTotal", a0, a1) }
        /// «La parte de %1$@: %2$@»
        static func imagePayerPart(_ a0: String, _ a1: String) -> String { f("image.payerPart", a0, a1) }
        /// «Entre todos»
        static var imageEveryone: String { s("image.everyone") }
        /// «entre %d»
        static func imageSharedBy(_ a0: Int) -> String { f("image.sharedBy", a0) }
        /// «Dividido con Yala»
        static var imageFooterTitle: String { s("image.footerTitle") }
        /// «Reparte tu cuenta gratis»
        static var imageFooterSubtitle: String { s("image.footerSubtitle") }
        /// «Tu nombre en la imagen»
        static var imageNameLabel: String { s("image.nameLabel") }
        /// «Escribe tu nombre»
        static var imageNamePlaceholder: String { s("image.namePlaceholder") }
        /// «La imagen va a otras personas: ahí sales con tu nombre. Se guarda en tu perfil.»
        static var imageNameFooter: String { s("image.nameFooter") }
        /// «Registrar mi parte · %@»
        static func registerButton(_ a0: String) -> String { f("register.button", a0) }
        /// «o mándala a la Bandeja»
        static var registerInbox: String { s("register.inbox") }
        /// «Tu parte quedó registrada»
        static var registerDone: String { s("register.done") }
        /// «Tu parte quedó en la Bandeja»
        static var registerInInbox: String { s("register.inInbox") }
        /// «No se pudo guardar tu parte. Inténtalo otra vez.»
        static var registerFailed: String { s("register.failed") }
        /// «Cerrar»
        static var close: String { s("close") }
        /// «Volver»
        static var back: String { s("back") }
    }
}
