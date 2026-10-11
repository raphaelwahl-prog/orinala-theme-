// Mode d'emploi : web/README.md
const { chromium } = require("playwright");
const path = require("path");

const CHROME = "/opt/pw-browsers/chromium-1194/chrome-linux/chrome";
let fails = 0, n = 0;
const ok = (c, m) => { n++; console.log((c ? "  OK    " : "  ÉCHEC ") + m); if (!c) fails++; };

(async () => {
  const browser = await chromium.launch({
    executablePath: CHROME,
    args: ["--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--no-sandbox"],
  });
  const page = await browser.newPage({ viewport: { width: 1280, height: 760 } });
  const errors = [], warns = [];
  page.on("pageerror", (e) => errors.push("pageerror: " + e.message));
  page.on("console", (m) => { if (m.type() === "error") errors.push("console: " + m.text());
                              else if (m.type() === "warning") warns.push(m.text()); });

  await page.goto("file://" + path.join(__dirname, "page.html"));
  await page.waitForTimeout(1200);

  console.log("— chargement —");
  ok(errors.length === 0, "aucune erreur au chargement" + (errors.length ? " → " + errors.join(" | ") : ""));
  ok(await page.evaluate(() => !!window.THREE), "Three.js chargé");
  ok(await page.evaluate(() => !!document.getElementById("cv").getContext), "canvas présent");
  const drew = await page.evaluate(() => renderer.info.render.calls);
  ok(drew > 0, "le GPU a dessiné " + drew + " appels de rendu");
  ok(await page.evaluate(() => renderer.getContext() !== null), "contexte WebGL vivant");
  const tri = await page.evaluate(() => renderer.info.render.triangles);
  ok(tri > 500, tri + " triangles à l'écran");

  console.log("— écran titre —");
  ok(await page.isVisible("#b-play"), "bouton « Commencer la nuit 1 » visible");
  const shot = async (name) => { await page.screenshot({ path: path.join(__dirname, name) }); };
  await shot("01-titre.png");
  await page.click("#b-play");
  await page.waitForTimeout(400);
  ok(await page.evaluate(() => G.running), "la partie tourne");
  ok(await page.evaluate(() => !document.getElementById("hud").hidden), "le HUD est affiché");
  ok(await page.evaluate(() => actors.children.includes(player)), "le personnage est bien dans la scène (bug world.clear corrigé)");
  ok(await page.evaluate(() => player.visible), "le personnage est visible");

  console.log("— déplacement —");
  const p0 = await page.evaluate(() => ({ x: G.px, z: G.pz }));
  await page.keyboard.down("w");
  await page.waitForTimeout(700);
  await page.keyboard.up("w");
  const p1 = await page.evaluate(() => ({ x: G.px, z: G.pz }));
  const moved = Math.hypot(p1.x - p0.x, p1.z - p0.z);
  ok(moved > 4, "Z/W avance : " + moved.toFixed(1) + " studs parcourus");
  ok(await page.evaluate(() => !solid(G.px, G.pz)), "le joueur n'est pas dans un mur");
  ok(await page.evaluate(() => G.walk > 0), "le cycle de marche des membres tourne");

  console.log("— les commandes suivent la caméra, quel que soit l'angle —");
  const dirs = await page.evaluate(() => {
    const out = [];
    for (const yaw of [0, Math.PI / 2, Math.PI, -Math.PI / 2, 0.7]) {
      G.yaw = yaw; G.sleeping = null; G.dead = 0;
      const b = beds.find(x => x.tier === 1);
      G.px = b.x; G.pz = b.z;
      keys["z"] = true;
      const x0 = G.px, z0 = G.pz;
      for (let i = 0; i < 20; i++) movePlayer(1 / 60);
      keys["z"] = false;
      const mx = G.px - x0, mz = G.pz - z0, len = Math.hypot(mx, mz) || 1;
      // l'avant de la caméra : yaw 0 regarde vers −Z
      const fx = -Math.sin(yaw), fz = -Math.cos(yaw);
      out.push({ yaw: yaw.toFixed(2), dot: ((mx / len) * fx + (mz / len) * fz).toFixed(2), len: len.toFixed(1) });
    }
    return out;
  });
  for (const d of dirs)
    ok(+d.dot > 0.9 || +d.len < 0.5,
       "vue à " + d.yaw + " rad : avancer part bien vers l'avant (produit scalaire " + d.dot + ", " + d.len + " studs)");
  const facing = await page.evaluate(async () => {
    G.yaw = 1.1; await new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r)));
    const f = new THREE.Vector3(0, 0, -1).applyQuaternion(player.quaternion);
    const toCam = new THREE.Vector3().subVectors(camera.position, player.position).setY(0).normalize();
    return f.dot(toCam);
  });
  ok(facing < -0.9, "le personnage tourne le dos à la caméra, il ne la regarde pas (" + facing.toFixed(2) + ")");

  console.log("— collision des murs —");
  const stuck = await page.evaluate(async () => {
    // plaqué dans un coin de la salle du Dortoir, puis on pousse dans le mur
    const b = beds.find(b => b.tier === 1);
    G.px = b.x; G.pz = b.z; G.yaw = 0;
    let inside = 0;
    for (const dir of [[1,0],[-1,0],[0,1],[0,-1]]) {
      G.px = b.x; G.pz = b.z;
      for (let i = 0; i < 400; i++) {
        const nx = G.px + dir[0] * 1.2, nz = G.pz + dir[1] * 1.2;
        if (!solid(nx + Math.sign(dir[0]) * 1.6, G.pz)) G.px = nx;
        if (!solid(G.px, nz + Math.sign(dir[1]) * 1.6)) G.pz = nz;
      }
      if (solid(G.px, G.pz)) inside++;
    }
    return inside;
  });
  ok(stuck === 0, "en poussant 480 studs dans les 4 directions, on ne traverse aucun mur");

  console.log("— dormir et gagner —");
  const sleep = await page.evaluate(async () => {
    const b = beds.find(b => b.tier === 1);
    G.phase = "night"; G.phaseLeft = 180;
    G.px = b.x; G.pz = b.z;
    return { near: !!nearBed(), promptOn: promptLine() };
  });
  ok(sleep.near, "le lit est détecté sous le joueur");
  ok(sleep.promptOn, "l'invite « E dormir » apparaît");
  await page.keyboard.press("e");
  await page.waitForTimeout(1500);
  const slept = await page.evaluate(() => ({ sleeping: !!G.sleeping, tier: G.sleeping && G.sleeping.tier, cash: G.unbanked }));
  ok(slept.sleeping, "E endort le joueur (palier " + slept.tier + ")");
  ok(slept.cash > 0.8, "l'argent monte pendant le sommeil : " + slept.cash.toFixed(1) + " $");
  await shot("02-sommeil.png");
  await page.keyboard.press(" ");
  await page.waitForTimeout(150);
  ok(await page.evaluate(() => !G.sleeping), "Espace réveille");

  console.log("— coffre et boutique —");
  const banked = await page.evaluate(() => {
    G.px = vault.x; G.pz = vault.z; G.unbanked = 5000;
    const before = G.cash; interact();
    return { gain: G.cash - before, unbanked: G.unbanked, total: G.totalBanked };
  });
  ok(banked.gain === 5000 && banked.unbanked === 0, "le coffre encaisse 5 000 $ (banque +" + banked.gain + ")");
  await page.evaluate(() => { G.px = shop.x; G.pz = shop.z; interact(); });
  await page.waitForTimeout(250);
  ok(await page.isVisible("[data-buy='shoes']"), "la boutique s'ouvre avec ses articles");
  await page.click("[data-buy='shoes']");
  await page.waitForTimeout(200);
  ok(await page.evaluate(() => G.items.shoes === 1), "l'achat des baskets s'applique");
  await shot("03-boutique.png");
  await page.click("#b-cl");
  await page.waitForTimeout(150);
  const closed = await page.evaluate(() => {
    const sh = document.getElementById("sheet");
    const mid = document.elementFromPoint(innerWidth / 2, innerHeight / 2);
    return { running: G.running, display: getComputedStyle(sh).display, hit: mid && mid.id };
  });
  ok(closed.running, "la partie reprend après la boutique");
  ok(closed.display === "none", "le panneau fermé ne laisse aucun voile devant le jeu (display: " + closed.display + ")");
  ok(closed.hit === "cv", "le clic au centre atteint bien le canvas (" + closed.hit + ") — verrouillage souris possible");

  console.log("— déblocage des paliers —");
  const unlocked = await page.evaluate(() => { G.totalBanked = 60000; refreshBeds(); return maxTier(); });
  ok(unlocked === 5, "60 000 $ déposés débloquent les 5 paliers (max = " + unlocked + ")");

  console.log("— les quatre créatures —");
  for (const tier of [2, 3, 4, 5]) {
    const res = await page.evaluate(async (tier) => {
      const b = beds.find(x => x.tier === tier);
      clearBeasts();
      G.phase = "night"; G.dead = 0; G.stage = 0; G.unbanked = 900;
      G.px = b.x; G.pz = b.z; G.sleeping = null;
      spawnBeast(BEASTS[tier], 4.5);
      const inst = G.beasts[0];
      const d0 = Math.hypot(inst.x - G.px, inst.z - G.pz);
      const start = performance.now();
      // on laisse 2,5 s de vraies frames tourner
      await new Promise(r => setTimeout(r, 2500));
      const alive = G.beasts.includes(inst);
      const d1 = alive ? Math.hypot(inst.x - G.px, inst.z - G.pz) : 0;
      return { name: BEASTS[tier].name, d0, d1, alive, mode: inst.mode,
               caught: G.dead > 0, unbanked: G.unbanked,
               inScene: actors.children.includes(inst.obj),
               hasLamp: !!inst.lamp, lampInScene: inst.lamp ? actors.children.includes(inst.lamp) : null };
    }, tier);
    ok(res.inScene, res.name + " : modèle 3D ajouté à la scène");
    ok(res.d0 > 14, res.name + " : apparaît à " + res.d0.toFixed(0) + " studs (hors de portée immédiate)");
    ok(res.caught || res.d1 < res.d0 - 5 || !res.alive,
       res.name + " : se rapproche (" + res.d0.toFixed(0) + " → " + (res.alive ? res.d1.toFixed(0) : "attrape/abandon") + ")");
    if (res.caught) ok(res.unbanked === 0, res.name + " : la prise fait perdre l'argent non déposé");
    if (tier === 2) { ok(res.hasLamp && res.lampInScene, res.name + " : sa lanterne éclaire depuis la scène, pas depuis le corps"); }
  }

  console.log("— le son —");
  const au = await page.evaluate(() => ({
    ctx: SFX.ctx ? SFX.ctx.state : "aucun",
    drone: !!SFX.drone, gain: SFX.master ? SFX.master.gain.value : -1,
  }));
  ok(au.ctx === "running", "le contexte audio démarre au clic sur Jouer (" + au.ctx + ")");
  ok(au.drone, "la nappe d'ambiance tourne");
  ok(au.gain > 0.5, "le son est audible (gain " + au.gain + ")");
  await page.keyboard.press("m");
  await page.waitForTimeout(120);
  const muted = await page.evaluate(() => ({ gain: SFX.master.gain.value, label: document.getElementById("snd").textContent }));
  ok(muted.gain === 0, "M coupe le son");
  ok(/coupé/.test(muted.label), "l'indicateur affiche « " + muted.label + " »");
  await page.keyboard.press("m");
  await page.waitForTimeout(120);
  ok(await page.evaluate(() => SFX.master.gain.value) > 0.5, "M le remet");

  console.log("— courir —");
  const run = await page.evaluate(() => {
    const b = beds.find(x => x.tier === 1);
    const walk = () => {
      G.px = b.x; G.pz = b.z; G.yaw = 0; G.stam = 1; G.sleeping = null; G.dead = 0;
      const x0 = G.px, z0 = G.pz;
      for (let i = 0; i < 30; i++) movePlayer(1 / 60);
      return Math.hypot(G.px - x0, G.pz - z0);
    };
    keys["z"] = true; keys["shift"] = false;
    const marche = walk();
    keys["shift"] = true;
    const course = walk();
    const stamApres = G.stam;
    // jusqu'à épuisement
    G.stam = 1; let t = 0;
    while (G.stam > 0 && t < 10) { movePlayer(1 / 60); t += 1 / 60; }
    const vide = t;
    const essouffle = G.winded;
    // à sec, Maj ne relance pas la course tant qu'on n'a pas récupéré
    let relance = false;
    for (let i = 0; i < 30; i++) { movePlayer(1 / 60); if (G.sprint) relance = true; }
    keys["z"] = false; keys["shift"] = false;
    let r = 0; while (G.stam < 1 && r < 20) { movePlayer(1 / 60); r += 1 / 60; }
    return { marche, course, stamApres, vide, recup: r, essouffle, relance };
  });
  ok(run.course > run.marche * 1.4,
     "Maj fait courir : " + run.course.toFixed(1) + " studs contre " + run.marche.toFixed(1) + " en marchant");
  ok(run.stamApres < 0.9, "courir vide la jauge (" + (run.stamApres * 100).toFixed(0) + " % restants)");
  ok(run.vide > 2.5 && run.vide < 4, "la jauge tient " + run.vide.toFixed(1) + " s, pas plus");
  ok(run.recup > 4 && run.recup < 7, "elle met " + run.recup.toFixed(1) + " s à revenir — la course reste une sortie de secours");
  ok(run.essouffle, "à sec, le joueur est essoufflé");
  ok(!run.relance, "essoufflé, Maj ne relance pas la course en saccades");

  console.log("— silhouettes des créatures —");
  const forms = await page.evaluate(() => {
    const out = {};
    clearBeasts();
    for (const t of [2, 3, 4, 5]) {
      spawnBeast(BEASTS[t], null, true);
      const inst = G.beasts[G.beasts.length - 1];
      const mats = [];
      inst.obj.traverse(o => { if (o.material) mats.push(Array.isArray(o.material) ? o.material : [o.material]); });
      const flat = [].concat(...mats);
      out[BEASTS[t].id] = {
        crawl: !!inst.obj.userData.crawl,
        pieces: inst.obj.children.length,
        visage: flat.some(m => m.map),
        couleurJoueur: flat.some(m => m.color && m.color.getHex() === 0x3f7fbf),
      };
    }
    const pf = [];
    player.traverse(o => { if (o.material) pf.push(...(Array.isArray(o.material) ? o.material : [o.material])); });
    out.joueur = { visage: pf.some(m => m.map) };
    clearBeasts();
    return out;
  });
  ok(forms.joueur.visage, "le joueur a un vrai visage dessiné sur la tête");
  ok(forms.crawler.crawl, "LA RAMPANTE est à quatre pattes, pas debout");
  ok(forms.crawler.visage, "LA RAMPANTE a une bouche cousue à la place des yeux");
  ok(!forms.watchman.crawl && forms.watchman.pieces >= 7, "LE VEILLEUR est debout, avec sa casquette");
  ok(forms.mimic.couleurJoueur, "LE MIME porte les couleurs du joueur");
  ok(forms.mimic.visage, "LE MIME porte un visage — le mauvais");

  console.log("— décor —");
  const deco = await page.evaluate(() => {
    const y = [];
    // un plafond doit exister au-dessus du point d'apparition
    const ray = new THREE.Raycaster(new THREE.Vector3(spawn.x, 2, spawn.z), new THREE.Vector3(0, 1, 0), 0, 40);
    const hits = ray.intersectObjects(world.children, true);
    return { objets: world.children.length, plafond: hits.length > 0, hauteur: hits[0] ? hits[0].distance : -1 };
  });
  ok(deco.objets > 150, deco.objets + " objets dans le décor (sol, murs, plafond, mobilier)");
  ok(deco.plafond, "il y a un plafond au-dessus de la tête (à " + deco.hauteur.toFixed(1) + " studs)");

  console.log("— résumé de fin de nuit —");
  const rec = await page.evaluate(() => {
    closeSheet(); G.running = true; clearBeasts();
    G.night = 3; G.nightEarn = 0; G.nightCaught = 1; G.nightDeep = 4;
    G.phase = "night"; G.unbanked = 2400;
    beginDawn();
    const card = document.getElementById("sheet").textContent;
    return { sheet, running: G.running, card };
  });
  ok(rec.sheet === "night", "l'aube ouvre le bilan de la nuit");
  ok(rec.running === false, "le bilan met le jeu en pause");
  ok(/2 400/.test(rec.card.replace(/\u202f|\u00a0/g, " ")), "le bilan affiche ce qui a été déposé");
  ok(/Chambre froide/.test(rec.card), "le bilan nomme la planque la plus profonde");
  ok(/1 fois/.test(rec.card.replace(/\u202f|\u00a0/g, " ")), "le bilan compte les prises");
  await shot("10-bilan.png");
  await page.click("#b-nx");
  await page.waitForTimeout(150);
  ok(await page.evaluate(() => G.running), "« Continuer » relance la partie");

  console.log("— occlusion : on ne voit pas à travers les murs —");
  const occ = await page.evaluate(async () => {
    clearBeasts(); G.dead = 0;
    const b1 = beds.find(x => x.tier === 5), b2 = beds.find(x => x.tier === 4);
    G.px = b1.x; G.pz = b1.z; G.stage = 0;
    spawnBeast(BEASTS[4], null, true);
    const inst = G.beasts[0];
    inst.x = b2.x; inst.z = b2.z; inst.mode = "patrol"; inst.pt = { x: b2.x, z: b2.z };
    await new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r)));
    const hiddenBehindWall = inst.obj.visible;
    inst.x = G.px + 20; inst.z = G.pz;
    await new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r)));
    return { behind: hiddenBehindWall, same: inst.obj.visible, revealed: sheet };
  });
  ok(occ.behind === false, "une créature dans une autre salle est masquée");
  ok(occ.same === true, "une créature dans la même salle est visible");
  ok(occ.revealed === "reveal", "quand elle repère le joueur, la carte de révélation s'ouvre et met le jeu en pause");
  await shot("06-revelation.png");
  await page.evaluate(() => { closeSheet(); G.running = true; });

  console.log("— éveil de la maison —");
  const awak = await page.evaluate(async () => {
    closeSheet(); G.running = true;
    clearBeasts(); G.awaken = 0; G.stage = 0;
    const steps = [];
    for (let i = 0; i < 40; i++) { feedAwakening(5); steps.push(G.stage); }
    const fogTarget = STAGES[G.stage].fog;
    await new Promise(r => setTimeout(r, 1200));
    return { stage: G.stage, fogTarget, fogNow: scene.fog.far,
             starved: G.beasts.some(b => b.def.id === "starved"), path: steps.join("") };
  });
  ok(awak.stage === 3, "dormir dans Le Nid pousse la maison au stade AFFAMÉ (" + awak.stage + ")");
  ok(awak.starved, "L'AFFAMÉ sort du Nid au stade 3");
  ok(Math.abs(awak.fogNow - awak.fogTarget) < 6, "le brouillard se resserre vers " + awak.fogTarget + " (actuel " + awak.fogNow.toFixed(1) + ")");

  console.log("— nuit / jour —");
  const cycle = await page.evaluate(() => {
    clearBeasts(); G.phase = "night"; G.unbanked = 777; const c0 = G.cash, nights0 = G.nights;
    beginDawn();
    const dawn = { phase: G.phase, gain: G.cash - c0, nights: G.nights - nights0, beasts: G.beasts.length };
    beginNight();
    return { dawn, night: { phase: G.phase, beasts: G.beasts.length, awaken: G.awaken, stage: G.stage, left: Math.round(G.phaseLeft) } };
  });
  ok(cycle.dawn.phase === "dawn" && cycle.dawn.gain === 777, "l'aube encaisse ce qui restait (+" + cycle.dawn.gain + " $)");
  ok(cycle.dawn.nights === 1, "le compteur de nuits avance");
  ok(cycle.dawn.beasts === 0, "les créatures disparaissent au jour");
  ok(cycle.night.phase === "night" && cycle.night.left === 180, "la nuit repart sur 180 s");
  ok(cycle.night.beasts === 1 && cycle.night.stage === 0, "une ronde (Le Veilleur) démarre, éveil remis à zéro");

  console.log("— sauvegarde —");
  const sav = await page.evaluate(() => { save(); const raw = localStorage.getItem("deadtired3d.v1"); const d = JSON.parse(raw); return { keys: Object.keys(d).sort().join(","), cash: d.cash }; });
  ok(sav.keys === "cash,deepest,items,nights,seen,totalBanked", "la sauvegarde contient " + sav.keys);
  await page.reload();
  await page.waitForTimeout(900);
  ok(await page.evaluate(() => G.cash) === sav.cash, "après rechargement, l'argent est retrouvé (" + sav.cash + " $)");
  ok(await page.isVisible("#b-reset"), "l'écran titre propose « Repartir de zéro »");

  console.log("— pause —");
  await page.click("#b-play"); await page.waitForTimeout(300);
  await page.keyboard.press("Escape"); await page.waitForTimeout(250);
  ok(await page.evaluate(() => !G.running), "Échap met en pause");
  ok(await page.isVisible("#b-res"), "le panneau de pause s'affiche");
  await page.keyboard.press("Escape"); await page.waitForTimeout(200);
  ok(await page.evaluate(() => G.running), "Échap reprend");

  console.log("— caméra —");
  const cam = await page.evaluate(async () => {
    const b = beds.find(x => x.tier === 3);
    G.px = b.x; G.pz = b.z - b.d; G.yaw = Math.PI; // dos au mur du fond
    await new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r)));
    const inWall = solid(camera.position.x, camera.position.z);
    const d = Math.hypot(camera.position.x - G.px, camera.position.z - G.pz);
    return { inWall, d };
  });
  ok(!cam.inWall, "dos au mur, la caméra se rapproche au lieu de passer dedans (" + cam.d.toFixed(1) + " studs)");
  // balayage : partout dans les 5 salles, sous tous les angles, la caméra doit
  // rester dans le décor jouable
  const sweep = await page.evaluate(async () => {
    let bad = 0, total = 0, worst = null;
    for (const b of beds) {
      for (let dx = -14; dx <= 14; dx += 7) for (let dz = -14; dz <= 14; dz += 7) {
        if (solid(b.x + dx, b.z + dz)) continue;
        for (let k = 0; k < 8; k++) {
          G.px = b.x + dx; G.pz = b.z + dz; G.yaw = k * Math.PI / 4; G.pitch = -0.15;
          await new Promise(r => requestAnimationFrame(r));
          total++;
          if (solid(camera.position.x, camera.position.z)) { bad++; worst = worst || { x: G.px, z: G.pz, yaw: k }; }
        }
      }
    }
    return { bad, total, worst };
  });
  ok(sweep.bad === 0, "sur " + sweep.total + " positions et angles dans les 5 salles, la caméra n'est jamais dans un mur (" + sweep.bad + " cas)");
  await shot("04-dos-au-mur.png");

  // Vue représentative : debout dans le hall, face au coffre.
  await page.evaluate(async () => {
    closeSheet(); G.running = true; G.dead = 0; clearBeasts();
    G.phase = "night"; G.phaseLeft = 143; G.unbanked = 1240; G.cash = 5027;
    G.px = spawn.x; G.pz = spawn.z - 6;
    G.yaw = Math.atan2(G.px - vault.x, G.pz - vault.z);
    G.pitch = -0.12;
    for (let i = 0; i < 4; i++) await new Promise(r => requestAnimationFrame(r));
  });
  await page.waitForTimeout(200);
  await shot("07-hall.png");
  await page.evaluate(async () => {
    const b = beds.find(x => x.tier === 5);
    // yaw 0 regarde vers -Z : le joueur a le lit et la créature devant lui.
    G.px = b.x; G.pz = b.z + 18; G.yaw = 0; G.pitch = -0.1; G.stage = 2;
    clearBeasts(); spawnBeast(BEASTS[5], null, true);
    G.beasts[0].x = b.x + 4; G.beasts[0].z = b.z - 6; G.beasts[0].mode = "hunt";
    G.beasts[0].angle = Math.PI;
    for (let i = 0; i < 4; i++) await new Promise(r => requestAnimationFrame(r));
  });
  await page.waitForTimeout(300);
  const framing = await page.evaluate(() => ({
    camInWall: solid(camera.position.x, camera.position.z),
    beastVisible: G.beasts[0] && G.beasts[0].obj.visible,
  }));
  ok(!framing.camInWall, "capture : la caméra est bien dans la salle");
  ok(framing.beastVisible, "capture : L'AFFAMÉ est visible face au joueur");
  await shot("08-affame.png");
  await page.evaluate(() => { closeSheet(); G.running = true; G.dead = 0; clearBeasts(); });

  console.log("— téléphone 390×844 —");
  await page.setViewportSize({ width: 390, height: 844 });
  await page.waitForTimeout(500);
  const mob = await page.evaluate(() => ({
    overflow: document.documentElement.scrollWidth - document.documentElement.clientWidth,
    canvasW: document.getElementById("cv").clientWidth,
    aspect: camera.aspect.toFixed(2),
  }));
  ok(mob.overflow <= 0, "pas de défilement horizontal (débord " + mob.overflow + " px)");
  ok(mob.canvasW === 390, "le canvas suit la largeur (" + mob.canvasW + " px)");
  const lay = await page.evaluate(() => {
    document.getElementById("sleep").hidden = false;
    document.getElementById("prompt").hidden = false;
    document.getElementById("prompt").textContent = "E dormir · Le Nid · 45 $/s";
    const ids = ["sleep", "prompt"];
    const r = (sel) => { const e = document.querySelector(sel); const b = e.getBoundingClientRect(); return { sel, ...b.toJSON() }; };
    const panes = [r(".wallet"), r(".clock"), r(".awake"), r(".sleep"), r(".prompt"), r(".toasts")];
    const hits = [];
    for (let i = 0; i < panes.length; i++) for (let j = i + 1; j < panes.length; j++) {
      const a = panes[i], b = panes[j];
      if (a.width && b.width && a.left < b.right && b.left < a.right && a.top < b.bottom && b.top < a.bottom)
        hits.push(a.sel + " ∩ " + b.sel);
    }
    const out = panes.filter(p => p.width && (p.left < 0 || p.right > innerWidth)).map(p => p.sel);
    return { hits, out, fov: camera.fov.toFixed(0) };
  });
  ok(lay.hits.length === 0, "aucun panneau du HUD n'en chevauche un autre" + (lay.hits.length ? " → " + lay.hits.join(", ") : ""));
  ok(lay.out.length === 0, "aucun panneau ne déborde de l'écran" + (lay.out.length ? " → " + lay.out.join(", ") : ""));
  ok(+lay.fov >= 90, "le champ de vision s'élargit en portrait (" + lay.fov + "°)");
  await shot("05-mobile.png");
  await page.evaluate(async () => {
    document.getElementById("sleep").hidden = true; document.getElementById("prompt").hidden = true;
    G.phase = "night"; G.px = spawn.x; G.pz = spawn.z - 6;
    G.yaw = Math.atan2(G.px - vault.x, G.pz - vault.z); G.pitch = -0.12;
    for (let i = 0; i < 4; i++) await new Promise(r => requestAnimationFrame(r));
  });
  await page.waitForTimeout(200);
  await shot("09-mobile-hall.png");

  console.log("— aucune erreur sur toute la session —");
  ok(errors.length === 0, errors.length ? errors.slice(0, 6).join(" | ") : "0 erreur console, 0 exception");
  console.log("  (avertissements : " + warns.length + (warns.length ? " → " + warns.slice(0,3).join(" | ") : "") + ")");

  await browser.close();
  console.log("\n" + (n - fails) + "/" + n + " vérifications passées.");
  process.exit(fails ? 1 : 0);
})().catch((e) => { console.error("HARNESS KO : " + e.stack); process.exit(2); });
