import { test } from "node:test";
import assert from "node:assert/strict";
import { ApiError, createApi, filenameFrom, toBase64 } from "../src/api.js";

function fakeFetch(responses) {
  const calls = [];
  const impl = async (url, init) => {
    calls.push({ url, init });
    const r = responses.shift();
    return {
      status: r.status,
      ok: r.status >= 200 && r.status < 300,
      headers: { get: (name) => (r.headers || {})[name.toLowerCase()] || null },
      json: async () => {
        if (r.json === undefined) throw new Error("no json");
        return r.json;
      },
      arrayBuffer: async () => r.body,
    };
  };
  return { impl, calls };
}

test("sends the token header, never cookies, to the v1 base", async () => {
  const { impl, calls } = fakeFetch([{ status: 200, json: { user: { name: "N" } } }]);
  const api = createApi({ origin: "http://localhost:3000/", token: "seera_x", fetchImpl: impl });
  const me = await api.me();
  assert.equal(me.user.name, "N");
  assert.equal(calls[0].url, "http://localhost:3000/api/extension/v1/me");
  assert.equal(calls[0].init.headers["X-Seera-Token"], "seera_x");
  assert.equal(calls[0].init.credentials, "omit");
  assert.equal(calls[0].init.headers.Authorization, undefined);
});

test("unknown origins fall back to the default origin", async () => {
  const { impl, calls } = fakeFetch([{ status: 204 }]);
  await createApi({ origin: "https://evil.example", token: "t", fetchImpl: impl }).next();
  assert.equal(calls[0].url, "https://cvcrft.com/api/extension/v1/applications/next");
});

test("204 from next is null; 200 unwraps application", async () => {
  const { impl } = fakeFetch([{ status: 204 }, { status: 200, json: { application: { id: 5 } } }]);
  const api = createApi({ origin: "https://cvcrft.com", token: "t", fetchImpl: impl });
  assert.equal(await api.next(), null);
  assert.deepEqual(await api.next(), { id: 5 });
});

test("JSON errors become ApiError(status, code)", async () => {
  const { impl } = fakeFetch([
    { status: 429, json: { error: "daily_cap_reached", message: "Cap" } },
    { status: 500 },
  ]);
  const api = createApi({ origin: "https://cvcrft.com", token: "t", fetchImpl: impl });
  await assert.rejects(api.next(), (e) => e instanceof ApiError && e.status === 429 && e.code === "daily_cap_reached");
  await assert.rejects(api.me(), (e) => e instanceof ApiError && e.status === 500 && e.code === "http_500");
});

test("network failures and missing tokens", async () => {
  const api = createApi({ origin: "https://cvcrft.com", token: "t", fetchImpl: async () => { throw new Error("offline"); } });
  await assert.rejects(api.me(), (e) => e.status === 0 && e.code === "network");
  await assert.rejects(createApi({ origin: "", token: "" , fetchImpl: async () => null }).me(), (e) => e.code === "unauthorized");
});

test("answers and update send JSON bodies", async () => {
  const { impl, calls } = fakeFetch([
    { status: 200, json: { answers: [] } },
    { status: 200, json: { application: {}, today: {} } },
  ]);
  const api = createApi({ origin: "https://cvcrft.com", token: "t", fetchImpl: impl });
  await api.answers(7, [{ id: "q1" }]);
  await api.update(7, { status: "submitted" });
  assert.equal(calls[0].init.method, "POST");
  assert.equal(calls[0].url, "https://cvcrft.com/api/extension/v1/applications/7/answers");
  assert.deepEqual(JSON.parse(calls[0].init.body), { questions: [{ id: "q1" }] });
  assert.equal(calls[0].init.headers["Content-Type"], "application/json");
  assert.equal(calls[1].init.method, "PATCH");
});

test("resume pdf: filename and base64", async () => {
  const bytes = new TextEncoder().encode("%PDF-1.4 hi").buffer;
  const { impl } = fakeFetch([
    { status: 200, headers: { "content-disposition": 'attachment; filename="Nasser_CV.pdf"' }, body: bytes },
  ]);
  const pdf = await createApi({ origin: "https://cvcrft.com", token: "t", fetchImpl: impl }).resumePdf();
  assert.equal(pdf.filename, "Nasser_CV.pdf");
  assert.equal(Buffer.from(pdf.base64, "base64").toString(), "%PDF-1.4 hi");
  assert.equal(filenameFrom("attachment; filename*=UTF-8''%D9%86_CV.pdf", "x"), "ن_CV.pdf");
  assert.equal(filenameFrom(null, "CV.pdf"), "CV.pdf");
  assert.equal(toBase64(new Uint8Array([1, 2, 3]).buffer), "AQID");
});
