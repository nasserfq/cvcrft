// Client for the Seera extension API (plan section 3.3). Used by the service
// worker and the popup only; content scripts never call it directly.
import { API_PATH, normaliseOrigin } from "./config.js";

export class ApiError extends Error {
  constructor(status, code, message) {
    super(message || code);
    this.name = "ApiError";
    this.status = status;
    this.code = code;
  }
}

export function toBase64(buffer) {
  const bytes = new Uint8Array(buffer);
  let binary = "";
  const chunk = 0x8000;
  for (let i = 0; i < bytes.length; i += chunk) {
    binary += String.fromCharCode.apply(null, bytes.subarray(i, i + chunk));
  }
  return btoa(binary);
}

export function filenameFrom(disposition, fallback) {
  const header = String(disposition || "");
  const star = header.match(/filename\*\s*=\s*(?:UTF-8'')?([^;]+)/i);
  if (star) {
    try {
      return decodeURIComponent(star[1].trim().replace(/^"|"$/g, ""));
    } catch (_e) {
      // fall through to the plain filename
    }
  }
  const plain = header.match(/filename\s*=\s*"?([^";]+)"?/i);
  return plain ? plain[1].trim() : fallback;
}

export function createApi({ origin, token, fetchImpl }) {
  const doFetch = fetchImpl || globalThis.fetch.bind(globalThis);
  const base = normaliseOrigin(origin) + API_PATH;

  async function request(method, path, { body, raw } = {}) {
    if (!token) throw new ApiError(401, "unauthorized", "No token");
    const headers = { "X-Seera-Token": token, Accept: raw ? "application/pdf" : "application/json" };
    const init = { method, headers, credentials: "omit", cache: "no-store" };
    if (body !== undefined) {
      headers["Content-Type"] = "application/json";
      init.body = JSON.stringify(body);
    }
    let res;
    try {
      res = await doFetch(base + path, init);
    } catch (e) {
      throw new ApiError(0, "network", e && e.message ? e.message : "Network error");
    }
    if (res.status === 204) return null;
    if (!res.ok) {
      let code = "http_" + res.status;
      let message = "";
      try {
        const data = await res.json();
        if (data && data.error) code = String(data.error);
        if (data && data.message) message = String(data.message);
      } catch (_e) {
        // non-JSON error body
      }
      throw new ApiError(res.status, code, message || code);
    }
    if (raw) return res;
    try {
      return await res.json();
    } catch (_e) {
      throw new ApiError(res.status, "invalid_json", "Invalid JSON from server");
    }
  }

  return {
    me: () => request("GET", "/me"),
    profile: () => request("GET", "/profile"),
    async resumePdf() {
      const res = await request("GET", "/resume.pdf", { raw: true });
      const buffer = await res.arrayBuffer();
      return {
        filename: filenameFrom(res.headers.get("Content-Disposition"), "CV.pdf"),
        base64: toBase64(buffer),
      };
    },
    async next() {
      const data = await request("GET", "/applications/next");
      return data ? data.application : null;
    },
    answers: (id, questions) => request("POST", `/applications/${encodeURIComponent(id)}/answers`, { body: { questions } }),
    update: (id, body) => request("PATCH", `/applications/${encodeURIComponent(id)}`, { body }),
  };
}
