/* Masque Onirala : 36 vues pre-rendues, tournables a la main.
   Ni WebGL ni transparence. Les deux ont pose probleme : Safari re-encodait
   la sortie du moteur 3D, ce qui delavait le masque en gris, et la couche
   alpha se retrouvait composee sur un fond gris. Les vues sont donc cuites
   a la bonne couleur, directement sur le fond du site. Ce qui s affiche est
   exactement ce qui a ete rendu.

   La meme scene sert au heros de l accueil et au bloc 360 de la fiche
   produit ; seule la facon de l ancrer change. */
(function () {
  var N = 36, COLS = 6, RANGEES = 6;
  var AIDE = '<svg viewBox="0 0 24 24" aria-hidden="true">' +
             '<path d="M9 7 5 12l4 5"/><path d="m15 7 4 5-4 5"/>' +
             '<path d="M12 9v6"/></svg><span>Faites glisser pour tourner</span>';

  function pret(f) {
    if (document.readyState !== 'loading') f();
    else document.addEventListener('DOMContentLoaded', f);
  }

  /* Construit une scene dans le conteneur donne.
     plat : photo a effacer une fois la planche chargee (peut etre absente).
     balance : balancement automatique tant que personne ne manipule. */
  function creer(conteneur, url, plat, balance) {
    var scene = document.createElement('div');
    scene.className = 'ophero';
    scene.setAttribute('role', 'img');
    scene.setAttribute('aria-label',
      'Masque de sommeil Onirala en 3D — faites glisser pour le tourner');

    var vue = document.createElement('div');
    vue.className = 'ophero-vue';
    vue.style.backgroundImage = "url('" + url + "')";
    scene.appendChild(vue);

    var aide = document.createElement('div');
    aide.className = 'ophero-aide';
    aide.innerHTML = AIDE;
    scene.appendChild(aide);

    conteneur.appendChild(scene);

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
      function lancer() { if (balance && !minuteur) minuteur = setInterval(tic, 60); }
      function couper() { if (minuteur) { clearInterval(minuteur); minuteur = null; } }

      var sobre = window.matchMedia &&
                  window.matchMedia('(prefers-reduced-motion: reduce)').matches;
      if (!sobre && balance) {
        if ('IntersectionObserver' in window) {
          new IntersectionObserver(function (e) {
            visible = e[0].isIntersecting;
            visible ? lancer() : couper();
          }, { threshold: 0.05 }).observe(conteneur);
        } else { lancer(); }
        document.addEventListener('visibilitychange', function () {
          document.hidden ? couper() : lancer();
        });
      }

      scene.addEventListener('pointerdown', function (e) {
        saisi = true; tourne = false; x0 = e.clientX; i0 = i;
        scene.classList.add('ophero-saisi');
        scene.setPointerCapture(e.pointerId);
      });
      scene.addEventListener('pointermove', function (e) {
        if (!saisi) return;
        var pas = Math.max(8, scene.clientWidth / N * 1.4);
        var d = Math.round((e.clientX - x0) / pas);
        if (d !== 0 && !tourne) { tourne = true; scene.classList.add('ophero-manipule'); }
        afficher(i0 - d);
      });
      function relacher() {
        if (!saisi) return;
        saisi = false;
        scene.classList.remove('ophero-saisi');
        if (tourne) retour();
      }

      /* Retour progressif vers la face avant. Recaler directement la phase du
         sinus faisait sauter le masque de plusieurs vues d un coup des que
         l utilisateur le lachait hors de la plage de balancement. */
      function retour() {
        couper();
        var ecart = ((i + N + N / 2) % N) - N / 2;   /* -18..18, chemin court */
        if (ecart === 0) { t = 0; lancer(); return; }
        var pas = ecart > 0 ? -1 : 1;
        var glisse = setInterval(function () {
          if (saisi) { clearInterval(glisse); return; }
          ecart += pas;
          afficher(ecart);
          if (ecart === 0) { clearInterval(glisse); t = 0; lancer(); }
        }, 45);
      }
      scene.addEventListener('pointerup', relacher);
      scene.addEventListener('pointercancel', relacher);
      scene.addEventListener('pointerleave', relacher);

      /* Clavier : le masque reste manipulable sans souris ni ecran tactile. */
      scene.tabIndex = 0;
      scene.addEventListener('keydown', function (e) {
        if (e.key !== 'ArrowLeft' && e.key !== 'ArrowRight') return;
        e.preventDefault();
        couper();
        scene.classList.add('ophero-manipule');
        afficher(i + (e.key === 'ArrowRight' ? 1 : -1));
      });
    }
  }

  pret(function () {
    var url = (window.ONIRALA_360_URL || '').trim();
    if (!url) return;

    /* Heros de l accueil : la scene se substitue a la photo de la banniere. */
    var media = document.querySelector('[id$="image_banner_TVECWz"] .banner__media');
    if (media && !media.querySelector('.ophero')) {
      creer(media, url, media.querySelector('img'), true);
    }

    /* Fiche produit et ailleurs : tout conteneur .ophero-solo. */
    var solos = document.querySelectorAll('.ophero-solo');
    for (var k = 0; k < solos.length; k++) {
      if (!solos[k].querySelector('.ophero')) creer(solos[k], url, null, true);
    }
  });
})();
