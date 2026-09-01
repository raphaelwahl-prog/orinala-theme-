/* Onirala — masque 3D (maillage GLB reel, three.js) */
(function () {
  'use strict';
  if (window.__onirala3d) return;
  window.__onirala3d = true;

  var THREE_SRC  = 'https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js';
  var LOADER_SRC = 'https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/loaders/GLTFLoader.js';
  var reduce = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  function ready(fn) {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', fn);
    else fn();
  }

  function load(src, cb) {
    var s = document.createElement('script');
    s.src = src; s.async = false;
    s.onload = cb; s.onerror = function () { cb(new Error('load ' + src)); };
    document.head.appendChild(s);
  }

  function withThree(cb) {
    if (window.THREE && window.THREE.GLTFLoader) { cb(); return; }
    load(THREE_SRC, function (e) {
      if (e || !window.THREE) return;
      load(LOADER_SRC, function (e2) { if (!e2 && window.THREE.GLTFLoader) cb(); });
    });
  }

  /* Recadre, centre, et corrige la profondeur.
     La reconstruction 3D depuis une seule photo gonfle l'arriere de l'objet :
     elle rend ici 1.90 x 0.91 x 1.78, alors qu'un masque de sommeil reel est
     plat (profondeur ~1/3 de la largeur). Sans ca, des qu'il tourne on voit
     une bulle au lieu d'un masque. On ecrase donc Z jusqu'au bon ratio. */
  var DEPTH_RATIO = 0.34;
  function normalise(THREE, obj) {
    var box = new THREE.Box3().setFromObject(obj);
    var size = box.getSize(new THREE.Vector3());
    var ctr = box.getCenter(new THREE.Vector3());
    var m = Math.max(size.x, size.y, size.z) || 1;
    obj.position.sub(ctr);
    var s = 2 / m;
    var zk = 1;
    if (size.x > 0 && size.z > 0) {
      zk = Math.max(0.2, Math.min(1, DEPTH_RATIO * size.x / size.z));
    }
    var wrap = new THREE.Group();
    wrap.add(obj);
    wrap.scale.set(s, s, s * zk);
    return wrap;
  }

  function mount(host, url, opts) {
    opts = opts || {};
    withThree(function () {
      var THREE = window.THREE;
      var w = host.clientWidth || 480;
      var h = host.clientHeight || Math.round(w * 0.7);

      var renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
      renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
      renderer.setSize(w, h);
      renderer.outputEncoding = THREE.sRGBEncoding;
      renderer.toneMapping = THREE.ACESFilmicToneMapping;
      renderer.toneMappingExposure = 1.15;
      renderer.domElement.style.cssText =
        'display:block;width:100%;height:100%;cursor:grab;touch-action:pan-y';
      host.appendChild(renderer.domElement);

      var scene = new THREE.Scene();
      var camera = new THREE.PerspectiveCamera(30, w / h, 0.1, 100);
      camera.position.set(0, 0.25, 5.4);
      camera.lookAt(0, 0, 0);

      scene.add(new THREE.HemisphereLight(0xffffff, 0x404650, 0.85));
      var key = new THREE.DirectionalLight(0xffffff, 1.9);
      key.position.set(2.5, 3.5, 4); scene.add(key);
      var rim = new THREE.DirectionalLight(0xdce6ff, 1.25);
      rim.position.set(-3.5, 1.5, -2.5); scene.add(rim);
      var fill = new THREE.DirectionalLight(0xffffff, 0.55);
      fill.position.set(-1.5, -2, 2.5); scene.add(fill);

      /* ombre portee douce */
      var shadow = null;
      if (opts.shadow !== false) {
        var c = document.createElement('canvas'); c.width = c.height = 256;
        var g = c.getContext('2d');
        var grd = g.createRadialGradient(128, 128, 8, 128, 128, 126);
        grd.addColorStop(0, 'rgba(0,0,0,0.42)');
        grd.addColorStop(0.55, 'rgba(0,0,0,0.16)');
        grd.addColorStop(1, 'rgba(0,0,0,0)');
        g.fillStyle = grd; g.fillRect(0, 0, 256, 256);
        var tex = new THREE.CanvasTexture(c);
        shadow = new THREE.Mesh(
          new THREE.PlaneGeometry(3.4, 3.4),
          new THREE.MeshBasicMaterial({ map: tex, transparent: true, depthWrite: false })
        );
        shadow.rotation.x = -Math.PI / 2;
        shadow.position.y = -1.15;
        shadow.scale.set(1, 0.55, 1);
        scene.add(shadow);
      }

      var pivot = new THREE.Group();
      scene.add(pivot);

      var vis = true, drag = false, px = 0, py = 0, velX = 0, velY = 0, t = 0, loaded = false;

      new THREE.GLTFLoader().load(url, function (gltf) {
        var obj = normalise(THREE, gltf.scene);
        obj.traverse(function (n) {
          if (!n.isMesh) return;
          n.material.side = THREE.DoubleSide;
          if (n.material.map) n.material.map.encoding = THREE.sRGBEncoding;
          if ('roughness' in n.material) n.material.roughness = Math.min(0.95, (n.material.roughness || 0.8));
          if ('envMapIntensity' in n.material) n.material.envMapIntensity = 1.1;
          n.material.needsUpdate = true;
        });
        pivot.add(obj);
        pivot.rotation.y = -0.35;
        loaded = true;
        host.classList.add('op3d-ready');
        if (opts.onReady) opts.onReady();
      }, undefined, function () { host.classList.add('op3d-failed'); });

      function down(e) { drag = true; renderer.domElement.style.cursor = 'grabbing'; px = e.clientX; py = e.clientY; }
      function move(e) {
        if (!drag) return;
        velX = (e.clientX - px) * 0.007;
        velY = (e.clientY - py) * 0.004;
        pivot.rotation.y += velX;
        pivot.rotation.x = Math.max(-0.5, Math.min(0.5, pivot.rotation.x + velY));
        px = e.clientX; py = e.clientY;
      }
      function up() { drag = false; renderer.domElement.style.cursor = 'grab'; }
      renderer.domElement.addEventListener('pointerdown', down);
      window.addEventListener('pointermove', move);
      window.addEventListener('pointerup', up);

      if ('IntersectionObserver' in window) {
        new IntersectionObserver(function (en) { vis = en[0].isIntersecting; }, { threshold: 0.02 }).observe(host);
      }

      function resize() {
        var nw = host.clientWidth, nh = host.clientHeight || Math.round(nw * 0.7);
        if (!nw || !nh) return;
        camera.aspect = nw / nh; camera.updateProjectionMatrix();
        renderer.setSize(nw, nh);
      }
      window.addEventListener('resize', resize);

      function loop() {
        requestAnimationFrame(loop);
        if (!vis || !loaded) return;
        t += 0.016;
        if (!drag) {
          if (reduce) {
            pivot.rotation.y += (-0.35 - pivot.rotation.y) * 0.05;
          } else {
            velX *= 0.94;
            /* va-et-vient de presentation, jamais de tour complet */
            var target = Math.sin(t * 0.32) * 0.62;
            pivot.rotation.y += (target - pivot.rotation.y) * 0.012 + velX;
            pivot.rotation.x += (Math.sin(t * 0.24) * 0.10 - pivot.rotation.x) * 0.02;
            pivot.position.y = Math.sin(t * 0.55) * 0.055;
          }
        }
        if (shadow) {
          var s = 1 - Math.abs(Math.sin(pivot.rotation.y)) * 0.22;
          shadow.scale.set(s, 0.55 * s, 1);
          shadow.material.opacity = 0.75 + Math.cos(pivot.rotation.y) * 0.25;
          shadow.position.y = -1.15 + pivot.position.y * 0.35;
        }
        renderer.render(scene, camera);
      }
      loop();
    });
  }

  function init() {
    var url = (window.ONIRALA_3D_URL || '').trim();
    if (!url) return;
    var media = document.querySelector('[id$="image_banner_TVECWz"] .banner__media');
    if (!media) return;
    var img = media.querySelector('img');
    var stage = document.createElement('div');
    stage.className = 'op3d-stage';
    media.appendChild(stage);
    mount(stage, url, {
      onReady: function () {
        if (img) { img.style.transition = 'opacity .5s ease'; img.style.opacity = '0'; }
        media.classList.add('op3d-live');
      }
    });
  }

  ready(init);
})();
