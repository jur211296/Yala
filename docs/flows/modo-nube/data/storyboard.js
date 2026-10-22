// storyboard.js — el ORDEN de presentación, por RECORRIDO DE PERSONA (chip F6).
//
// F6 (2026-08-12) cambió el EJE del Atlas: de siete flujos por MECANISMO (alta, re-entrada, migración,
// reversa, sign-out, puertas de Grupos, degradados) a once recorridos por PERSONA — «quién soy, qué móvil
// tengo, qué botón toco». Decisión del owner, y con ella otra: **los errores viven DENTRO del recorrido
// donde te los encuentras**, no en un recorrido aparte. Por eso ya no hay pestaña «degradados»: sus ocho
// paneles se repartieron entre las personas que se topan con ellos, y varios aparecen en más de una.
//
// Este fichero NO añade narrativa: cada frame es un nodo de `data/nodes.js`. Aquí solo se decide qué
// secuencia se lee primero (el camino feliz), cómo se agrupan las ramas y dónde entra cada error.
//
// `linked: true` = los frames son una SECUENCIA (se pintan conectados con flecha).
// `linked: false` = son estados sueltos del mismo tema (se pintan sin conector).
//
// **Un panel puede vivir en varios recorridos, y eso es correcto**: el chooser del Welcome lo ve todo el
// mundo, y la hoja de alcance la ven cuatro personas distintas. El id del panel es su NOMBRE PROPIO, no su
// clasificación — por eso los prefijos viejos (`alta-`, `reentry-`, `signout-`…) ya no dicen en qué
// recorrido vive. El reparto vive aquí, y solo aquí.
//
// El pin de completitud está en check.mjs: TODO nodo con pantalla debe aparecer en AL MENOS UN recorrido.

