/**
 * Variante de español de España: un parche sobre `es.ts` con solo las claves que cambian, como `es-ES.lproj` en la app.
 * Cambia el vocabulario de España (ordenador, comida, vosotros) y el pretérito perfecto para lo recién pasado (ha caducado).
 */
import type { TextsPatch } from "../i18n";

export const ES_ES: TextsPatch = {
  compartido: "Es un ordenador compartido: no recordar esta sesión",
  dentro: "Ya estás dentro de Yala web. Lo próximo que verás aquí es tu Panel.",
  equipoCompartido: "Ordenador compartido: la sesión se cierra al cerrar el navegador o tras 30 minutos sin uso.",
  avisos: {
    salida: "Has salido de Yala web. ¡Hasta pronto!",
    cancelado: "No se ha completado el inicio de sesión. Puedes intentarlo otra vez.",
    caducada: "El inicio de sesión ha tardado demasiado. Vuelve a intentarlo.",
    verificacion: "No hemos podido comprobar que eres tú. Vuelve a intentarlo.",
    error: "Algo ha salido mal al entrar. Vuelve a intentarlo en un momento.",
    cerrada: "Esta sesión se ha cerrado desde otro aparato. Vuelve a entrar si quieres seguir.",
  } as Record<string, string>,
  app: {
    descripcionPh: "Comida",
    errores: {
      tope_diario: "Has llegado al tope de borradores de hoy. Vuelve a intentarlo mañana.",
      recogido: "Tu iPhone ya ha recogido este borrador: cámbialo en su Bandeja.",
    } as Record<string, string>,
    equipoCompartidoCorto: "ordenador compartido",
    recogidoToast: "Tu iPhone ya lo ha recogido: lo verás en su Bandeja.",
  },
  csv: {
    cortado: (n: number) => `Se han exportado los ${n} más recientes. Para el resto, acota el período o los filtros.`,
  },
  qr: {
    visto: "Tu iPhone ha leído el código. Confírmalo ahí con Face ID.",
    caducado: "El código ha caducado.",
  },
  grp: {
    menosPagos: "Menos pagos entre vosotros",
  },
};
