# Pendiente: lanzar S12k al cerrar S13 (Grupos bugs)

Slug: sesion-nube-panel-welcome
Brief: ~/Claude/tmp-frank/sesion-S12k-sesion-nube-panel-welcome.md
Cards: 7e60 (crash cierre + Welcome tras login), pz4v (aviso Panel sin sesión)
Tras S12k: S12tf TestFlight 2.2 (3) — encargo en 2026-10-28-subida-testflight-2-2-3.md
No lanzar en paralelo con S13.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · pz4v: ¿dónde sale el aviso de «inicia sesión» en el Panel?** → Fijo arriba, justo debajo del aviso del attest y fuera de la cola «1 de N», como su hermano.
Por qué: la cabecera de `PanelNoticeQueueLogic` ya deja fuera de la cola los avisos de «algo NO funciona»; éste es uno. Alternativa descartada: un aviso más de la cola, que lo dejaría detrás de Primeros pasos o de la oferta Pro.

**D2 · pz4v: ¿qué decide que salga?** → Exactamente lo que enciende la tarjeta de Ajustes (`CloudMigrationController.syncNeedsSignIn`, vía `refresh()`), más el canal estable (`uiState == .cloudActive`, el mismo término que el aviso del attest) y nunca a la vez que el del attest.
Por qué: las dos superficies tienen que decir lo mismo; re-firmar no arregla un attest roto (orden de `SyncStatusSectionLogic`). Alternativa descartada: una condición propia del Panel, que divergiría de Ajustes.

**D3 · pz4v: ¿qué hace el botón?** → Abre Ajustes › «Dónde viven tus datos» y arranca ahí mismo el inicio de sesión (molde `CloudAdoptOfferRequest` de la card vbf9).
Por qué: el rechazo de «entró otra cuenta» y los errores se presentan en esa pantalla; llamando a la firma desde el Panel se perderían. Alternativa descartada: firmar desde el Panel.

**D4 · pz4v: ¿se puede cerrar con X?** → No.
Por qué: describe un estado que sigue ahí; el aviso hermano del attest tampoco lleva X. Desaparece solo al volver a entrar.

**D5 · pz4v: copy** → Título = la misma frase de Ajustes («Inicia sesión para subir N cambios», sin cifra si no se pudo contar); una línea nueva: «Lo que ves aquí puede no estar al día con tu cuenta.»; botón = «Iniciar sesión» de Ajustes. Una sola clave nueva, en 16 idiomas.

**D6 · ds09: ¿cómo se esconde Primeros pasos a quien vuelve con datos?** → En el mismo momento en que `ReturningUserBeginnerTips` da los tips por vistos (`.markSeen`), se descarta la tarjeta (`SetupChecklistManager.dismissCompleted`).
Por qué: es el criterio que Jürgen ya fijó el 22-oct («llegar con datos»); un segundo criterio divergiría. Alternativa descartada: sincronizar el progreso de la checklist por la cuenta (mueve datos y es más grande que el hueco).

**D7 · rj3b: referencia de alineación** → Las cards de grupo (Jurpi, Matri), medidas en píxeles en el simulador; banner de avisos y botones «Nuevo gasto»/«Nuevo grupo» se ajustan a ellas.

**D8 · rj3b: ¿qué hace la X de «Avisos del grupo»?** → La esconde y ya no vuelve en la lista (la marca «vista» que ya pone la tarjeta); no toca los avisos de iOS.
Por qué: la tarjeta de la lista ya es de una sola vez (card fptw); la X solo adelanta su salida.

**D9 · 7e60 (a): crash al cerrar sesión perdiendo cambios** → Sin informe en Sentry ni el iPhone conectado; el camino no tiene `fatalError`/`try!`. Se trata como lo medible: (ver «Hallazgos 7e60» al cerrar). Si no se puede reproducir en simulador, se instrumenta para que el próximo caso deje rastro y se pide el `.ips` a Jürgen en «Necesita de ti».
