//
//  PersonalSwapReleaseLogic.swift
//  Yala
//
//  R4 del relanzamiento cero · la decisión PURA del «release verificado».
//
//  ## Por qué esto es un enum aparte y no dos `if` dentro del orquestador
//
//  El swap de persona in-process (soltar el `ModelContainer` viejo, borrar los archivos del store y montar
//  otro) es seguro **si y solo si el container viejo MURIÓ**. Y el spike R3 midió que esa pregunta no tiene
//  una respuesta sino dos, que hay que hacer JUNTAS:
//
//   1. **¿Murió el OBJETO?** — el `weak` sentinel. Necesario y NO suficiente: el objeto Swift puede morir
//      con la pila de Core Data viva.
//   2. **¿Se cerró la CONEXIÓN?** — el conteo de descriptores abiertos del proceso que apuntan al archivo
//      (`fcntl(F_GETPATH)`). El instrumento que se eligió primero para esto —el borrado de `-wal`/`-shm` al
//      cerrar— **NO DISCRIMINA**: Core Data activa el WAL persistente, así que los dos sidecars siguen en
//      disco con la conexión ya cerrada (MEDIDO, spec §11.1).
//
//  El eje 4b del spike es la razón de que esto sea un ABORTO y no un aviso: con el container VIVO, borrar
//  los archivos por debajo NO lanza y NO crashea — el fetch devuelve **0 filas en silencio** (SQLite grita
//  `vnode unlinked while in use` y Core Data se lo traga) y el superviviente **ESCRIBE y RESUCITA** el
//  archivo que el wipe acababa de borrar. O sea: un wipe sin release verificado no falla, **miente**, y
//  además se deshace solo. Es el modo de fallo del incidente de Apple Pay (TN3163/TN3164, FB13278891).
//
//  ## Y por qué el canario ES el mecanismo, no una precaución
//
//  El spec §1.11 contó 62 propiedades de tipo `ModelContext`/`ModelContainer` y las trató como la lista de
//  retenedores. El eje 1c del spike la refutó: **una fila `@Model` fetcheada retiene el container por sí
//  sola**, y hay 37 ViewModels y 67 `@Query` cuyo contenido es exactamente eso. ⇒ la lista no se puede
//  cerrar por inspección y «soltar por lista» no es una estrategia de release. Lo que decide es esto.
//

import Foundation

nonisolated enum PersonalSwapReleaseLogic {

    // MARK: - ¿Murió del todo?

    /// El veredicto del release. Los dos abortos se distinguen a propósito: son fallos DISTINTOS y su
    /// canario tiene que poder decir cuál fue (objeto vivo ⇒ alguien retiene una referencia fuerte;
    /// descriptores abiertos con el objeto muerto ⇒ la pila de Core Data no soltó el archivo, que es el
    /// estado que el `weak` sentinel por sí solo declararía «verificado» y NO lo es).
    enum Verdict: Equatable {
        /// Sentinel `nil` **Y** cero descriptores. Es el ÚNICO valor que autoriza el wipe.
        case released
        /// El objeto sigue vivo al agotarse la ventana.
        case abortObjectAlive
        /// El objeto murió pero quedan descriptores abiertos sobre el archivo.
        case abortDescriptorsOpen(count: Int)
    }

    /// **«Release verificado» = sentinel `nil` Y cero descriptores.** Las dos condiciones, no una.
    ///
    /// El orden de los `guard` no es cosmético: si el objeto sigue vivo, sus descriptores lo están por una
    /// razón conocida y reportar «hay descriptores» sería ruido. La causa que importa es la primera.
    static func verdict(sentinelAlive: Bool, openDescriptors: Int) -> Verdict {
        guard !sentinelAlive else { return .abortObjectAlive }
        guard openDescriptors == 0 else { return .abortDescriptorsOpen(count: openDescriptors) }
        return .released
    }

    /// ¿Este veredicto autoriza a borrar los archivos y montar el container nuevo?
    ///
    /// Existe como propiedad y no como `== .released` en el call-site porque es la pregunta que el
    /// orquestador hace, y tenerla aquí es lo que permite que su mutación (dejar pasar un aborto) tumbe un
    /// test de esta tabla en vez de esconderse en un `if` del servicio.
    static func authorizesWipe(_ verdict: Verdict) -> Bool {
        verdict == .released
    }

    // MARK: - ¿Este mount admite siquiera intentarlo?

    /// **El guard de ALCANCE del chip, y es lo que lo mantiene dentro de lo medido.** La Opción C está
    /// acotada por decisión del owner a transiciones en las que NINGUNO de los dos extremos tiene mirror:
    /// ahí no hay `NSPersistentCloudKitContainer` en juego —ni que matar ni que arrancar—, que es justo la
    /// pieza cuyo comportamiento bajo release el eje 3 midió en device y dejó con un residual abierto (el
    /// trabajo en vuelo de CloudKit SOBREVIVE al container: 5 eventos en los 10 s posteriores al release).
    ///
    /// El extremo de LLEGADA es neutro por construcción (`neutralNoMirror`, `.none` explícito), así que lo
    /// único que hay que comprobar es el de SALIDA. Se pregunta por el TESTIGO del mount de este proceso y
    /// no por el modo persistido: durante la ventana del cutover el modo ya dice `.cloud` mientras el
    /// mirror sigue montado, y ese es exactamente el device que no puede hacer swap.
    static func mountAdmitsSwap(
        mountedDecision: SwiftDataConfiguration.PersonalStoreDecision
    ) -> Bool {
        !mountedDecision.attachesCloudKitMirror
    }
}
