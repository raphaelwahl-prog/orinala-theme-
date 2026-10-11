// Captures du jeu navigateur : une par zone, plus l'écran-titre.
//
//   node tools/shots_web.js [dossier]
//
// Trois précautions apprises à la dure sur le prototype, sinon les images ne
// montrent pas ce qu'on veut :
//   · figer la partie (G.running = false) avant de capturer, sinon un monstre
//     attrape le joueur au milieu de la pose ;
//   · remettre à zéro le voile rouge, les bandeaux et le cri, qui restent
//     affichés de la scène précédente ;
//   · placer la caméra à la main dans un endroit dégagé, et RENDRE une fois
//     juste avant la capture (le tampon WebGL est invalide après composition).

const { chromium } = require("/tmp/node_modules/playwright");
const fs = require("fs");
const path = require("path");
const http = require("http");

const GAME = path.resolve(__dirname, "..", "web", "sleep-or-die.html");
const THREE_LOCAL = "/tmp/threejs/package/build/three.min.js";
const OUT = process.argv[2] || "/tmp/sod-shots";
const PORT = 8732;

function serve() {
  const html = fs.readFileSync(GAME, "utf8")
    .replace(/<script src="https:\/\/cdnjs[^"]+"><\/script>/,
      '<script src="/three.min.js"></script>')
    .replace(/<link rel="stylesheet" href="https:\/\/fonts\.googleapis[^"]*">/, "");
  return http.createServer((req, res) => {
    if (req.url.startsWith("/three.min.js")) {
      res.writeHead(200, { "content-type": "application/javascript" });
      res.end(fs.readFileSync(THREE_LOCAL));
    } else {
      res.writeHead(200, { "content-type": "text/html; charset=utf-8" });
      res.end(html);
    }
  }).listen(PORT);
}

async function main() {
  fs.mkdirSync(OUT, { recursive: true });
  const server = serve();
  const browser = await chromium.launch({
    executablePath: "/opt/pw-browsers/chromium-1194/chrome-linux/chrome",
    args: ["--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--no-sandbox"],
  });
  const page = await browser.newPage({ viewport: { width: 1280, height: 760 } });
  await page.goto(`http://127.0.0.1:${PORT}/`, { waitUntil: "load" });
  await page.waitForTimeout(1200);

  await page.screenshot({ path: path.join(OUT, "00-titre.png") });
  console.log("00-titre.png");

  await page.click("#b-play");
  await page.waitForTimeout(1400);

  const zones = await page.evaluate(() => ZONES.map(z => ({ id: z.id, order: z.order })));
  for (const z of zones) {
    // Chaque zone : on y voyage, on pose la caméra devant un refuge, et on
    // place le monstre à bonne distance pour qu'il soit dans le cadre.
    await page.evaluate((zid) => {
      if (G.zone === zid) travel(zid === "street" ? "sewers" : "street");
      travel(zid);
      for (const id in MONSTERS) G.seen[id] = true;
      closeSheet();
      // Devant le premier refuge, légèrement en retrait.
      const s = shelters[0];
      G.px = s.x; G.pz = s.z + s.d + 6;
      G.yaw = 0; G.pitch = -0.18;
      // Le monstre, à 26 studs, dans l'axe du regard.
      if (G.beasts[0]) {
        const b = G.beasts[0];
        b.x = s.x + 4; b.z = s.z - 12;
        b.mode = "patrol"; b.stun = 0; b.path = [];
        b.obj.visible = true;
      }
      // On nettoie ce qui traîne de la scène précédente.
      G.shoutUntil = 0; G.toasts = []; drawToasts();
      document.getElementById("tint").style.opacity = "0";
      document.getElementById("shout").hidden = true;
      G.dead = 0; G.shake = 0;
    }, z.id);
    // Quelques images pour que la lumière, les ombres et le brouillard
    // atteignent leur valeur cible (le brouillard est interpolé).
    await page.waitForTimeout(1100);
    await page.evaluate(() => {
      // On fige AVANT de nettoyer : sinon le monstre repère le joueur pendant
      // l'attente, le cri « IL T'A VU » revient et la vignette rouge teinte
      // toute l'image en rose. C'est ce qui avait gâché la première série.
      G.running = false;
      G.shoutUntil = 0; G.toasts = []; drawToasts();
      document.getElementById("shout").hidden = true;
      document.getElementById("tint").style.opacity = "0";
      document.getElementById("vig").classList.remove("hot");
      renderer.render(scene, camera);
    });
    const name = `${String(z.order).padStart(2, "0")}-${z.id}.png`;
    await page.screenshot({ path: path.join(OUT, name) });
    console.log(name);
    await page.evaluate(() => { G.running = true; });
  }

  // Et une vue en train de dormir, avec le bandeau de session.
  await page.evaluate(() => {
    travel("street");
    for (const id in MONSTERS) G.seen[id] = true;
    closeSheet(); G.running = true;
    G.px = shelters[0].x; G.pz = shelters[0].z;
    trySleep(shelters[0]);
    G.graceLeft = 0; G.unbanked = 2340; G.earnedHere = 2340;
    G.yaw = 0.7;
  });
  await page.waitForTimeout(1200);
  await page.evaluate(() => { G.running = false; renderer.render(scene, camera); });
  await page.screenshot({ path: path.join(OUT, "08-sommeil.png") });
  console.log("08-sommeil.png");

  await browser.close();
  server.close();
  console.log("→ " + OUT);
}

main().catch((e) => { console.log("PLANTAGE : " + e.stack); process.exit(1); });
