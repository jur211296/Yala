
/// Cuándo «Conectando con tu cuenta…» añade «Esto puede tardar unos minutos. Mantén Yala abierta.» (card hov2 del QA
/// guiado del 19-oct: con una cuenta casi vacía, Jürgen leyó el aviso de minutos en una entrada que debería durar
/// segundos). Hasta este plazo la pantalla solo dice que conecta.
enum WelcomeAdoptSlowHint {
    static let delay: Duration = .seconds(8)
}
