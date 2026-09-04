/* Masque du heros : vues pre-rendues, pas de WebGL.
   La version three.js rendait le masque gris chez le client : Safari
   n honore pas le mode "sans conversion" impose au moteur de rendu et
   re-encode la sortie. Plutot que de courir apres l espace colorimetrique
   d un navigateur que je ne peux pas tester, les vues sont cuites une fois
   pour toutes a la bonne couleur. Ce qui s affiche est exactement ce qui a
   ete rendu, partout, pour 119 Ko et aucune dependance. */
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
    /* Decoratif : la photo au-dessous porte son texte alternatif. */
    scene.setAttribute('aria-hidden', 'true');
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

    /* On n efface la photo plate qu une fois la planche vraiment chargee,
       sinon un echec reseau laisserait un trou a la place du produit. */
    var img = new Image();
    img.onload = function () {
      scene.classList.add('ophero-prete');
      if (plat) { plat.style.transition = 'opacity .5s ease'; plat.style.opacity = '0'; }
      demarrer();
    };
    img.src = url;

    function demarrer() {
      var sobre = window.matchMedia &&
                  window.matchMedia('(prefers-reduced-motion: reduce)').matches;
      if (sobre) return;
      /* Balancement doux autour de la vue de face plutot qu un tour complet :
         de face le masque est reconnaissable, de profil il devient une
         tranche. On oscille sur environ +/- 50 degres, ce qui suffit a lire
         le volume sans jamais montrer un angle ingrat. */
      var visible = true, minuteur = null, t = 0, AMPLITUDE = 5;
      function tic() {
        if (!visible) return;
        t += 0.045;
        afficher(Math.round(Math.sin(t) * AMPLITUDE));
      }
      function lancer() { if (!minuteur) minuteur = setInterval(tic, 60); }
      function couper() { if (minuteur) { clearInterval(minuteur); minuteur = null; } }
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
  });
})();
