/* Masque Onirala : noir, en rotation continue, manipulable a la main.

   Deux couches, dans cet ordre de fiabilite.

   1. Une image animee de 72 vues a 24 images par seconde. C'est une
      simple <img> : une fois chargee elle tourne sans une ligne de
      script, et rien ne peut la faire disparaitre.

   2. La planche des memes 72 vues, posee par-dessus, invisible au repos.
      Elle ne prend le relais que pendant la manipulation, puis rend la
      main. Si elle ne se charge pas, le masque tourne quand meme.

   La scene est un FRERE de l'image du theme, pas une enveloppe autour
   d'elle : dans cette banniere l'image est en position absolue dans un
   conteneur .media a hauteur calculee, donc l'envelopper la privait de
   sa boite. Et l'image du theme n'est masquee qu'une fois la notre
   affichee, par une classe posee sur le conteneur : tant que la notre
   n'est pas la, celle du theme reste visible. */
(function () {
  var COLS = 12, RANGEES = 6, N = COLS * RANGEES;

  function pret(f) {
    if (document.readyState !== 'loading') f();
    else document.addEventListener('DOMContentLoaded', f);
  }

  function creer(hote, planche) {
    if (hote.querySelector('.ophero-scene')) return;

    var scene = document.createElement('span');
    scene.className = 'ophero-scene';

    var img = document.createElement('img');
    img.className = 'ophero-img';
    img.alt = 'Masque de sommeil Onirala, vue rotative';
    img.decoding = 'async';
    /* Le conteneur du theme ne cede la place qu'une fois l'image animee
       vraiment affichee. Sans cette condition, un echec de chargement
       laissait la banniere vide. */
    img.addEventListener('load', function () { hote.classList.add('ophero-en-place'); });
    img.src = window.ONIRALA_TOUR_URL;
    scene.appendChild(img);

    var vue = document.createElement('span');
    vue.className = 'ophero-vue';
    scene.appendChild(vue);

    var aide = document.createElement('span');
    aide.className = 'ophero-aide';
    aide.textContent = 'Faites glisser pour tourner';
    scene.appendChild(aide);

    hote.appendChild(scene);

    if (!planche) return;
    var sonde = new Image();
    sonde.onload = function () {
      vue.style.backgroundImage = "url('" + planche + "')";
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
    if (!window.ONIRALA_TOUR_URL) return;
    var planche = (window.ONIRALA_PLANCHE_URL || '').trim();

    var media = document.querySelector('[id$="image_banner_TVECWz"] .banner__media .media')
             || document.querySelector('[id$="image_banner_TVECWz"] .banner__media');
    if (media) creer(media, planche);

    var solos = document.querySelectorAll('.ophero-solo');
    for (var k = 0; k < solos.length; k++) creer(solos[k], planche);
  });
})();
