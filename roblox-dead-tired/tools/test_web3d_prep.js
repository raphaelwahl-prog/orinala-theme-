const fs = require("fs"), path = require("path");
const DIR = process.env.TMP_TEST_DIR || __dirname;
const SRC = path.join(__dirname, "..", "web");
let html = fs.readFileSync(path.join(SRC, "dead-tired-3d.html"), "utf8");
const before = html;
html = html.replace("https://cdn.jsdelivr.net/npm/three@0.136.0/build/three.min.js", "./three.min.js");
if (html === before) throw new Error("le src de three.js n'a pas été trouvé");
html = html.replace(/<link[^>]*fonts\.googleapis[^>]*>\s*/g, "");
fs.writeFileSync(path.join(DIR, "page.html"),
  "<!doctype html><html lang=fr><head><meta charset=utf-8><meta name=viewport content=\"width=device-width,initial-scale=1\"></head><body>" + html + "</body></html>");
fs.copyFileSync(path.join(DIR, "node_modules/three/build/three.min.js"), path.join(DIR, "three.min.js"));
console.log("page.html prête (" + fs.statSync(path.join(DIR,"page.html")).size + " octets)");