window.ATLAS_STORYBOARD = {

  // ══════════════════════════════════════════════════════════════════════════
  // R1 · Empiezo de cero, cuenta privada (móvil nuevo)
  // ══════════════════════════════════════════════════════════════════════════
  r1: {
    tracks: [
      {
        label: "Camino feliz · el recorrido que hace HOY todo usuario nuevo de producción",
        linked: true,
        frames: ["degradado-neutro", "alta-hero", "alta-chooser", "alta-faro", "alta-newchooser",
                 "alta-privado", "alta-mirrorrelaunch", "onboarding-purpose"]
      },
      {
        label: "Si en el onboarding digo que vengo por los grupos",
        linked: true,
        frames: ["onboarding-muro", "onboarding-groupsonly"]
      },
      {
        label: "Cuando algo va mal",
        linked: false,
        frames: ["degradado-killswitch"]
      }
    ]
  },

  // ══════════════════════════════════════════════════════════════════════════
  // R2 · Empiezo de cero, cuenta en la nube (móvil nuevo)
  // ══════════════════════════════════════════════════════════════════════════
  r2: {
    tracks: [
      {
        label: "Camino feliz · el alta en la nube (percent remoto ON) — y NO paga relanzamiento",
        linked: true,
        frames: ["degradado-neutro", "alta-hero", "alta-chooser", "alta-faro", "alta-newchooser",
                 "alta-consent", "alta-intro", "alta-signin", "alta-creating", "alta-claim",
                 "alta-bornready", "alta-postrelaunch", "onboarding-purpose"]
      },
      {
        label: "Las otras tres salidas del claim, y el device que SÍ relanza",
        linked: false,
        frames: ["alta-returning", "alta-waitingleader", "degradado-claiming", "alta-par-relaunch",
                 "degradado-mount"]
      },
      {
        label: "Cuando algo va mal, y qué pasa si me arrepiento",
        linked: false,
        frames: ["alta-error-401", "alta-error-403", "alta-error-transient", "degradado-sinred",
                 "alta-cancel", "degradado-killswitch", "degradado-sesion"]
      }
    ]
  },

  // ══════════════════════════════════════════════════════════════════════════
  // R3 · Llego con una invitación a un grupo
  // ══════════════════════════════════════════════════════════════════════════
  r3: {
    tracks: [
      {
        label: "Antes de la app · el enlace y la página web que veo si no la tengo instalada",
        linked: true,
        frames: ["r3-enlace-origen", "r3-landing"]
      },
      {
        label: "Camino feliz · toco el enlace con Yala instalada",
        linked: true,
        frames: ["r3-tap", "r3-canal", "r3-puerta-invite", "onboarding-puertas",
                 "onboarding-groupssignin", "onboarding-consent", "onboarding-consentcuenta",
                 "r3-onboarding-nombre", "r3-join", "r3-esperando", "r3-solicitud"]
      },
      {
        label: "La otra puerta · pego el enlace a mano desde el Welcome (la que SÍ pide reabrir la app)",
        linked: true,
        frames: ["alta-hero", "alta-chooser", "alta-groupschooser", "r3-recovery-relanzamiento",
                 "degradado-neutro", "alta-mirrorrelaunch", "r3-recovery"]
      },
      {
        label: "Después de pedir entrar · la espera, la aprobación y lo que queda escrito",
        linked: true,
        frames: ["r3-banner", "onboarding-empty", "onboarding-adopcion", "r3-intent",
                 "r3-aprobacion", "r3-listo"]
      },
      {
        label: "Cuando algo va mal · el enlace, el canal, la red y la sesión de otra persona",
        linked: false,
        frames: ["r3-err-enlace", "r3-err-canal", "r3-err-ckshare", "r3-err-red", "r3-frio",
                 "degradado-killswitch", "degradado-sesion", "degradado-sinred",
                 "r3-otra-sesion", "reentry-slotocupado", "r3-muertos"]
      }
    ]
  },

  // ══════════════════════════════════════════════════════════════════════════
  // R4 · Solo quiero grupos: creo el primero (organizador)
  // ══════════════════════════════════════════════════════════════════════════
  r4: {
    tracks: [
      {
        label: "Camino feliz · «Vengo por un grupo → Crear mi primer grupo» (la puerta comprueba ANTES de escribir)",
        linked: true,
        frames: ["degradado-neutro", "alta-hero", "alta-chooser", "alta-groupschooser",
                 "alta-groupsgate", "onboarding-puertas", "onboarding-educativo",
                 "onboarding-groupssignin", "onboarding-consent", "onboarding-consentcuenta",
                 "alta-organizername", "alta-organizerwrite"]
      },
      {
        label: "La otra vía a lo mismo · la card «Solo grupos» del onboarding de 8 pasos",
        linked: true,
        frames: ["onboarding-purpose", "onboarding-muro", "onboarding-groupsonly"]
      },
      {
        label: "Ya dentro del tab Grupos",
        linked: true,
        frames: ["onboarding-adopcion", "onboarding-empty", "onboarding-crear"]
      },
      {
        label: "Cuando la puerta NO abre, y si me arrepiento a mitad",
        linked: false,
        frames: ["alta-groupsgate-blocked", "alta-organizercancel", "onboarding-canalapagado",
                 "degradado-legacyretire"]
      },
      {
        label: "Si un día me quiero ir",
        linked: false,
        frames: ["signout-path", "signout-hoja", "signout-pushall", "signout-relaunch",
                 "signout-exityala", "signout-vaciar", "signout-borrarcuenta"]
      }
    ]
  },

  // ══════════════════════════════════════════════════════════════════════════
  // R5 · Vuelvo a Yala en un móvil nuevo (2.º dispositivo o reinstalación)
  // ══════════════════════════════════════════════════════════════════════════
  r5: {
    tracks: [
      {
        label: "Camino feliz · móvil nuevo, entro con mi cuenta y adopto",
        linked: true,
        frames: ["reentry-arranque", "degradado-neutro", "alta-hero", "alta-chooser", "alta-faro",
                 "reentry-movilnuevo", "reentry-chooser", "reentry-intro", "alta-consent",
                 "alta-signin", "reentry-consentwrite", "reentry-exists", "reentry-guard",
                 "reentry-adoptvacio", "reentry-adopt", "reentry-relanzamientoR5", "reentry-relaunch"]
      },
      {
        label: "Reinstalación en el MISMO móvil · la sesión sobrevive y la llave de attest no",
        linked: true,
        frames: ["reentry-mismomovil", "reentry-attestmuerta"]
      },
      {
        label: "Ya dentro · lo que chirría al volver (⚠︎ tres hallazgos medidos)",
        linked: true,
        frames: ["degradado-mount", "reentry-vacio", "reentry-nuevainstalacion", "migracion-cloudactive"]
      },
      {
        label: "La otra puerta · «Restaurar desde iCloud» y la adopción desde Ajustes",
        linked: true,
        frames: ["reentry-puertaequivocada", "alta-mirrorrelaunch", "migracion-adopt-copy",
                 "migracion-signin-decision", "migracion-progreso", "migracion-relaunch"]
      },
      {
        label: "Cuando algo va mal · el método, la cuenta, la red y el kill-switch",
        linked: false,
        frames: ["reentry-mismatch", "reentry-notfound", "reentry-falsobloqueo", "reentry-blocked",
                 "alta-returning", "alta-waitingleader", "degradado-claiming", "reentry-autoresume",
                 "reentry-errores", "alta-error-401", "alta-error-403", "alta-error-transient",
                 "degradado-sinred", "reentry-killmidadopt", "reentry-killswitch",
                 "degradado-killswitch"]
      }
    ]
  },

  // ══════════════════════════════════════════════════════════════════════════
  // R6 · Soy privada y salgo de Yala
  // ══════════════════════════════════════════════════════════════════════════
  r6: {
    tracks: [
      {
        label: "La salida · una fila, una hoja, y ningún dato tocado",
        linked: true,
        frames: ["signout-fila-privada", "signout-path", "signout-hoja", "signout-hoja-privada",
                 "signout-privado-ejecucion"]
      },
      {
        label: "Y ahora, ¿qué veo? · el mismo Welcome sobre un móvil LLENO",
        linked: true,
        frames: ["signout-welcome-condatos", "alta-hero", "alta-chooser", "signout-salidas-matriz"]
      },
      {
        label: "Si toco «Es mi primera vez» · el único alert que borra (⚠︎ y lo que ya borró antes de preguntar)",
        linked: true,
        frames: ["signout-freshstart-alert", "alta-privado"]
      },
      {
        label: "Si toco «Ya tengo una cuenta» · la vuelta a casa y sus cuatro finales no-felices",
        linked: true,
        frames: ["reentry-chooser", "signout-restaurar-vuelta", "signout-restaurar-errores"]
      },
      {
        label: "Si toco «Vengo por un grupo» · la puerta que me acusa de traer datos ajenos (⚠︎)",
        linked: false,
        frames: ["alta-groupsgate-blocked", "reentry-guard", "reentry-blocked"]
      },
      {
        label: "El otro humano que sale por esta misma fila · el solo-grupos legado 5a",
        linked: true,
        frames: ["signout-exityala", "signout-hoja-legado5a"]
      }
    ]
  },

  // ══════════════════════════════════════════════════════════════════════════
  // R7 · Soy de la nube y cierro sesión
  // ══════════════════════════════════════════════════════════════════════════
  r7: {
    tracks: [
      {
        label: "Vivo en la nube",
        linked: true,
        frames: ["migracion-cloudactive", "degradado-sesion"]
      },
      {
        label: "Camino feliz · cierro sesión (y JAMÁS se descarta lo que no subió)",
        linked: true,
        frames: ["signout-path", "signout-hoja", "signout-pushall", "signout-relaunch",
                 "degradado-neutro"]
      },
      {
        label: "El cambio de persona sin reiniciar",
        linked: false,
        frames: ["signout-swap"]
      },
      {
        label: "Las otras dos filas de la misma pantalla",
        linked: false,
        frames: ["signout-vaciar", "signout-borrarcuenta"]
      }
    ]
  },

  // ══════════════════════════════════════════════════════════════════════════
  // R8 · Paso de privada a la nube
  // ══════════════════════════════════════════════════════════════════════════
  r8: {
    tracks: [
      {
        label: "La puerta · Ajustes → «Dónde viven tus datos»",
        linked: true,
        frames: ["migracion-fila", "migracion-idle", "migracion-signin-decision", "alta-signin",
                 "alta-consent", "migracion-confirm"]
      },
      {
        label: "Camino feliz · la migración, paso a paso",
        linked: true,
        frames: ["migracion-adopt-copy", "migracion-progreso", "migracion-cutover",
                 "migracion-relaunch", "degradado-mount", "migracion-cloudactive"]
      },
      {
        label: "Cuando algo va mal · el rollback y lo que se ve mientras",
        linked: false,
        frames: ["migracion-fallo", "degradado-sinred", "degradado-claiming", "degradado-sesion",
                 "degradado-killswitch"]
      }
    ]
  },

  // ══════════════════════════════════════════════════════════════════════════
  // R9 · Vuelvo de la nube a privada
  // ══════════════════════════════════════════════════════════════════════════
  r9: {
    tracks: [
      {
        label: "Camino feliz · la reversa completa",
        linked: true,
        frames: ["migracion-cloudactive", "migracion-fila", "reversa-card", "reversa-confirm",
                 "reversa-fases", "reversa-relaunch", "degradado-mount", "reversa-cierre",
                 "migracion-idle"]
      }
    ]
  },

  // ══════════════════════════════════════════════════════════════════════════
  // R10 · Estoy de visita en el móvil de otra persona
  // ══════════════════════════════════════════════════════════════════════════
  r10: {
    tracks: [
      {
        label: "Cómo entro de visita · la sesión secundaria y su confirmación",
        linked: true,
        frames: ["reentry-guard", "reentry-secondary", "reentry-slotocupado", "reentry-relaunch"]
      },
      {
        label: "La app que veo mientras baja mi cuenta · y de quién es cada cajón",
        linked: true,
        frames: ["visita-stores", "visita-shell", "degradado-ajustesdueno", "visita-frontera-prefs"]
      },
      {
        label: "La puerta por la que vuelvo al Welcome sin querer",
        linked: true,
        frames: ["visita-vaciar", "alta-chooser", "visita-chooser"]
      },
      {
        label: "Intento 1 · «Crear mi primer grupo» — la ÚNICA de las cuatro con puerta",
        linked: true,
        frames: ["alta-groupschooser", "visita-crear-grupo", "alta-groupsgate-blocked"]
      },
      {
        label: "Intento 2 · entrar a MI cuenta, o restaurar de iCloud",
        linked: true,
        frames: ["visita-reentrar-cuenta", "reentry-blocked", "visita-restaurar-icloud"]
      },
      {
        label: "Intento 3 · crear una cuenta nube nueva (⚠︎ escribe el faro del dueño)",
        linked: false,
        frames: ["visita-cuenta-nueva"]
      },
      {
        label: "Intento 4 · «privacidad total» — la rama SIN puerta (⚠︎ el hueco medido)",
        linked: true,
        frames: ["visita-privado", "visita-privado-alert", "visita-privado-onboarding"]
      },
      {
        label: "La salida",
        linked: true,
        frames: ["signout-path", "signout-hoja", "visita-salida"]
      }
    ]
  },

  // ══════════════════════════════════════════════════════════════════════════
  // R11 · El dueño recupera su móvil
  // ══════════════════════════════════════════════════════════════════════════
  r11: {
    tracks: [
      {
        label: "La visita busca la salida · la única fila que tiene",
        linked: true,
        frames: ["vuelta-salida-ajustes", "signout-path", "signout-hoja", "vuelta-hoja",
                 "signout-pushall", "vuelta-pushall", "vuelta-gruposnoempuja"]
      },
      {
        label: "El cierre · lo que se arma y lo que JAMÁS se arma",
        linked: true,
        frames: ["vuelta-armado", "vuelta-cover", "signout-relaunch", "vuelta-boot"]
      },
      {
        label: "El dueño reabre y se encuentra el Welcome, no su app",
        linked: true,
        frames: ["vuelta-welcome", "degradado-neutro", "vuelta-restaurar"]
      },
      {
        label: "Qué queda de la visita en el móvil (⚠︎ inventario medido)",
        linked: false,
        frames: ["vuelta-queda", "degradado-ajustesdueno", "vuelta-consent"]
      },
      {
        label: "Cuando el cierre no sale limpio",
        linked: false,
        frames: ["vuelta-bloqueado", "vuelta-sesioncaducada", "vuelta-kill", "vuelta-abort"]
      }
    ]
  }
};
