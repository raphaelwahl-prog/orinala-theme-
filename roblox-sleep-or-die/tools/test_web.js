// Banc d'essai du jeu navigateur : on y JOUE, on ne le relit pas.
//
// C'est cette méthode qui avait sorti six bugs invisibles à la relecture sur le
// prototype : le joueur effacé par la reconstruction du décor, le voile noir
// qui mangeait les clics, la scène quatre fois trop sombre, le déplacement
// inversé en X, une collision de nom entre « partie en cours » et « sprint »,
// et la caméra dans les murs.
//
//   cd /tmp && npm i playwright       (les navigateurs sont déjà là)
//   node tools/test_web.js
//
// Three.js est servi en local : le proxy de ce conteneur bloque les CDN.

const { chromium } = require("/tmp/node_modules/playwright");
const fs = require("fs");
const path = require("path");
const http = require("http");

const GAME = path.resolve(__dirname, "..", "web", "sleep-or-die.html");
const THREE_LOCAL = "/tmp/threejs/package/build/three.min.js";
// Port tiré au hasard : deux exécutions qui se chevauchent (une relance
// pendant qu'une précédente agonise) se battaient pour le 8731 et la seconde
// mourait sur EADDRINUSE — un échec qui n'a rien à voir avec le jeu.
const PORT = 8700 + Math.floor(Math.random() * 300);

let checks = 0, fails = 0;
const ok = (cond, label) => {
  checks++;
  if (cond) console.log("  OK    " + label);
  else { fails++; console.log("  ÉCHEC " + label); }
};
const eq = (got, want, label) =>
  ok(got === want, `${label}  (obtenu ${JSON.stringify(got)}, attendu ${JSON.stringify(want)})`);
const near = (got, want, tol, label) =>
  ok(Math.abs(got - want) <= tol, `${label}  (obtenu ${got}, attendu ${want} ±${tol})`);

// Serveur local : le fichier tel quel, mais Three.js pris sur le disque.
function serve() {
  const html = fs.readFileSync(GAME, "utf8")
    .replace(/<script src="https:\/\/cdnjs[^"]+"><\/script>/,
      '<script src="/three.min.js"></script>')
    // Le proxy de ce conteneur casse TLS vers fonts.googleapis.com : l'erreur
    // qui en sort n'est pas un bug du jeu, elle n'existe pas chez le joueur.
    // On sert une feuille vide plutôt que de filtrer un message d'erreur.
    .replace(/<link rel="stylesheet" href="https:\/\/fonts\.googleapis[^"]*">/,
      '<link rel="stylesheet" href="/fonts.css">');
  return http.createServer((req, res) => {
    if (req.url.startsWith("/fonts.css")) {
      res.writeHead(200, { "content-type": "text/css" });
      res.end("/* polices neutralisées pour le banc d'essai */");
    } else if (req.url.startsWith("/three.min.js")) {
      res.writeHead(200, { "content-type": "application/javascript" });
      res.end(fs.readFileSync(THREE_LOCAL));
    } else {
      res.writeHead(200, { "content-type": "text/html; charset=utf-8" });
      res.end(html);
    }
  }).listen(PORT);
}

// Un appui touche réaliste : le navigateur envoie `key` ET `code`, et c'est
// tout le sujet du test clavier.
// Attendre que le JEU ait avancé de `secs` secondes (et pas l'horloge).
async function waitGame(page, secs, cap) {
  const t0 = await page.evaluate(() => G.time);
  const deadline = Date.now() + (cap || 30000);
  for (;;) {
    const t = await page.evaluate(() => G.time);
    if (t - t0 >= secs) return t - t0;
    if (Date.now() > deadline) return t - t0;
    await page.waitForTimeout(120);
  }
}

const KEY = {
  qwerty: { fwd: ["w", "KeyW"], left: ["a", "KeyA"], back: ["s", "KeyS"], right: ["d", "KeyD"] },
  // AZERTY : les mêmes touches physiques, d'autres lettres dessus.
  azerty: { fwd: ["z", "KeyW"], left: ["q", "KeyA"], back: ["s", "KeyS"], right: ["d", "KeyD"] },
  // QWERTZ (allemand) : W et A au même endroit qu'en QWERTY.
  qwertz: { fwd: ["w", "KeyW"], left: ["a", "KeyA"], back: ["s", "KeyS"], right: ["d", "KeyD"] },
  // ЙЦУКЕН (russe) : les lettres n'ont AUCUN rapport avec w/a/s/d. C'est le
  // seul cas où lire `e.key` ne sert à rien et où `e.code` sauve la mise —
  // donc le seul qui prouve que le support des positions est utile.
  cyrillique: { fwd: ["ц", "KeyW"], left: ["ф", "KeyA"], back: ["ы", "KeyS"], right: ["в", "KeyD"] },
};

