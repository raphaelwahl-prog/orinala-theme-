const { chromium } = require("playwright");
const path = require("path");
(async () => {
  const b = await chromium.launch({ executablePath: "/opt/pw-browsers/chromium-1194/chrome-linux/chrome",
    args: ["--use-gl=angle","--use-angle=swiftshader","--enable-unsafe-swiftshader","--no-sandbox"] });
  const p = await b.newPage({ viewport: { width: 1280, height: 720 } });
  p.on("pageerror", e => console.log("ERREUR", e.message));
  await p.goto("file://" + path.join(__dirname, "page.html"));
  await p.waitForTimeout(900);
  await p.click("#b-play"); await p.waitForTimeout(400);
  await p.evaluate(() => { G.totalBanked = 60000; G.cash = 18400; refreshBeds(); G.phase = "night"; G.phaseLeft = 121; G.night = 4; });

  const scene = async (name, setup) => {
    await p.evaluate(async (setup) => {
      closeSheet(); G.running = true; G.dead = 0; clearBeasts(); G.shake = 0;
      G.shoutUntil = 0; G.toasts = []; drawToasts();
      document.getElementById("tint").style.opacity = "0";
      G.seen = { watchman: 1, crawler: 1, mimic: 1, starved: 1 };
      eval(setup);
      for (let i = 0; i < 4; i++) await new Promise(r => requestAnimationFrame(r));
      // on gèle la simulation : sinon la créature attrape le joueur pendant
      // que la capture s'écrit, et toutes les images finissent en rouge.
      G.running = false;
    }, setup);
    await p.waitForTimeout(260);
    await p.screenshot({ path: path.join(__dirname, name) });
    console.log("capture", name);
  };

  await scene("A-cave.png", `
    const b = beds.find(x => x.tier === 3);
    G.px = b.x - 6; G.pz = b.z + 6; G.yaw = -0.5; G.pitch = -0.14; G.unbanked = 860; G.stage = 1;`);

  await scene("B-rampante.png", `
    const b = beds.find(x => x.tier === 3);
    G.px = b.x + 7; G.pz = b.z + 10; G.yaw = 0.35; G.pitch = -0.12; G.stage = 1; G.unbanked = 3120;
    spawnBeast(BEASTS[3], null, true);
    G.beasts[0].x = b.x - 4; G.beasts[0].z = b.z - 6; G.beasts[0].mode = "hunt"; G.beasts[0].angle = Math.PI;
    G.shoutText = "IL ARRIVE — COURS"; G.shoutUntil = G.time + 3;`);

  await scene("C-mime.png", `
    const b = beds.find(x => x.tier === 4);
    G.px = b.x + 6; G.pz = b.z + 9; G.yaw = 0.4; G.pitch = -0.1; G.stage = 2; G.unbanked = 7400;
    spawnBeast(BEASTS[4], null, true);
    G.beasts[0].x = b.x - 5; G.beasts[0].z = b.z - 7; G.beasts[0].mode = "hunt"; G.beasts[0].angle = Math.PI;`);

  await scene("D-nid.png", `
    const b = beds.find(x => x.tier === 5);
    G.px = b.x + 8; G.pz = b.z + 12; G.yaw = 0.5; G.pitch = -0.1; G.stage = 3; G.unbanked = 21500;
    spawnBeast(BEASTS[5], null, true);
    G.beasts[0].x = b.x - 6; G.beasts[0].z = b.z - 8; G.beasts[0].mode = "hunt"; G.beasts[0].angle = Math.PI;`);

  await scene("E-dortoir.png", `
    const b = beds.find(x => x.tier === 1);
    G.px = b.x + 5; G.pz = b.z + 4; G.yaw = 0.35; G.pitch = -0.13; G.stage = 0; G.unbanked = 0;`);

  await b.close();
})();
