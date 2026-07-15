/**
 * Envelopes de error OpenAI-compatibles.
 *
 * CRÍTICO: el SDK MacPaw/OpenAI ignora el status HTTP ante respuestas no-2xx y solo sabe
 * decodificar `{"error":{message,type,param,code}}` (struct APIError). Por eso TODOS los
 * errores propios del gateway (attest/cuota/Pro) se devuelven en ese shape, con un `type`
 * discriminante que el cliente iOS mapea a sus errores tipados.
 * Ref: URLSessionProtocol+MakeDataTask.swift:30-34 y APIError.swift:19-23 del SDK.
 */

export type YalaErrorType =
  | "yala_attest_required"
  | "yala_attest_invalid"
  | "yala_attest_unknown_key"
  | "yala_pro_required"
  | "yala_quota_daily"
  | "yala_quota_burst"
  | "yala_unavailable"
  | "yala_bad_request"
  | "yala_account_reverting"
  | "yala_rpc_error";

interface OpenAIErrorBody {
  error: {
    message: string;
    type: string;
    param: string | null;
    code: string | null;
  };
}

export function errorBody(type: YalaErrorType, message: string, code?: string): OpenAIErrorBody {
  return { error: { message, type, param: null, code: code ?? type } };
}

/** Respuesta de error OpenAI-compatible. `extraHeaders` p.ej. { "X-Yala-Limit": "daily" }. */
export function jsonError(
  type: YalaErrorType,
  message: string,
  status: number,
  extraHeaders?: Record<string, string>,
): Response {
  // Metadata-only (sin bodies): tipo + status + motivo. Útil para diagnóstico/monitoreo.
  console.log(`[gw-err] ${status} ${type}: ${message}`);
  return new Response(JSON.stringify(errorBody(type, message)), {
    status,
    headers: { "content-type": "application/json", ...(extraHeaders ?? {}) },
  });
}
