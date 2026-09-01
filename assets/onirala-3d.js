/* Onirala — vrai objet 3D (WebGL / three.js) */
(function () {
  'use strict';
  if (window.__onirala3d) return;
  window.__onirala3d = true;

  var reduceMotion = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  var THREE_URL = 'https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js';
  var loading = false, queue = [];

  function ready(fn) {
    if (document.readyState === 'loading') { document.addEventListener('DOMContentLoaded', fn); } else { fn(); }
  }

  function withThree(cb) {
    if (window.THREE) { cb(window.THREE); return; }
    queue.push(cb);
    if (loading) return;
    loading = true;
    var s = document.createElement('script');
    s.src = THREE_URL;
    s.async = true;
    s.onload = function () { queue.forEach(function (f) { try { f(window.THREE); } catch (e) {} }); queue = []; };
    s.onerror = function () { queue = []; };
    document.head.appendChild(s);
  }

  function buildMask(THREE) {
    var g = new THREE.Group();
    var tissu = new THREE.MeshStandardMaterial({ color: 0x16181d, roughness: 0.88, metalness: 0.06, side: THREE.DoubleSide });
    var creux = new THREE.MeshStandardMaterial({ color: 0x0c0e12, roughness: 0.95, metalness: 0.02, side: THREE.DoubleSide });
    var or = new THREE.MeshStandardMaterial({ color: 0xc9a96a, roughness: 0.25, metalness: 0.95 });

    var shell = new THREE.Mesh(new THREE.SphereGeometry(1, 72, 48, -Math.PI * 0.60, Math.PI * 1.20, Math.PI * 0.30, Math.PI * 0.42), tissu);
    shell.scale.set(1.62, 0.92, 0.86);
    g.add(shell);

    var inner = new THREE.Mesh(shell.geometry, creux);
    inner.scale.set(1.55, 0.86, 0.80);
    g.add(inner);

    var rim = new THREE.Mesh(new THREE.TorusGeometry(1.0, 0.075, 16, 96), tissu);
    rim.scale.set(1.62, 0.92, 1);
    rim.position.z = 0.06;
    g.add(rim);

    [-0.72, 0.72].forEach(function (x) {
      var cup = new THREE.Mesh(new THREE.SphereGeometry(0.42, 48, 32), creux);
      cup.scale.set(1.05, 0.72, 0.55);
      cup.position.set(x, 0.02, 0.52);
      g.add(cup);
      var ring = new THREE.Mesh(new THREE.TorusGeometry(0.44, 0.035, 14, 64), tissu);
      ring.scale.set(1.05, 0.74, 1);
      ring.position.set(x, 0.02, 0.60);
      g.add(ring);
    });

    var nez = new THREE.Mesh(new THREE.SphereGeometry(0.3, 32, 24), tissu);
    nez.scale.set(0.5, 0.55, 0.5);
    nez.position.set(0, -0.34, 0.5);
    g.add(nez);

    var trait = new THREE.Mesh(new THREE.TorusGeometry(1.0, 0.012, 10, 96), or);
    trait.scale.set(1.63, 0.93, 1);
    trait.position.z = 0.10;
    g.add(trait);

    var logo = new THREE.Mesh(new THREE.TorusGeometry(0.085, 0.016, 12, 40), or);
    logo.position.set(0, 0.42, 0.60);
    g.add(logo);

    var strap = new THREE.Mesh(new THREE.TorusGeometry(1.42, 0.055, 14, 120, Math.PI * 1.05), tissu);
    strap.rotation.z = Math.PI;
    strap.scale.set(1.12, 0.86, 0.5);
    strap.position.z = -0.35;
    g.add(strap);

    var boucle = new THREE.Mesh(new THREE.TorusGeometry(0.1, 0.022, 10, 32), or);
    boucle.position.set(1.42, 0.1, -0.35);
    boucle.rotation.y = Math.PI / 2;
    g.add(boucle);

    return g;
  }

  function mount(host, onReady) {
    withThree(function (THREE) {
      try {
        var w = host.clientWidth || 420;
        var h = host.clientHeight || Math.round(w * 0.62);

        var renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
        renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
        renderer.setSize(w, h);
        renderer.domElement.style.cssText = 'display:block;width:100%;height:100%;cursor:grab;touch-action:pan-y';
        host.appendChild(renderer.domElement);

        var scene = new THREE.Scene();
        var camera = new THREE.PerspectiveCamera(34, w / h, 0.1, 100);
        camera.position.set(0, 0.15, 6.1);

        scene.add(new THREE.HemisphereLight(0xdfe8ff, 0x0a0d14, 0.75));
        var key = new THREE.DirectionalLight(0xffffff, 1.15); key.position.set(3, 4, 5); scene.add(key);
        var rimL = new THREE.DirectionalLight(0xc9a96a, 1.5); rimL.position.set(-4, 1.5, -2.5); scene.add(rimL);
        var fill = new THREE.DirectionalLight(0x8fa8d8, 0.5); fill.position.set(-2, -2, 3); scene.add(fill);

        var pivot = new THREE.Group();
        pivot.add(buildMask(THREE));
        scene.add(pivot);

        var vis = true, drag = false, px = 0, py = 0, velX = 0.0035, velY = 0, t = 0;

        function down(e) {
          drag = true;
          renderer.domElement.style.cursor = 'grabbing';
          px = e.clientX; py = e.clientY;
        }
        function move(e) {
          if (!drag) return;
          velX = (e.clientX - px) * 0.006;
          velY = (e.clientY - py) * 0.004;
          pivot.rotation.y += velX;
          pivot.rotation.x = Math.max(-0.6, Math.min(0.6, pivot.rotation.x + velY));
          px = e.clientX; py = e.clientY;
        }
        function up() { drag = false; renderer.domElement.style.cursor = 'grab'; }

        renderer.domElement.addEventListener('pointerdown', down);
        window.addEventListener('pointermove', move);
        window.addEventListener('pointerup', up);

        if ('IntersectionObserver' in window) {
          new IntersectionObserver(function (en) { vis = en[0].isIntersecting; }, { threshold: 0.05 }).observe(host);
        }

        window.addEventListener('resize', function () {
          var nw = host.clientWidth, nh = host.clientHeight || Math.round(nw * 0.62);
          if (!nw) return;
          camera.aspect = nw / nh;
          camera.updateProjectionMatrix();
          renderer.setSize(nw, nh);
        });

        function loop() {
          requestAnimationFrame(loop);
          if (!vis) return;
          t += 0.016;
          if (!drag && !reduceMotion) {
            velX += (0.0035 - velX) * 0.02;
            pivot.rotation.y += velX;
            pivot.rotation.x += (Math.sin(t * 0.5) * 0.10 - pivot.rotation.x) * 0.02;
            pivot.position.y = Math.sin(t * 0.7) * 0.07;
          }
          renderer.render(scene, camera);
        }
        loop();
        if (onReady) onReady();
      } catch (e) {}
    });
  }

  function init() {
    try {
      var media = document.querySelector('[id$="image_banner_TVECWz"] .banner__media');
      if (media) {
        var img = media.querySelector('img');
        var box = document.createElement('div');
        box.style.cssText = 'position:absolute;inset:0;z-index:2';
        media.appendChild(box);
        mount(box, function () { if (img) { img.style.opacity = '0'; img.style.transition = 'opacity .4s ease'; } });
      }

      var sec = document.querySelector('[id$="shop_product_details_JbqzwH"]');
      if (sec) {
        var btn = null, cands = sec.querySelectorAll('button, a');
        for (var i = 0; i < cands.length; i++) {
          var txt = (cands[i].textContent || '').toUpperCase();
          if (txt.indexOf('PANIER') !== -1 || txt.indexOf('COMMANDE') !== -1) { btn = cands[i]; break; }
        }
        if (btn) {
          var anchor = btn.closest('div') || btn.parentElement;
          var card = document.createElement('div');
          card.style.cssText = 'margin:18px auto 0;max-width:470px;border:1px solid rgba(201,169,106,.3);border-radius:14px;overflow:hidden;background:radial-gradient(120% 120% at 50% 30%,#24334f,#0f1626 70%)';
          var stage = document.createElement('div');
          stage.style.cssText = 'width:100%;height:250px';
          var hint = document.createElement('p');
          hint.textContent = 'Faites glisser pour tourner le masque';
          hint.style.cssText = 'margin:0;padding:9px 0 13px;text-align:center;font-size:11.5px;letter-spacing:.16em;text-transform:uppercase;color:#c9a96a';
          card.appendChild(stage);
          card.appendChild(hint);
          if (anchor && anchor.parentElement) { anchor.parentElement.insertBefore(card, anchor.nextSibling); } else { sec.appendChild(card); }
          mount(stage, null);
        }
      }
    } catch (e) {}
  }

  ready(init);
})();