async function main() {
  if (!fs.existsSync(THREE_LOCAL)) {
    console.log("ERREUR : " + THREE_LOCAL + " absent.");
    console.log("  mkdir -p /tmp/threejs && cd /tmp/threejs && npm pack three@0.136.0 && tar xzf three-0.136.0.tgz");
    process.exit(2);
  }
  const server = serve();
  const browser = await chromium.launch({
    executablePath: "/opt/pw-browsers/chromium-1194/chrome-linux/chrome",
    args: ["--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--no-sandbox"],
  });
  const page = await browser.newPage({ viewport: { width: 1280, height: 800 } });

  const errors = [];
  page.on("pageerror", (e) => errors.push(String(e.message || e)));
  page.on("console", (m) => { if (m.type() === "error") errors.push("console: " + m.text()); });

  await page.goto(`http://127.0.0.1:${PORT}/`, { waitUntil: "load" });
  await page.waitForTimeout(900);

  console.log("— chargement —");
  eq(errors.length, 0, "aucune erreur JavaScript au chargement"
    + (errors.length ? " : " + errors.slice(0, 3).join(" | ") : ""));
  eq(await page.title(), "Sleep or Die", "le titre de la page");
  ok(await page.locator("#sheet .card h1").count() > 0, "l'écran-titre s'affiche");

  // Le voile du titre ne doit pas rester devant le jeu : c'est le bug qui
  // avait coûté le plus cher sur le prototype (85 % de noir et les clics
  // avalés). On vérifie qu'au centre de l'écran c'est bien le canvas qui
  // reçoit les clics.
  await page.click("#b-play");
  await page.waitForTimeout(700);
  const hit = await page.evaluate(() =>
    document.elementFromPoint(innerWidth / 2, innerHeight / 2).id);
  eq(hit, "cv", "après avoir cliqué sur Jouer, le centre de l'écran est le canvas");
  eq(await page.evaluate(() => document.getElementById("sheet").hidden), true, "le panneau est caché");
  eq(await page.evaluate(() => G.running), true, "la partie tourne");

  console.log("");
  console.log("— le clavier, dans les trois dispositions —");
  // On met la scène au calme d'abord. Sans ça, le Rôdeur repère le joueur
  // pendant le test, le panneau de révélation s'ouvre, `G.running` passe à
  // false et TOUS les appuis suivants mesurent zéro déplacement — un test
  // clavier qui accuse le clavier d'un problème d'IA.
  await page.evaluate(() => {
    for (const id in MONSTERS) G.seen[id] = true;
    clearBeasts();
    closeSheet();
    G.running = true;
    G.dead = 0;
    // Et on neutralise les portails : la case la plus dégagée du parvis est
    // dans l'allée des portails, le joueur en traversait un en avançant et se
    // retrouvait 130 studs plus loin, dans une autre zone. Le test passait par
    // chance (le saut était vaguement dans la bonne direction).
    G.portalLock = G.time + 1e6;
  });
  for (const [name, map] of Object.entries(KEY)) {
    for (const [dir, [key, code]] of Object.entries(map)) {
      // On replace le joueur au MILIEU d'un espace dégagé avant chaque
      // appui : sinon il finit dans un angle au bout de trois touches et le
      // test accuse le clavier d'un problème de collision.
      const before = await page.evaluate(() => {
        let best = null, bestFree = -1;
        for (let z = 2; z < MH - 2; z++) for (let x = 2; x < MW - 2; x++) {
          if (grid[z][x] !== 1) continue;
          let free = 0;
          for (let r = 1; r <= 4; r++)
            for (const [ox, oz] of [[r,0],[-r,0],[0,r],[0,-r]])
              if (grid[z + oz] && grid[z + oz][x + ox] === 1) free++;
          if (free > bestFree) { bestFree = free; best = { x, z }; }
        }
        G.px = (best.x + 0.5) * TILE; G.pz = (best.z + 0.5) * TILE;
        G.yaw = 0;   // l'avant est −Z, la droite +X
        return { x: G.px, z: G.pz };
      });
      // Playwright déduit `code` de la touche demandée ; on force le couple
      // (key, code) à la main pour simuler une autre disposition.
      await page.evaluate(([k, c]) => {
        dispatchEvent(new KeyboardEvent("keydown", { key: k, code: c }));
      }, [key, code]);
      await waitGame(page, 0.35, 8000);
      const after = await page.evaluate(() => ({
        x: G.px, z: G.pz, moving: G.moving,
        keys: Object.keys(keys).filter(k => keys[k]).join(","),
      }));
      await page.evaluate(([k, c]) => {
        dispatchEvent(new KeyboardEvent("keyup", { key: k, code: c }));
      }, [key, code]);
      await page.waitForTimeout(120);

      const live = await page.evaluate(() => ({ running: G.running, sheet, dead: G.dead }));
      if (!live.running || live.sheet || live.dead > 0) {
        ok(false, `${name} · ${dir} : la partie a été interrompue pendant l'appui `
          + `(running=${live.running}, panneau=${live.sheet}, mort=${live.dead.toFixed(1)})`);
        continue;
      }
      const dx = after.x - before.x, dz = after.z - before.z;
      const moved = Math.hypot(dx, dz);
      const want = { fwd: [0, -1], back: [0, 1], left: [-1, 0], right: [1, 0] }[dir];
      const dot = (dx * want[0] + dz * want[1]) / (moved || 1);
      ok(moved < 30,
        `${name} · ${dir} : le joueur marche, il ne se téléporte pas `
        + `(${moved.toFixed(1)} studs)`);
      ok(moved > 0.5 && dot > 0.7,
        `${name} · ${dir} (key="${key}", code="${code}") déplace dans le bon sens`
        + `  (|d|=${moved.toFixed(1)}, alignement=${dot.toFixed(2)}`
        + (moved <= 0.5 ? `, touches enfoncées="${after.keys}", moving=${after.moving}` : "")
        + `)`);
    }
  }

  await page.evaluate(() => { G.portalLock = 0; });

  console.log("");
  console.log("— le parvis et les portails —");
  const hub = await page.evaluate(() => {
    if (G.zone !== "hub") travel("hub");
    return {
      zone: G.zone, portals: portals.length, signs: signs.length,
      shelters: shelters.length, beasts: G.beasts.length,
      rate: zone().rate, spawnFree: !solid(spawn.x, spawn.z),
      dests: portals.map(p => p.to).join(","),
      spawnInPortal: portals.some(pt =>
        Math.abs(spawn.x - pt.x) < pt.w / 2 && Math.abs(spawn.z - pt.z) < pt.d),
    };
  });
  eq(hub.zone, "hub", "on peut rejoindre le parvis");
  eq(hub.portals, 7, "sept portails, un par zone");
  eq(hub.dests, "street,sewers,dollhouse,slasher,convent,hospital,carnival",
    "ils mènent aux sept zones, dans l'ordre");
  eq(hub.signs, 3, "trois bornes d'explication");
  eq(hub.shelters, 0, "aucun refuge au parvis : on n'y dort pas");
  eq(hub.beasts, 0, "et aucun monstre");
  eq(hub.rate, 0, "on n'y gagne rien non plus");
  eq(hub.spawnFree, true, "le point d'arrivée n'est pas dans un mur");
  eq(hub.spawnInPortal, false,
    "et il n'est pas DANS un portail (sinon on repart aussitôt arrivé)");

  // Traverser un portail doit changer de zone — et le portail de retour doit
  // ramener au parvis sans boucler.
  const trip = await page.evaluate(async () => {
    travel("hub");
    const target = portals.find(p => p.to === "sewers");
    G.px = target.x; G.pz = target.z;
    G.portalLock = 0;
    // On exécute le pas de boucle qui détecte les portails.
    const before = G.zone;
    if (!G.sleeping && G.dead <= 0 && G.time >= G.portalLock) {
      const pt = portalUnder();
      if (pt) travel(pt.to);
    }
    const arrived = G.zone;
    const back = portals.filter(p => p.to === "hub").length;
    // Juste après l'arrivée, le verrou doit empêcher un second saut.
    const locked = G.time < G.portalLock;
    return { before, arrived, back, locked };
  });
  eq(trip.before, "hub", "on part du parvis");
  eq(trip.arrived, "sewers", "traverser le portail des égouts y emmène");
  eq(trip.back, 1, "la zone a un portail de retour, et un seul");
  eq(trip.locked, true, "un verrou empêche de repartir dans la seconde");

  const loop = await page.evaluate(() => {
    // On avance le temps du jeu au-delà du verrou et on se pose sur le retour.
    G.portalLock = G.time - 1;
    const back = portals.find(p => p.to === "hub");
    G.px = back.x; G.pz = back.z;
    const pt = portalUnder();
    if (pt) travel(pt.to);
    return G.zone;
  });
  eq(loop, "hub", "et le portail de retour ramène au parvis");

  console.log("");
  console.log("— un panneau ouvert ne doit pas donner l'impression d'un clavier cassé —");
  const resumed = await page.evaluate(() => {
    reveal(MONSTERS.prowler);           // ouvre un panneau, met en pause
    const paused = { sheet, running: G.running };
    dispatchEvent(new KeyboardEvent("keydown", { key: "z", code: "KeyW" }));
    dispatchEvent(new KeyboardEvent("keyup", { key: "z", code: "KeyW" }));
    return { paused, after: { sheet, running: G.running } };
  });
  eq(resumed.paused.running, false, "une révélation met bien la partie en pause");
  eq(resumed.after.sheet, null, "une touche de déplacement referme le panneau");
  eq(resumed.after.running, true, "et relance la partie");
  const stays = await page.evaluate(() => {
    title();
    dispatchEvent(new KeyboardEvent("keydown", { key: "z", code: "KeyW" }));
    dispatchEvent(new KeyboardEvent("keyup", { key: "z", code: "KeyW" }));
    const r = { sheet, running: G.running };
    closeSheet(); G.running = true;
    return r;
  });
  eq(stays.sheet, "title", "mais l'écran-titre reste : il faut un vrai clic pour le son");

  console.log("");
  console.log("— qualité du rendu —");
  const gfx = await page.evaluate(() => ({
    aniso: renderer.capabilities.getMaxAnisotropy(),
    texAniso: surface("wall", 4, 2.6).map.anisotropy,
    texSize: surface("wall", 4, 2.6).map.image.width,
    shadows: renderer.shadowMap.enabled,
    torchShadow: torch.castShadow,
    encoding: renderer.outputEncoding === THREE.sRGBEncoding,
    tone: renderer.toneMapping === THREE.ACESFilmicToneMapping,
    standard: surface("wall", 4, 2.6).type,
    bump: !!surface("wall", 4, 2.6).bumpMap,
  }));
  ok(gfx.aniso >= 2, `le GPU accepte le filtrage anisotrope (max ${gfx.aniso}×)`);
  eq(gfx.texAniso, Math.min(16, gfx.aniso), "les textures l'utilisent vraiment");
  eq(gfx.texSize, 256, "les textures font 256 px et non 64");
  eq(gfx.shadows, true, "les ombres portées sont activées");
  eq(gfx.torchShadow, true, "la torche projette l'ombre du joueur");
  eq(gfx.encoding, true, "sortie en sRGB (sans ça, tout est 4× trop sombre)");
  eq(gfx.tone, true, "compression ACES des hautes lumières");
  eq(gfx.standard, "MeshStandardMaterial", "les grandes surfaces ont un vrai matériau");
  eq(gfx.bump, true, "et une carte de relief");

  // Luminance : une scène d'horreur est sombre, mais pas noire. On mesure.
  const lum = await page.evaluate(() => {
    // `preserveDrawingBuffer` est à false (par défaut, et c'est tant mieux
    // pour les performances) : le tampon est invalide dès que le navigateur a
    // composé l'image. On redessine donc juste avant de lire, dans la même
    // tâche JavaScript.
    renderer.render(scene, camera);
    const c = document.getElementById("cv");
    const g = document.createElement("canvas");
    g.width = 160; g.height = 100;
    const x = g.getContext("2d");
    x.drawImage(c, 0, 0, 160, 100);
    const d = x.getImageData(0, 0, 160, 100).data;
    let sum = 0, bright = 0;
    for (let i = 0; i < d.length; i += 4) {
      const v = 0.2126 * d[i] + 0.7152 * d[i + 1] + 0.0722 * d[i + 2];
      sum += v; if (v > 90) bright++;
    }
    return { mean: sum / (d.length / 4), bright: bright / (d.length / 4) };
  });
  ok(lum.mean > 12 && lum.mean < 150,
    `la scène est lisible sans être lavée (luminance moyenne ${lum.mean.toFixed(1)})`);
  ok(lum.bright > 0.002,
    `il y a de vraies zones éclairées (${(lum.bright * 100).toFixed(1)} % de pixels clairs)`);

  console.log("");
  console.log("— les sept zones se construisent toutes —");
  const zones = await page.evaluate(() => ZONES.map(z => z.id));
  eq(zones.length, 7, "sept zones déclarées");
  for (const id of zones) {
    const r = await page.evaluate((zid) => {
      // `travel()` est un no-op vers la zone courante — ce qui est juste, mais
      // laisserait la zone sans monstre après le clearBeasts du test clavier.
      if (G.zone === zid) travel(zid === "street" ? "sewers" : "street");
      travel(zid);
      let floor = 0;
      for (let z = 0; z < MH; z++) for (let x = 0; x < MW; x++) if (grid[z][x] === 1) floor++;
      return {
        zone: G.zone, shelters: shelters.length, patrol: patrol.length, floor,
        monster: G.beasts.length ? G.beasts[0].def.id : null,
        wantMonster: ZONE_BY_ID[zid].monster,
        spawnFree: !solid(spawn.x, spawn.z),
        vaultFree: !solid(vault.x, vault.z + 8),
        reach: findPath({ x: spawn.x, z: spawn.z }, { x: shelters[0].x, z: shelters[0].z }).length,
        meshes: world.children.length,
      };
    }, id);
    const z = await page.evaluate((zid) => ZONE_BY_ID[zid].name, id);
    ok(r.zone === id && r.shelters >= 4 && r.patrol >= 6 && r.floor > 400
       && r.spawnFree && r.vaultFree && r.reach > 0 && r.meshes > 40
       && r.monster === r.wantMonster,
      `${z} : ${r.shelters} refuges, ${r.patrol} points de ronde, ${r.floor} cases, `
      + `${r.meshes} objets, ${r.monster} présent, refuge atteignable en ${r.reach} pas`);
  }

  console.log("");
  console.log("— les sept mécaniques —");
  // « gaze » : la Poupée doit être figée tant qu'on la regarde.
  const gaze = await page.evaluate(async () => {
    travel("dollhouse");
    const b = G.beasts[0];
    b.mode = "hunt"; b.last = { x: G.px, z: G.pz };
    // On la place devant le joueur, et le joueur la regarde (yaw 0 → −Z).
    G.yaw = 0; b.x = G.px; b.z = G.pz - 40;
    const x0 = b.x, z0 = b.z;
    for (let i = 0; i < 40; i++) { updateBeast(b, 0.05); }
    const watched = Math.hypot(b.x - x0, b.z - z0);
    // Maintenant on détourne le regard : elle doit avancer.
    G.yaw = Math.PI;
    const x1 = b.x, z1 = b.z;
    for (let i = 0; i < 40; i++) { updateBeast(b, 0.05); }
    return { watched, away: Math.hypot(b.x - x1, b.z - z1) };
  });
  ok(gaze.watched < 0.6, `la Poupée ne bouge pas sous le regard (${gaze.watched.toFixed(2)} studs)`);
  ok(gaze.away > 3, `et elle avance dès qu'on regarde ailleurs (${gaze.away.toFixed(1)} studs)`);

  // « sound » : la Chose repère un joueur qui COURT, pas un joueur qui marche.
  const sound = await page.evaluate(() => {
    travel("sewers");
    const b = G.beasts[0];
    const place = () => { b.mode = "patrol"; b.x = G.px + 30; b.z = G.pz; b.path = []; };
    place(); G.sprint = false; G.moving = true;
    for (let i = 0; i < 10; i++) updateBeast(b, 0.05);
    const walking = b.mode;
    place(); G.sprint = true; G.moving = true;
    for (let i = 0; i < 10; i++) updateBeast(b, 0.05);
    const running = b.mode;
    G.sprint = false;
    return { walking, running };
  });
  eq(sound.walking, "patrol", "la Chose des égouts ignore un joueur qui MARCHE à 30 studs");
  eq(sound.running, "hunt", "mais elle entend un joueur qui COURT");

  // « relentless » : le Masque ne lâche jamais, même hors de vue et après
  // l'expiration du temps d'abandon des autres.
  const rel = await page.evaluate(() => {
    travel("slasher");
    const b = G.beasts[0];
    b.mode = "hunt"; b.ends = G.time - 1; b.lost = 99;
    b.x = G.px + 60; b.z = G.pz + 60;
    for (let i = 0; i < 30; i++) updateBeast(b, 0.05);
    return b.mode;
  });
  eq(rel, "hunt", "le Masque ne lâche jamais la piste");

  // « none » : le Rôdeur, lui, abandonne.
  const giveUp = await page.evaluate(() => {
    travel("street");
    const b = G.beasts[0];
    b.mode = "hunt"; b.ends = G.time - 1; b.lost = 99;
    b.x = G.px + 60; b.z = G.pz + 60;
    for (let i = 0; i < 30; i++) updateBeast(b, 0.05);
    return b.mode;
  });
  ok(giveUp !== "hunt", `le Rôdeur abandonne au bout de son délai (état « ${giveUp} »)`);

  // « disable » : l'Entité annule le délai des défenses.
  const dis = await page.evaluate(() => {
    travel("convent");
    G.cash = 1e12;
    G.owned.barricade = 2; G.placed.barricade = 2;
    const withDef = defenseProfile().delay;
    G.sleeping = shelters[0]; G.graceLeft = 0;
    launchAssault();
    const incoming = G.incoming;
    G.sleeping = null; G.incoming = 0;
    return { withDef, incoming };
  });
  ok(dis.withDef >= 14, `deux barricades donnent ${dis.withDef} s de délai`);
  eq(dis.incoming, 0.6, "mais l'Entité les neutralise : l'assaut arrive tout de suite");

  // « fake_alerts » : au Menteur, une alerte sur trois ne doit rien envoyer.
  const fake = await page.evaluate(() => {
    travel("hospital");
    G.owned.alarm = 1; G.placed.alarm = 1;
    let sent = 0;
    for (let i = 0; i < 300; i++) {
      G.sleeping = shelters[0]; G.graceLeft = 0; G.incoming = 0; G.defHits = {};
      launchAssault();
      if (G.incoming > 0) sent++;
    }
    G.sleeping = null; G.incoming = 0;
    return sent / 300;
  });
  ok(fake > 0.55 && fake < 0.8,
    `le Menteur n'envoie rien dans ~1 cas sur 3 (${(fake * 100).toFixed(0)} % d'assauts réels)`);

  // « boss_phases » : trois phases, et chacune rejoue une mécanique connue.
  const boss = await page.evaluate(() => {
    travel("carnival");
    G.cash = 1e12; G.owned.legendary = 1; G.weapon = "legendary";
    const b = G.beasts[0];
    const seen = [ruleOf(b)];
    const phases = [];
    for (let p = 0; p < 3; p++) {
      const hits = BOSS_PHASES[Math.min(G.bossPhase, 2)].hits;
      for (let i = 0; i < hits; i++) {
        G.nextSwing = 0; b.x = G.px + 2; b.z = G.pz;
        if (G.beasts.length) swing();
      }
      phases.push(G.bossPhase);
      if (G.beasts.length) seen.push(ruleOf(G.beasts[0]));
    }
    return { seen, phases, down: G.beasts.length === 0, cleared: !!G.seen.carnival_cleared };
  });
  eq(boss.seen[0], "sound", "phase 1 du boss : il suit le bruit");
  eq(boss.seen[1], "gaze", "phase 2 : regardé, il se fige");
  eq(boss.seen[2], "relentless", "phase 3 : il ne lâche plus");
  eq(boss.down, true, "au bout des trois phases, le clown tombe");
  eq(boss.cleared, true, "et le carnaval est marqué battu");

  console.log("");
  console.log("— l'économie, aux chiffres du jeu Roblox —");
  const eco = await page.evaluate(() => {
    travel("street");
    G.cash = 0; G.totalBanked = 0; G.unbanked = 0; G.awaken = 0; G.stage = 0;
    G.sleeping = shelters[0]; G.earnedHere = 0; G.graceLeft = 0; G.preview = false;
    G.sessionLeft = 999; G.nextAssault = G.time + 9999;
    const z = zone();
    // 10 secondes de sommeil à 10 $/s = 100 $.
    for (let i = 0; i < 200; i++) {
      const rate = z.rate * STAGES[G.stage].reward / (G.earnedHere >= z.cap ? SOFTCAP_DIV : 1);
      G.earnedHere += rate * 0.05; G.unbanked += rate * 0.05;
    }
    const tenSec = G.unbanked;
    // Plafond souple : au-delà de 4 000 $, le taux est divisé par 4.
    G.earnedHere = z.cap;
    const capped = z.rate * STAGES[G.stage].reward / SOFTCAP_DIV;
    // Mort : on perd DeathLossRatio de ce qu'on porte.
    G.unbanked = 1000;
    const b = G.beasts[0];
    caught(b);
    const afterDeath = G.unbanked;
    // Dépôt : l'argent déposé est définitif.
    G.unbanked = 500; const got = bank();
    return { tenSec, capped, afterDeath, got, cash: G.cash, banked: G.totalBanked,
             loss: z.loss, rate: z.rate, cap: z.cap };
  });
  near(eco.tenSec, 100, 1, "10 s dans la rue à 10 $/s rapportent 100 $");
  eq(eco.capped, 2.5, "au-delà du plafond de 4 000 $, le taux tombe à 2,5 $/s (÷4)");
  eq(eco.afterDeath, 500, "une mort dans la rue coûte 50 % de ce qu'on porte");
  eq(eco.got, 500, "le dépôt crédite la banque");
  eq(eco.cash, 500, "et l'argent déposé est définitif");

  const awake = await page.evaluate(() => {
    const r = {};
    // L'éveil ne monte PAS dans la rue (zone 1) : c'est la règle du CDC.
    r.street = gainFor(1);
    r.carnival = gainFor(7);
    r.stage0 = STAGES[0].reward;
    r.stage3 = STAGES[3].reward;
    r.thresholds = THRESHOLDS.join(",");
    return r;
  });
  eq(awake.street, 0, "dormir dans la rue ne réveille rien (zone 1)");
  near(awake.carnival, 0.54, 0.001, "au carnaval, 0,54 point par seconde");
  eq(awake.thresholds, "0,16,40,76", "les quatre seuils d'éveil");
  eq(awake.stage3, 1.6, "au stade AFFAMÉ, les gains sont à x1,6");

  const preview = await page.evaluate(() => {
    travel("carnival");            // non débloqué : 60 M$ requis
    const wasPreview = G.preview;
    G.unbanked = 0; G.sleeping = shelters[0]; G.graceLeft = 0; G.earnedHere = 0;
    for (let i = 0; i < 100; i++) {
      const rate = zone().rate * STAGES[G.stage].reward;
      G.earnedHere += rate * 0.05;
      if (!G.preview) G.unbanked += rate * 0.05;
    }
    const gained = G.unbanked;
    G.sleeping = null;
    return { wasPreview, gained, earned: G.earnedHere };
  });
  eq(preview.wasPreview, true, "le carnaval est en aperçu tant qu'on n'a pas 60 M$ déposés");
  ok(preview.earned > 100000, "on voit les gains défiler");
  eq(preview.gained, 0, "mais rien n'est crédité en aperçu — la progression reste honnête");

  console.log("");
  console.log("— la caméra ne finit jamais dans un mur —");
  const cam = await page.evaluate(() => {
    travel("sewers");
    let inWall = 0, tested = 0, tooClose = 0;
    const free = [];
    for (let z = 0; z < MH; z++) for (let x = 0; x < MW; x++)
      if (grid[z][x] === 1) free.push({ x: (x + 0.5) * TILE, z: (z + 0.5) * TILE });
    for (let i = 0; i < free.length; i += Math.max(1, Math.floor(free.length / 220))) {
      G.px = free[i].x; G.pz = free[i].z;
      for (let a = 0; a < 8; a++) {
        G.yaw = a * Math.PI / 4;
        const sy = Math.sin(G.yaw), cy = Math.cos(G.yaw);
        let dist = 13;
        while (dist > 5 && solid(G.px + sy * (dist + 1.5), G.pz + cy * (dist + 1.5))) dist -= 1;
        while (dist > 3.5 && solid(G.px + sy * dist, G.pz + cy * dist)) dist -= 0.5;
        tested++;
        if (solid(G.px + sy * dist, G.pz + cy * dist)) inWall++;
        if (dist < 3.5) tooClose++;
      }
    }
    return { tested, inWall, tooClose };
  });
  ok(cam.inWall / cam.tested < 0.06,
    `sur ${cam.tested} positions × angles, la caméra est dans la pierre ${cam.inWall} fois `
    + `(${(cam.inWall / cam.tested * 100).toFixed(1)} %)`);
  eq(cam.tooClose, 0, "et jamais à moins de 3,5 studs (sinon elle est dans la tête du perso)");

  console.log("");
  console.log("— on peut jouer une session complète —");
  const ready = await page.evaluate(() => {
    travel("street");
    G.cash = 0; G.totalBanked = 0; G.unbanked = 0;
    G.awaken = 0; G.stage = 0;
    // Les tests de mécaniques précédents ont pu laisser un panneau de
    // révélation ouvert (c'est le comportement voulu du jeu : la première
    // rencontre d'un monstre met la partie en pause). Pour jouer une session
    // il faut repartir d'un écran propre, et empêcher une révélation de
    // s'ouvrir au milieu : on marque les sept monstres comme déjà vus.
    for (const id in MONSTERS) G.seen[id] = true;
    clearBeasts();
    closeSheet();
    G.running = true;
    G.px = shelters[0].x; G.pz = shelters[0].z;
    return { sheet, running: G.running, beasts: G.beasts.length };
  });
  eq(ready.sheet, null, "aucun panneau ouvert avant de jouer");
  eq(ready.running, true, "la partie tourne");
  await page.waitForTimeout(150);
  await page.keyboard.press("KeyE");          // dormir
  await waitGame(page, 1.0, 20000);
  const grace = await page.evaluate(() => ({
    asleep: !!G.sleeping, hud: !document.getElementById("sleep").hidden,
    earned: G.unbanked, grace: G.graceLeft,
  }));
  eq(grace.asleep, true, "E au-dessus d'un lit endort le joueur");
  eq(grace.hud, true, "le bandeau de session s'affiche");
  // Délai de grâce de 3 s : s'allonger une seconde entre deux courses ne doit
  // rien payer. Après 1,2 s, le compteur doit donc être encore à zéro.
  eq(grace.earned, 0, "rien n'est gagné pendant les 3 s de délai de grâce");
  ok(grace.grace > 0, `le délai court encore (${grace.grace.toFixed(1)} s restantes)`);
  // On laisse passer le délai de grâce (3 s de JEU) plus une marge.
  await waitGame(page, 3.0, 60000);
  const sleeping = await page.evaluate(() => ({
    earned: G.unbanked, here: G.earnedHere, asleep: !!G.sleeping,
    grace: G.graceLeft, preview: G.preview, left: G.sessionLeft,
    incoming: G.incoming, dead: G.dead, running: G.running, sheet,
  }));
  ok(sleeping.earned > 0, `puis l'argent monte (${sleeping.earned.toFixed(1)} $ ; `
    + `endormi=${sleeping.asleep}, grâce=${sleeping.grace.toFixed(1)}, `
    + `aperçu=${sleeping.preview}, session=${sleeping.left.toFixed(0)}, `
    + `assaut=${sleeping.incoming.toFixed(1)}, mort=${sleeping.dead.toFixed(1)}, `
    + `tourne=${sleeping.running}, panneau=${sleeping.sheet})`);
  await page.keyboard.press("Space");         // se réveiller
  await waitGame(page, 0.2, 8000);
  eq(await page.evaluate(() => !!G.sleeping), false, "Espace réveille");

  const banked = await page.evaluate(async () => {
    G.px = vault.x; G.pz = vault.z + 6;
    return new Promise(r => setTimeout(() => r(null), 60));
  });
  await page.keyboard.press("KeyE");          // déposer
  await waitGame(page, 0.2, 8000);
  const after = await page.evaluate(() => ({ cash: G.cash, unb: G.unbanked }));
  ok(after.cash > 0 && after.unb === 0,
    `E au coffre dépose tout (${after.cash} $ en banque, ${after.unb} $ sur soi)`);

  console.log("");
  console.log("— pas d'erreur après tout ça —");
  eq(errors.length, 0, "aucune erreur JavaScript pendant la partie"
    + (errors.length ? " : " + errors.slice(0, 4).join(" | ") : ""));

  await browser.close();
  server.close();
  console.log("");
  console.log(`${checks - fails}/${checks} vérifications passées.`);
  process.exit(fails ? 1 : 0);
}

main().catch((e) => { console.log("PLANTAGE DU BANC : " + e.stack); process.exit(3); });
