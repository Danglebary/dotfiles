---
paths:
  - "**/*.{ts,tsx,mts,cts}"
  - "**/tsconfig*.json"
---

# TypeScript: HTTP clients

- **Accept documented statuses via axios `validateStatus`.** Configure `validateStatus` to return true for the documented status codes, so axios hands them back as data instead of throwing; the caller branches on `response.status` explicitly, and statuses outside the documented set remain exceptional. This is External APIs' documented-errors-never-throw rule in axios.
- **Auth headers are listed in axios `sensitiveHeaders`.** When a request authenticates via a header (`Authorization`, `X-API-Key`, …), name that header in the request's `sensitiveHeaders` config so the Node adapter strips it when following a redirect to a different origin — the credential never travels to an origin the integration didn't name. (Same-origin redirects keep it; with `maxRedirects: 0` it is moot.)
- **…and in `redact`.** The same secret-bearing keys go in the request's `redact` config, so a serialized `AxiosError.toJSON()` masks them — errors end up in logs, and this keeps Observability's no-sensitive-data rule intact on that path. `redact` affects error serialization only; it changes nothing about the request itself.
- **`responseType` and `responseEncoding` are always set on outbound requests.** The call site states the shape and encoding it expects back instead of leaning on axios defaults — Tooling's pass-options-explicitly rule at the HTTP surface, and the known parse that the boundary `assertSchema` then validates against.
