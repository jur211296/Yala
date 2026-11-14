/**
 * Variante de español de Argentina: un parche sobre `es.ts` con solo las claves que cambian, como `es-AR.lproj` en la app.
 * Cambia el voseo (Elegí, Volvé a intentarlo, tenés, podés) y el vocabulario de la app: acá, anotar, vas a ver, agregar.
 */
import type { TextsPatch } from "../i18n";

export const ES_AR: TextsPatch = {
  titulo: "Entrá a tu Yala",
  subtitulo: "Usá la misma cuenta que en tu iPhone.",
  protegido: "Protegido contra bots. Al entrar aceptás la",
  esperandoVerificacion: "Comprobando que sos vos…",
  dentro: "Ya estás dentro de Yala web. Lo próximo que vas a ver acá es tu Panel.",
  sinNubeComo: "Para usarla, elegí «Pasar a tu cuenta de Yala» en los ajustes de Yala en tu iPhone. Tus registros se copian y volvés acá.",
  soloGruposTitulo: "Pronto vas a poder ver tus Grupos acá",
  avisos: {
    cancelado: "No se completó el inicio de sesión. Podés intentarlo otra vez.",
    caducada: "El inicio de sesión tardó demasiado. Volvé a intentarlo.",
    verificacion: "No pudimos comprobar que sos vos. Volvé a intentarlo.",
    limite: "Demasiados intentos seguidos. Esperá un minuto y volvé a intentarlo.",
    error: "Algo salió mal al entrar. Volvé a intentarlo en un momento.",
    cerrada: "Esta sesión se cerró desde otro aparato. Volvé a entrar si querés seguir.",
  } as Record<string, string>,
  noDisponible: "Yala web no responde ahora mismo. Volvé a intentarlo en un momento.",
  app: {
    sinCuentas: "Todavía no tenés cuentas. Crealas en tu iPhone.",
    registrosNota: "En la beta los registros se miran. Para cambiar uno, abrilo en tu iPhone.",
    bandejaNota: "En la beta la Bandeja se ve acá y se aprueba en tu iPhone. Lo que anotás en la web llega con la etiqueta «Yala web».",
    esperandoNota: "Abrí Yala en tu iPhone y lo vas a ver en la Bandeja.",
    apuntarNota: "Va a la Bandeja de tu iPhone. Ahí lo confirmás con un toque y entra en tus saldos.",
    errores: {
      importe: "Escribí un importe mayor que cero.",
      fecha: "Elegí una fecha de hoy o anterior.",
      tope_diario: "Llegaste al tope de borradores de hoy. Volvé a intentarlo mañana.",
      recogido: "Tu iPhone ya recogió este borrador: cambialo en su Bandeja.",
      otro: "No se pudo enviar. Volvé a intentarlo.",
    } as Record<string, string>,
    sesionesNota: "Al cerrar una, esa pestaña se vacía en menos de un minuto. También podés cerrarlas desde tu iPhone: Ajustes › Tu cuenta de Yala › Navegadores conectados.",
    noCargo: "No se pudo cargar. Volvé a intentarlo.",
    recogidoToast: "Tu iPhone ya lo recogió: lo vas a ver en su Bandeja.",
    soloGruposCuerpo: "Tu cuenta usa Yala solo para Grupos. Para ver acá tus cuentas, registros y estadísticas, elegí «Activar Yala completo» en la app de Yala en tu iPhone.",
  },
  est: {
    nota: "Las mismas cifras que Estadísticas en tu iPhone. Para filtrar por cuenta o etiqueta, usá tu iPhone.",
  },
  pag: {
    sinSuscripciones: "No tenés suscripciones activas.",
    nota: "Para crear, editar o marcar un pago como pagado, usá tu iPhone.",
  },
  pre: {
    vacio: "Aún no tenés presupuestos",
    vacioCuerpo: "Crealos en tu iPhone, en Planificación › Presupuestos.",
    nota: "Las mismas cifras que Presupuestos en tu iPhone. Para crear o cambiar uno, usá tu iPhone.",
  },
  bus: {
    campo: "Buscá secciones, cuentas, categorías o notas",
  },
  csv: {
    cortado: (n: number) => `Se exportaron los ${n} más recientes. Para el resto, acotá el período o los filtros.`,
    error: "No se pudo exportar. Volvé a intentarlo.",
  },
  qr: {
    titulo: "Abrí Yala con tu iPhone",
    pasos: "En tu iPhone: Ajustes › Tu cuenta de Yala › Navegadores conectados › Vincular un navegador, y apuntá la cámara acá.",
    escribir: "¿Sin cámara? Escribí este código en tu iPhone:",
    visto: "Tu iPhone leyó el código. Confirmalo ahí con Face ID.",
    error: "No se pudo crear el código. Volvé a intentarlo.",
    seguridad: "Solo escaneá un código que veas en tu propia pantalla. Nadie de Yala te lo va a pedir.",
  },
  grp: {
    debes: (s: string) => `Debés ${s}`,
    leDebes: (nombre: string) => `Le debés a ${nombre}`,
    sinGruposNota: "Creá un grupo o unite con una invitación desde tu iPhone, y lo vas a ver acá.",
    incompleto: "Tenés más grupos de los que la web muestra de una vez: acá salen los primeros 50.",
    nota: "Los mismos saldos que Grupos en tu iPhone. Por ahora, para agregar un gasto, saldar o invitar, usá tu iPhone.",
    tu: "Vos",
    pagasteTu: "Pagaste vos",
    noParticipas: "No participás",
    grupoIncompleto: "Este grupo tiene más movimientos de los que la web lee de una vez: alguna cifra puede no cuadrar. Miralo en tu iPhone.",
    noDisponible: "Grupos no responde ahora mismo. Volvé a intentarlo en un momento.",
    notaEscribe: "Los mismos saldos que Grupos en tu iPhone. Lo que agregás acá les llega al momento a los demás.",
    soloIgual: "La web reparte a partes iguales. Para otros repartos, usá tu iPhone.",
    pagoHecho: "Pago anotado.",
    pagoPendienteHecho: (n: string) => `Pago anotado. Falta que ${n} lo confirme.`,
    invitarCuerpo: "Cualquier persona con este enlace puede unirse al grupo durante 7 días, hasta 20 personas. Compartilo solo con personas de confianza.",
    errores: {
      importe: "Escribí un importe mayor que cero, con dos decimales como mucho.",
      descripcion: "Escribí una descripción.",
      fecha: "Elegí una fecha de hoy o anterior.",
      participantes: "Elegí al menos una persona.",
      pagadoPor: "Elegí quién pagó.",
      limite: "Hiciste muchos cambios seguidos. Esperá un momento y volvé a intentarlo.",
      archivado: "Este grupo está archivado. Desarchivalo en tu iPhone para agregar cosas.",
      miembro: "Ya no formás parte de este grupo.",
      otro: "No se pudo guardar. Volvé a intentarlo.",
    } as Record<string, string>,
  },
};
