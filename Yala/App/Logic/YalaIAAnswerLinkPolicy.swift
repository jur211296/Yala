//
//  YalaIAAnswerLinkPolicy.swift
//  Yala
//
//  Qué enlaces de un texto escrito por el modelo se pueden tocar (decisión 4A de Jürgen, 2026-10-18; ticket
//  `yala-ia-answer-renders-model-links-as-tappable`). El modelo lee texto que el usuario no escribió —la nota de un gasto
//  de grupo la puso otro miembro— y una nota con instrucciones podría hacer que la respuesta enseñe un enlace con cifras
//  del usuario dentro de la URL. Por eso solo se pueden tocar los de Yala: `https` a `yala-app.pe` o a un subdominio
//  suyo. Los demás se quedan como texto, con su etiqueta y sin la URL. La negrita, la cursiva y el `código` no cambian.
//

import Foundation

nonisolated enum YalaIAAnswerLinkPolicy {
    static let allowedHost = "yala-app.pe"

    /// ¿Se puede tocar este enlace? Solo `https` con host `yala-app.pe` o `*.yala-app.pe`. Falla cerrado: `http`,
    /// `mailto:`, `tel:`, esquemas propios, hosts que solo lo contienen (`yala-app.pe.otro.com`, `noyala-app.pe`) y
    /// URLs sin host se quedan como texto.
    static func isAllowed(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https", let host = url.host()?.lowercased() else { return false }
        return host == allowedHost || host.hasSuffix("." + allowedHost)
    }

    /// Quita el enlace a todo tramo cuya URL no pase `isAllowed`. El texto del tramo se queda.
    static func sanitized(_ text: AttributedString) -> AttributedString {
        var result = text
        for run in text.runs {
            guard let url = run.link, !isAllowed(url) else { continue }
            result[run.range].link = nil
        }
        return result
    }

    /// El markdown en línea de una respuesta, con los enlaces ya filtrados. Mismas reglas que tenía la burbuja con
    /// `LocalizedStringKey` (solo sintaxis en línea, espacios y saltos tal cual); si el markdown no se deja leer, el
    /// texto plano, que no lleva enlaces.
    static func inlineMarkdown(_ text: String) -> AttributedString {
        do {
            let parsed = try AttributedString(
                markdown: text,
                options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            )
            return sanitized(parsed)
        } catch {
            #if DEBUG
            print("YalaIAAnswerLinkPolicy: markdown no legible, va como texto: \(error)")
            #endif
            return AttributedString(text)
        }
    }
}
