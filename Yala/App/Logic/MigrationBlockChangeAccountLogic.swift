//
//  MigrationBlockChangeAccountLogic.swift
//  Yala
//
//  ¿El aviso de «Activar la nube» parado ofrece «Cambiar de cuenta»? (decisión 55 de la revisión 2.3, opción G1.)
//
//  Hasta el 2026-11-11 tres de esos avisos mandaban a «desasociar en «Grupos»» y solo ofrecían «Entendido»: un callejón
//  de cinco toques (cerrar, leer, bajar hasta la tarjeta, «Desasociar», la hoja). Ahora la salida está en el botón, y el
//  botón abre la misma hoja de consecuencias que el enlace de la pantalla: **no se la salta**. Lo hace la pantalla
//  (`StorageSettingsView.onMigrationBlockDismissed`); aquí solo se decide si se ofrece.
//
//  Se ofrece cuando las dos cosas son verdad:
//  - el motivo se arregla soltando la cuenta de los grupos: la cuenta ya tiene datos propios, los grupos usan otra, o la
//    sesión puede ser de la persona anterior;
//  - y la pantalla puede soltarla AHORA (la sección ofrece soltar, no hay un soltar a medias ni uno en curso). Sin eso el
//    botón abriría nada.
//
//  No se ofrece junto a «Desasociarla y seguir»: ese aviso ya suelta la asociación vieja él mismo. Con «Usar otra
//  cuenta» depende del motivo: si los grupos usan OTRA cuenta, elegir otra se pararía igual mientras siga asociada, así que
//  se ofrecen las dos —su texto nombra las dos salidas—; si la cuenta elegida ya tiene datos, «Usar otra cuenta» es la
//  salida y soltar la de los grupos no la arregla.
//

enum MigrationBlockChangeAccountLogic {
    static func offersChangeAccount(
        reason: StorageMigrationIdentityGateLogic.Block,
        offersAnotherAccount: Bool,
        offersDetachingStaleAssociation: Bool,
        groupsAccountCanBeReleased: Bool
    ) -> Bool {
        guard groupsAccountCanBeReleased, !offersDetachingStaleAssociation else { return false }
        switch reason {
        case .anotherGroupsAccountAssociated:
            return true
        case .accountHasPersonalData, .sessionFromBeforeFreshStart:
            return !offersAnotherAccount
        case .accountReturnedToICloud, .migrationInProgressOnAnotherDevice:
            return false
        }
    }
}
