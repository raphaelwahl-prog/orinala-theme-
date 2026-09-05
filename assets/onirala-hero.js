/* Masque Onirala : la couche de manipulation.

   Le masque lui-meme — noir, en balancement de -45 a +45 degres, sans
   jamais passer par le profil ou il n'est qu'une tranche — est une image
   animee posee en fond de conteneur par layout/theme.liquid. Il s'affiche
   et tourne sans une ligne de script.

   Ce fichier n'ajoute que la planche des 72 vues, par-dessus, pour
   pouvoir tourner le masque a la main. Elle n'est posee qu'une fois
   chargee et n'efface rien : si elle manque, le masque tourne quand meme.

   Les trois versions precedentes faisaient l'inverse — le script portait
   l'affichage — et a chaque echec c'est le masque entier qui manquait. */
(function () {
  var COLS = 12, RANGEES = 6, N = COLS * RANGEES;

  function pret(f) {
    if (document.readyState !== 'loading') f();
    else document.addEventListener('DOMContentLoaded', f);
  }

  function creer(hote, planche) {
    if (!planche || hote.querySelector('.ophero-scene')) return;

    /* Le masque anime est deja affiche : c'est le fond du conteneur, pose
       par la mise en page. Le script n'ajoute que de quoi le manipuler,
       et seulement une fois la planche chargee. Il ne peut donc plus
       faire disparaitre quoi que ce soit s'il echoue. */
    var sonde = new Image();
    sonde.onload = function () {
      var scene = document.createElement('span');
      scene.className = 'ophero-scene';

      var vue = document.createElement('span');
      vue.className = 'ophero-vue';
      vue.style.backgroundImage = "url('" + planche + "')";
      scene.appendChild(vue);

      var aide = document.createElement('span');
      aide.className = 'ophero-aide';
      aide.textContent = 'Faites glisser pour tourner';
      scene.appendChild(aide);

      hote.appendChild(scene);
      piloter(scene, vue);
    };
    sonde.src = planche;
  }

  function piloter(scene, vue) {
    var i = 0, saisi = false, x0 = 0, i0 = 0, retour = null;

    function afficher(n) {
      i = ((n % N) + N) % N;
      vue.style.backgroundPosition =
        (i % COLS) * 100 / (COLS - 1) + '% ' +
        Math.floor(i / COLS) * 100 / (RANGEES - 1) + '%';
    }
    afficher(0);

    scene.tabIndex = 0;
    scene.setAttribute('role', 'img');
    scene.setAttribute('aria-label',
      'Masque de sommeil Onirala en 3D — faites glisser pour le tourner');

    function prendre() {
      if (retour) { clearInterval(retour); retour = null; }
      scene.classList.add('ophero-manuel');
    }
    /* On revient doucement a la face avant avant de rendre la main a
       l'image animee : un saut sec entre la vue laissee et la premiere
       vue de l'animation se verrait. */
    function rendre() {
      if (retour) clearInterval(retour);
      var ecart = ((i + N + N / 2) % N) - N / 2;
      var pas = ecart > 0 ? -2 : 2;
      retour = setInterval(function () {
        if (saisi) { clearInterval(retour); retour = null; return; }
        if (Math.abs(ecart) <= 2) {
          clearInterval(retour); retour = null;
          scene.classList.remove('ophero-manuel');
          return;
        }
        ecart += pas;
        afficher(ecart);
      }, 40);
    }

    scene.addEventListener('pointerdown', function (e) {
      saisi = true; x0 = e.clientX; i0 = i;
      scene.classList.add('ophero-saisi', 'ophero-vu');
      prendre();
      scene.setPointerCapture(e.pointerId);
    });
    scene.addEventListener('pointermove', function (e) {
      if (!saisi) return;
      /* Un tour complet pour une largeur et demie de glissement. */
      afficher(i0 - Math.round((e.clientX - x0) / (scene.clientWidth * 1.5 / N)));
    });
    function relacher() {
      if (!saisi) return;
      saisi = false;
      scene.classList.remove('ophero-saisi');
      rendre();
    }
    scene.addEventListener('pointerup', relacher);
    scene.addEventListener('pointercancel', relacher);
    scene.addEventListener('pointerleave', relacher);

    scene.addEventListener('keydown', function (e) {
      if (e.key !== 'ArrowLeft' && e.key !== 'ArrowRight') return;
      e.preventDefault();
      prendre();
      scene.classList.add('ophero-vu');
      afficher(i + (e.key === 'ArrowRight' ? 2 : -2));
    });
  }

  pret(function () {
    var planche = (window.ONIRALA_PLANCHE_URL || '').trim();
    if (!planche) return;

    var media = document.querySelector('[id$="image_banner_TVECWz"] .banner__media .media');
    if (media) creer(media, planche);

    var solos = document.querySelectorAll('.ophero-solo');
    for (var k = 0; k < solos.length; k++) creer(solos[k], planche);
  });
})();
