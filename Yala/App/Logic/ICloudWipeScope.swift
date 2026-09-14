//
//  ICloudWipeScope.swift
//  Yala
//
//  **Qué se lleva por delante un borrado del corpus de iCloud, además de la zona.**
//
//  Hasta el 2026-09-14 esto era un `Bool` (`includingLocalRows`) con dos valores, y era suficiente
//  porque había dos consumidores con necesidades opuestas: el Welcome, donde «empiezo de cero» es la
//  frontera de OTRO usuario en este dispositivo, y la puerta de «Activar Yala completo», donde lo local
//  es de la misma persona que está activando.
//
//  «Activar Yala completo → Restaurar → Empezar desde cero» abrió la tercera, y **no es la mitad de
//  ninguna de las dos**: hay que borrar las filas que el espejo importó (o el store las re-exporta a la
//  zona recién creada, que es el bug) pero sin tocar las preferencias (resetear `hasCompletedOnboarding`
//  mandaría al Welcome a quien está a mitad de activar) ni el dominio de Grupos (esos grupos son suyos, y
//  la activación existe para conservarlos).
//
//  **Por qué un enum y no dos `Bool` más:** con tres banderas sueltas el compilador acepta combinaciones
//  que no existen —purgar el dominio de Grupos sin borrar ninguna fila, resetear las preferencias sin
//  borrar nada— y cada call-site nuevo tendría que volver a razonar las tres. Aquí hay tres políticas con
//  nombre, y elegir una es una sola decisión.
//

import Foundation

/// Las tres políticas de borrado del corpus personal. **Todas borran la zona de CloudKit**; lo que
/// cambia es qué más se llevan del dispositivo.
///
/// | scope | zona | filas personales | preferencias e identidad | dominio Grupos |
/// |---|---|---|---|---|
/// | `.zoneOnly` | sí | — | — | — |
/// | `.importedRows` | sí | sí | **no** | **no** |
/// | `.handover` | sí | sí | sí | purga + sello |
enum ICloudWipeScope: Equatable, CaseIterable {

    /// **Solo la zona de iCloud.** La puerta privada de «Activar Yala completo» ANTES del relanzamiento:
    /// allí el store todavía no espeja, así que lo local nunca vino de iCloud — son las categorías, las
    /// cuentas y los grupos de la persona que está activando, y borrárselos sería el daño contrario al
    /// que esa puerta existe para evitar.
    case zoneOnly

    /// **La zona y las filas que el espejo ya importó, y nada más.** «Activar Yala completo → Restaurar →
    /// Empezar desde cero»: para llegar ahí hubo relanzamiento, así que el store espeja y lo local **es**
    /// el corpus que la persona acaba de decidir no traerse. Se va con la zona o se re-exporta a ella.
    ///
    /// Lo que NO se toca, y las dos son decisiones de Jürgen (2026-09-14):
    ///  · **las preferencias y la identidad** — el nombre, la divisa y el prefill son de quien está
    ///    activando, y `hasCompletedOnboarding` lo mandaría al Welcome a mitad de la activación;
    ///  · **el dominio de Grupos** — esos grupos son suyos, y conservarlos es el motivo de la activación.
    case importedRows

    /// **El handover: aquí empieza otro usuario en este dispositivo.** El Welcome y la reanudación de un
    /// borrado que quedó armado. Se lleva las filas, las preferencias y el dominio de Grupos, y escribe
    /// el sello que mantiene el bridge cerrado hasta que el usuario nuevo adopte Grupos.
    case handover

    /// ¿Borra las filas personales del dispositivo?
    var deletesLocalRows: Bool {
        switch self {
        case .zoneOnly: return false
        case .importedRows, .handover: return true
        }
    }

    /// ¿Resetea las preferencias y la identidad (`DataWipeService.wipeAllUserData(resetsPreferences:)`)?
    ///
    /// **Solo tiene sentido preguntarlo cuando se borran filas**, y por eso `.zoneOnly` contesta `false`:
    /// ese camino sale antes de llamar al borrador local.
    var resetsPreferences: Bool {
        switch self {
        case .zoneOnly, .importedRows: return false
        case .handover: return true
        }
    }

    /// ¿Purga y SELLA el dominio local de Grupos?
    ///
    /// **Es una pregunta distinta de `resetsPreferences` aunque hoy contesten lo mismo**, y separarlas no
    /// es ceremonia: la una habla de las preferencias de la persona y la otra de los grupos de OTRA
    /// persona que usó este teléfono. Colapsarlas haría que añadir un scope futuro heredara en silencio
    /// una purga que nadie pidió — y ese borrado es irreversible en local.
    var purgesGroupsDomain: Bool {
        switch self {
        case .zoneOnly, .importedRows: return false
        case .handover: return true
        }
    }
}
