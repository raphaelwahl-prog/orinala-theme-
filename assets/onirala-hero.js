/* Masque du heros : 36 vues pre-rendues, tournables a la main.
   Ni WebGL ni transparence. Les deux ont pose probleme chez le client :
   Safari re-encodait la sortie du moteur 3D, ce qui delavait le masque en
   gris, et la couche alpha se retrouvait composee sur un fond gris. Les
   vues sont donc cuites a la bonne couleur, directement sur le creme du
   site. Ce qui s affiche est exactement ce qui a ete rendu. */
(function () {
  var N = 36, COLS = 6, RANGEES = 6;

  function pret(f) {
    if (document.readyState !== 'loading') f();
    else document.addEventListener('DOMContentLoaded', f);
  }

  pret(function () {
    var url = (window.ONIRALA_360_URL || '').trim();
    if (!url) return;
    var media = document.querySelector('[id$="image_banner_TVECWz"] .banner__media');
    if (!media) return;
    var plat = media.querySelector('img');

    var scene = document.createElement('div');
    scene.className = 'ophero';
    scene.setAttribute('role', 'img');
    scene.setAttribute('aria-label',
      'Masque de sommeil 3D Onirala, vue rotative — faites glisser pour tourner');
    var vue = document.createElement('div');
    vue.className = 'ophero-vue';
    vue.style.backgroundImage = "url('" + url + "')";
    scene.appendChild(vue);
    media.appendChild(scene);

    var i = 0;
    function afficher(n) {
      i = ((n % N) + N) % N;
      vue.style.backgroundPosition =
        (i % COLS) * 100 / (COLS - 1) + '% ' +
        Math.floor(i / COLS) * 100 / (RANGEES - 1) + '%';
    }
    afficher(0);

    /* La photo plate n est effacee qu une fois la planche vraiment chargee :
       en cas d echec reseau, le produit reste visible. */
    var img = new Image();
    img.onload = function () {
      scene.classList.add('ophero-prete');
      if (plat) { plat.style.transition = 'opacity .5s ease'; plat.style.opacity = '0'; }
      animer();
    };
    img.src = url;

    function animer() {
      var saisi = false, visible = true, minuteur = null, t = 0;
      var AMPLITUDE = 5;           /* environ +/- 50 degres autour de la face */
      var x0 = 0, i0 = 0, tourne = false;

      /* Balancement doux tant que personne ne manipule le masque. Un tour
         complet automatique passerait par le profil, ou le masque n est
         qu une tranche. A la main en revanche, les 36 vues sont accessibles. */
      function tic() {
        if (!visible || saisi) return;
        t += 0.045;
        afficher(Math.round(Math.sin(t) * AMPLITUDE));
      }
      function lancer() { if (!minuteur) minuteur = setInterval(tic, 60); }
      function couper() { if (minuteur) { clearInterval(minuteur); minuteur = null; } }

      var sobre = window.matchMedia &&
                  window.matchMedia('(prefers-reduced-motion: reduce)').matches;
      if (!sobre) {
        if ('IntersectionObserver' in window) {
          new IntersectionObserver(function (e) {
            visible = e[0].isIntersecting;
            visible ? lancer() : couper();
          }, { threshold: 0.05 }).observe(media);
        } else { lancer(); }
        document.addEventListener('visibilitychange', function () {
          document.hidden ? couper() : lancer();
        });
      }

      scene.style.cursor = 'grab';
      scene.style.touchAction = 'pan-y';
      scene.addEventListener('pointerdown', function (e) {
        saisi = true; tourne = false; x0 = e.clientX; i0 = i;
        scene.style.cursor = 'grabbing';
        scene.setPointerCapture(e.pointerId);
      });
      scene.addEventListener('pointermove', function (e) {
        if (!saisi) return;
        var pas = Math.max(8, scene.clientWidth / N * 1.4);
        var d = Math.round((e.clientX - x0) / pas);
        if (d !== 0) tourne = true;
        afficher(i0 - d);
      });
      function relacher() {
        if (!saisi) return;
        saisi = false;
        scene.style.cursor = 'grab';
        /* Le balancement repart la ou l utilisateur a laisse le masque,
           sans saut : on recale la phase du sinus sur la vue courante. */
        if (tourne) {
          var v = Math.max(-1, Math.min(1, i > N / 2 ? (i - N) / AMPLITUDE : i / AMPLITUDE));
          t = Math.asin(v);
        }
      }
      scene.addEventListener('pointerup', relacher);
      scene.addEventListener('pointercancel', relacher);
      scene.addEventListener('pointerleave', relacher);
    }
  });
})();
