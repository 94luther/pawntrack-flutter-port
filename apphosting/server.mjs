import { createReadStream, existsSync, statSync } from "node:fs";
import { createServer } from "node:http";
import { extname, join, normalize, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";

import { handleApiRequest, runtimeConfig } from "./googleSheetsFirestoreBridge.mjs";

const __dirname = resolve(fileURLToPath(new URL(".", import.meta.url)));
const publicRoot = resolve(__dirname, "public");
const port = Number(process.env.PORT || 8080);

const contentTypes = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".wasm": "application/wasm",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon",
  ".otf": "font/otf",
  ".ttf": "font/ttf",
  ".woff": "font/woff",
  ".woff2": "font/woff2"
};

function resolveStaticPath(requestUrl) {
  const pathname = decodeURIComponent(new URL(requestUrl, "http://localhost").pathname);
  const candidate = normalize(join(publicRoot, pathname));
  if (!candidate.startsWith(publicRoot + sep) && candidate !== publicRoot) return null;
  if (existsSync(candidate) && statSync(candidate).isFile()) return candidate;
  return join(publicRoot, "index.html");
}

function serveStatic(req, res) {
  const file = resolveStaticPath(req.url || "/");
  if (!file || !existsSync(file)) {
    res.writeHead(404, { "content-type": "text/plain; charset=utf-8" });
    res.end("Not found");
    return;
  }
  const extension = extname(file).toLowerCase();
  res.writeHead(200, {
    "content-type": contentTypes[extension] || "application/octet-stream",
    "cache-control": extension === ".html" ? "no-store" : "public, max-age=3600"
  });
  if (req.method === "HEAD") {
    res.end();
    return;
  }
  createReadStream(file).pipe(res);
}

createServer((req, res) => {
  const pathname = new URL(req.url || "/", "http://localhost").pathname;
  if (pathname.startsWith("/api/")) {
    handleApiRequest(req, res);
    return;
  }
  serveStatic(req, res);
}).listen(port, () => {
  console.log(`PawnTrack App Hosting server listening on ${port}`);
  console.log(`Firestore project ${runtimeConfig.firebaseProjectId}, bucket ${runtimeConfig.firebaseStorageBucket}`);
});
