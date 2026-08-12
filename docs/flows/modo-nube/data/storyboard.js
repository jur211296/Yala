// storyboard.js — el ORDEN de presentación del storyboard (chip F4).
//
// Este fichero NO añade narrativa: cada frame es un nodo de `data/nodes.js` y su orden sale de las
// aristas de los grafos de `data/flows.js` (que siguen siendo la SSOT de la estructura). Aquí solo se
// decide qué secuencia se lee primero (el camino feliz) y cómo se agrupan las ramas y los errores para
// poder recorrerlos de un vistazo, que es lo que el grafo no da.
//
// `linked: true` = los frames son una SECUENCIA (se pintan conectados con flecha).
// `linked: false` = son estados sueltos del mismo tema (se pintan sin conector).
// Un frame puede referenciar un nodo de OTRO flujo (p. ej. el consent, compartido): se pinta igual y
// el rótulo del frame dice de qué flujo viene.
//
// El pin de completitud vive en check.mjs: TODO nodo con pantalla debe aparecer en el storyboard de su
// flujo — un frame que falte es fallo, no un hueco silencioso.

window.ATLAS_STORYBOARD = {
  alta: {
    tracks: [
      {
        label: "Camino feliz · alta en la nube (percent remoto ON)",
        linked: true,
        frames: ["alta-hero", "alta-chooser", "alta-faro", "alta-newchooser", "alta-consent",
                 "alta-intro", "alta-signin", "alta-creating", "alta-claim", "alta-bornready",
                 "alta-postrelaunch"]
      },
      {
        label: "El camino de producción HOY · «privacidad total» (paga +1 relanzamiento — F3-H1)",
        linked: true,
        frames: ["alta-newchooser", "alta-mirrorrelaunch", "alta-privado"]
      },
      {
        label: "G2/G3 · «Vengo por un grupo» → crear el primero (la puerta comprueba antes de escribir)",
        linked: true,
        frames: ["alta-chooser", "alta-groupschooser", "alta-groupsgate", "alta-organizername",
                 "alta-organizerwrite"]
      },
      {
        label: "Las otras salidas del claim, los errores y la cancelación",
        linked: false,
        frames: ["alta-par-relaunch", "alta-returning", "alta-waitingleader", "alta-error-401",
                 "alta-error-403", "alta-error-transient", "alta-cancel",
                 "alta-groupsgate-blocked", "alta-organizercancel"]
      }
    ]
  },

  reentry: {
    tracks: [
      {
        label: "Camino feliz · re-entrada con Apple/Google → adopt",
        linked: true,
        frames: ["reentry-chooser", "reentry-intro", "alta-consent", "alta-signin",
                 "reentry-exists", "reentry-guard", "reentry-adopt", "reentry-relaunch"]
      },
      {
        label: "Restaurar de iCloud sobre mount neutro (R2: interpone el relanzamiento)",
        linked: true,
        frames: ["reentry-chooser", "alta-mirrorrelaunch"]
      },
      {
        label: "Guardas y errores",
        linked: false,
        frames: ["reentry-mismatch", "reentry-notfound", "reentry-blocked", "reentry-secondary",
                 "reentry-slotocupado", "reentry-consentwrite", "reentry-autoresume"]
      }
    ]
  },

  migracion: {
    tracks: [
      {
        label: "Camino feliz · migrar desde Ajustes",
        linked: true,
        frames: ["migracion-fila", "migracion-idle", "alta-consent", "migracion-confirm",
                 "migracion-signin-decision", "migracion-progreso", "migracion-cutover",
                 "migracion-relaunch", "migracion-cloudactive"]
      },
      {
        label: "La variante ADOPT y el fallo con rollback",
        linked: false,
        frames: ["migracion-adopt-copy", "migracion-fallo"]
      }
    ]
  },

  reversa: {
    tracks: [
      {
        label: "Camino completo · volver a iCloud",
        linked: true,
        frames: ["migracion-cloudactive", "reversa-card", "reversa-confirm", "reversa-fases",
                 "reversa-relaunch", "reversa-cierre"]
      }
    ]
  },

  signout: {
    tracks: [
      {
        label: "Cerrar sesión en `.cloud` · del tap al Welcome",
        linked: true,
        frames: ["signout-path", "signout-hoja", "signout-pushall", "signout-swap",
                 "signout-relaunch"]
      },
      {
        label: "Las otras salidas: salir del dispositivo, borrar cuenta, vaciar datos",
        linked: false,
        frames: ["signout-exityala", "signout-borrarcuenta", "signout-vaciar"]
      }
    ]
  },

  onboarding: {
    tracks: [
      {
        label: "Camino solo-grupos · de la card al primer grupo (C2: las cuatro puertas comparten esta cadena)",
        linked: true,
        frames: ["onboarding-purpose", "onboarding-groupsonly", "onboarding-educativo",
                 "onboarding-empty", "onboarding-groupssignin", "onboarding-consent",
                 "onboarding-crear"]
      },
      {
        label: "Lo que corta el paso: el muro iCloud (canal OFF en el selector) y el canal apagado al crear (C4)",
        linked: false,
        frames: ["onboarding-muro", "onboarding-canalapagado"]
      }
    ]
  },

  degradado: {
    tracks: [
      {
        label: "Estados degradados · no son una secuencia, son situaciones",
        linked: false,
        frames: ["degradado-killswitch", "degradado-sesion", "degradado-sinred",
                 "degradado-claiming", "degradado-mount", "degradado-neutro"]
      }
    ]
  }
};
