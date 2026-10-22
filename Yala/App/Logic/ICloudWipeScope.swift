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
///
/// **`String` porque se apunta en disco** (`StorageModePersistence.recordICloudCorpusWipeScope`): el borrado armado
/// guarda con qué alcance entró, y quien lo termina lo lee. Los `rawValue` son formato persistido: no se renombran.
/// `nonisolated` porque lo lee y lo escribe `StorageModePersistence`, que lo es.
nonisolated enum ICloudWipeScope: String, Equatable, CaseIterable {

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
    ///
    /// Y **el borrado que empieza el aviso del espejo tardío**, para todas las sesiones (tickets
    /// `activation-private-gate-leaves-a-late-notice-that-purges-groups` y
    /// `late-notice-of-a-welcome-private-session-purges-groups-joined-later`): ver `lateNotice`.
    case importedRows

    /// **El handover: aquí empieza otro usuario en este dispositivo.** El Welcome, y el aviso del espejo
    /// tardío cuando lo que termina es un borrado del Welcome que quedó a medias (`lateNotice`). Se lleva las
    /// filas, las preferencias y el dominio de Grupos, y escribe el sello que mantiene el bridge cerrado hasta
    /// que el usuario nuevo adopte Grupos.
    ///
    /// **Las tres promesas cuelgan de que HAYA filas locales, y eso no es un descuido** (2026-09-17). Sin
    /// corpus en el teléfono no hay nada que apartar, y el sello es irreversible aquí: escribirlo sobre un
    /// store vacío se lo comería quien reinstala su PROPIA app y quien contesta al aviso del espejo
    /// tardío, que es la misma persona. Lo que sí sobrevive al store vacío es la SESIÓN en la nube del
    /// anterior, y esa se retira siempre (`CloudSessionRetirement`, en la salida temprana de
    /// `performICloudCorpusWipe`).
    case handover

    /// **Los dos borrados del aviso del espejo tardío.** El aviso hace dos cosas distintas, y hasta el 2026-09-27 las
    /// borraba con el mismo alcance:
    nonisolated enum LateWipe: Equatable {
        /// «Empezar de cero» del aviso con el corpus de iCloud: un borrado NUEVO, que pide la persona de esta sesión.
        case startFresh
        /// Terminar un borrado que ya estaba en marcha: «Terminar de borrar» del borrado a medias y la reanudación del
        /// arranque tras un kill. `armedWith` es el alcance con que ese borrado entró
        /// (`StorageModePersistence.icloudCorpusWipeScope`), o `nil` si lo armó un build anterior al apunte.
        case finishPending(armedWith: ICloudWipeScope?)

        /// **Cuál de los dos es, leído del llamador y del disco.** Termina quien lo dice —la hoja «El borrado quedó a
        /// medias» y la reanudación del arranque— y también cualquiera con «a medias» puesto: el «Terminar de borrar» del
        /// aviso con el corpus cuyo propio borrado quedó a medias delante de la persona (la hoja sigue siendo `.corpus`).
        /// Así no depende de que empezar y terminar den hoy el mismo alcance en ese caso.
        static func resolve(finishingPendingWipe: Bool, leftHalfway: Bool, armedWith: ICloudWipeScope?) -> LateWipe {
            (finishingPendingWipe || leftHalfway) ? .finishPending(armedWith: armedWith) : .startFresh
        }
    }

    /// **El alcance del borrado del aviso del espejo tardío.**
    ///
    /// **Empezar de cero es `.importedRows`, venga de donde venga la sesión.** Quien contesta al aviso es la persona
    /// de esta sesión privada, y los grupos que hay en el teléfono son suyos. El testigo del aviso solo lo dejan dos
    /// puertas: la del Welcome, que sigue al onboarding privado —y ése solo arranca sobre un teléfono sin datos, grupos
    /// incluidos: `startFreshPrivateOnboarding` los cuenta y, si los hay, pide borrarlos con el handover; salvo los que
    /// conservó un aviso tardío anterior, que son de la misma persona (`LateNoticeKeptGroupsMark`)—, y la de
    /// «Activar Yala completo», que existe para conservarlos. Así que todo grupo que haya al llegar el aviso es uno al
    /// que la persona se unió DESPUÉS de elegir privado, o uno que trajo la activación. El `.handover` se los llevaba,
    /// con su sesión de Grupos y el sello, mientras el copy solo nombra «tus registros, tus cuentas y tus presupuestos».
    ///
    /// **Terminar un borrado es terminar EL QUE SE ARMÓ**, con su alcance. El aviso termina también el borrado a medias
    /// de la puerta del Welcome, y ése sí es una frontera de usuario: el dominio puede ser de quien usó el teléfono
    /// antes, y tiene que seguir sellándose. Lo que decide no es quién contesta sino qué borrado se está terminando, y
    /// ese hecho lo apunta el propio borrado al entrar. Sin apunte (un arm de un build anterior), el comportamiento de
    /// antes: de dónde nació la sesión (`PrivateSessionMark.isBornFromFullActivation`).
    ///
    /// Sin default a propósito, como `performICloudCorpusWipe`: el llamador tiene que decir cuál de los dos borra.
    static func lateNotice(_ wipe: LateWipe, sessionBornFromFullActivation: Bool) -> ICloudWipeScope {
        switch wipe {
        case .startFresh:
            return .importedRows
        case .finishPending(armedWith: let armed?):
            return armed
        case .finishPending(armedWith: nil):
            return sessionBornFromFullActivation ? .importedRows : .handover
        }
    }

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
