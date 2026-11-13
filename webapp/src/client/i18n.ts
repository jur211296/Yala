/** Textos de la página en español e inglés (decisión D12). El idioma es el del navegador; por defecto, español. */
const ES = {
  titulo: "Entra a tu Yala",
  subtitulo: "Usa la misma cuenta que en tu iPhone.",
  apple: "Continuar con Apple",
  google: "Continuar con Google",
  compartido: "Es un equipo compartido: no recordar esta sesión",
  protegido: "Protegido contra bots. Al entrar aceptas la",
  politica: "política de privacidad",
  esperandoVerificacion: "Comprobando que eres tú…",
  cargando: "Cargando…",
  hola: (nombre: string) => (nombre ? `Hola, ${nombre}` : "Hola"),
  dentro: "Ya estás dentro de Yala web. Lo próximo que vas a ver aquí es tu Panel.",
  cuenta: "Tu cuenta",
  equipoCompartido: "Equipo compartido: la sesión se cierra al cerrar el navegador o tras 30 minutos sin uso.",
  salir: "Salir",
  volver: "Volver a intentar",
  sinNubeTitulo: "Tu Yala vive en iCloud",
  sinNube:
    "Yala web solo abre cuentas que usan la nube de Yala. Tus datos siguen en tu iCloud y no se mueven sin que lo pidas.",
  sinNubeComo: "Para usarla, activa la nube en los ajustes de Yala en tu iPhone. Tus registros se copian y vuelves aquí.",
  soloGruposTitulo: "Pronto podrás ver tus Grupos aquí",
  soloGrupos: "Por ahora Yala web abre cuentas que usan la nube de Yala para sus finanzas personales. Grupos llega en una próxima versión.",
  avisos: {
    salida: "Saliste de Yala web. ¡Hasta pronto!",
    cancelado: "No se completó el inicio de sesión. Puedes intentarlo otra vez.",
    caducada: "El inicio de sesión tardó demasiado. Vuelve a intentarlo.",
    verificacion: "No pudimos comprobar que eres tú. Vuelve a intentarlo.",
    limite: "Demasiados intentos seguidos. Espera un minuto y vuelve a intentarlo.",
    error: "Algo salió mal al entrar. Vuelve a intentarlo en un momento.",
  } as Record<string, string>,
  noDisponible: "Yala web no responde ahora mismo. Vuelve a intentarlo en un momento.",
};

type Texts = typeof ES;

const EN: Texts = {
  titulo: "Sign in to Yala",
  subtitulo: "Use the same account as on your iPhone.",
  apple: "Continue with Apple",
  google: "Continue with Google",
  compartido: "This is a shared computer: don't remember this session",
  protegido: "Protected against bots. By signing in you accept the",
  politica: "privacy policy",
  esperandoVerificacion: "Checking it's you…",
  cargando: "Loading…",
  hola: (nombre: string) => (nombre ? `Hi, ${nombre}` : "Hi"),
  dentro: "You're in Yala web. Your Dashboard is the next thing you'll see here.",
  cuenta: "Your account",
  equipoCompartido: "Shared computer: the session ends when you close the browser or after 30 minutes of inactivity.",
  salir: "Sign out",
  volver: "Try again",
  sinNubeTitulo: "Your Yala lives in iCloud",
  sinNube: "Yala web only opens accounts that use the Yala cloud. Your data stays in your iCloud and doesn't move unless you ask.",
  sinNubeComo: "To use it, turn on the cloud in Yala's settings on your iPhone. Your records are copied and you can come back here.",
  soloGruposTitulo: "Your Groups are coming here soon",
  soloGrupos: "For now, Yala web opens accounts that use the Yala cloud for personal finances. Groups arrive in an upcoming version.",
  avisos: {
    salida: "You signed out of Yala web. See you soon!",
    cancelado: "Sign-in wasn't completed. You can try again.",
    caducada: "Sign-in took too long. Please try again.",
    verificacion: "We couldn't check it's you. Please try again.",
    limite: "Too many attempts in a row. Wait a minute and try again.",
    error: "Something went wrong while signing in. Try again in a moment.",
  },
  noDisponible: "Yala web isn't responding right now. Try again in a moment.",
};

export function texts(): Texts {
  const lang = (navigator.language || "es").toLowerCase();
  return lang.startsWith("es") ? ES : lang.startsWith("en") ? EN : ES;
}

export function lang(): "es" | "en" {
  return (navigator.language || "es").toLowerCase().startsWith("en") ? "en" : "es";
}
