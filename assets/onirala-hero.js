/* Masque Onirala : noir, en rotation, manipulable.

   Deux couches, dans cet ordre de fiabilite.

   1. Une image animee. C'est l'element <img> du theme lui-meme dont on
      remplace la source : il garde exactement la mise en page du theme,
      donc il ne peut pas se retrouver sans hauteur ni passer derriere
      autre chose. Sans JavaScript au-dela de cette ligne, le masque est
      deja noir et il tourne.

   2. Une planche de 36 vues posee par-dessus, activee seulement quand
      l'utilisateur attrape le masque. Si elle ne se charge pas, la
      couche 1 continue de tourner et rien ne disparait.

   Les versions precedentes ancraient la scene sur .banner__media et
   effacaient l'image du theme avant d'avoir la preuve que la scene
   occupait la moindre surface. Quand ce conteneur ne donnait pas de
   hauteur a la scene, les deux disparaissaient. */
(function () {
  var N = 36, COLS = 6, RANGEES = 6;

  function pret(f) {
    if (document.readyState !== 'loading') f();
    else document.addEventListener('DOMContentLoaded', f);
  }

  /* Un <picture> impose sa source via ses <source> : sans cela, remplacer
     le src de l'image ne changerait rien. Idem pour srcset et sizes. */
  function liberer(img) {
    var p = img.parentNode;
    if (p && p.tagName === 'PICTURE') {
      var s = p.querySelectorAll('source');
      for (var i = 0; i < s.length; i++) s[i].parentNode.removeChild(s[i]);
    }
    img.removeAttribute('srcset');
    img.removeAttribute('sizes');
    img.removeAttribute('loading');
    img.removeAttribute('width');
    img.removeAttribute('height');
  }

  function monter(img, planche) {
    liberer(img);
    img.src = window.ONIRALA_HERO_URL;
    img.classList.add('ophero-img');

    if (!planche) return;

    /* La planche n'est posee qu'une fois chargee, et dans une enveloppe
       calee sur l'image : sa boite est celle de l'image, au pixel pres. */
    var sonde = new Image();
    sonde.onload = function () {
      var boite = document.createElement('span');
      boite.className = 'ophero-boite';
      img.parentNode.insertBefore(boite, img);
      boite.appendChild(img);

      var vue = document.createElement('span');
      vue.className = 'ophero-vue';
      vue.style.backgroundImage = "url('" + planche + "')";
      boite.appendChild(vue);

      var aide = document.createElement('span');
      aide.className = 'ophero-aide';
      aide.textContent = 'Faites glisser pour tourner';
      boite.appendChild(aide);

      piloter(boite, vue);
    };
    sonde.src = planche;
  }

  function piloter(boite, vue) {
    var i = 0, saisi = false, x0 = 0, i0 = 0, tourne = false, retourEnCours = null;

    function afficher(n) {
      i = ((n % N) + N) % N;
      vue.style.backgroundPosition =
        (i % COLS) * 100 / (COLS - 1) + '% ' +
        Math.floor(i / COLS) * 100 / (RANGEES - 1) + '%';
    }
    afficher(0);

    boite.tabIndex = 0;
    boite.setAttribute('aria-label',
      'Masque de sommeil Onirala en 3D — faites glisser pour le tourner');

    /* On bascule sur la planche seulement le temps de la manipulation :
       le reste du temps c'est l'image animee qui tourne toute seule. */
    function prendreLaMain() {
      if (retourEnCours) { clearInterval(retourEnCours); retourEnCours = null; }
      boite.classList.add('ophero-manuel');
    }
    function rendreLaMain() {
      if (retourEnCours) clearInterval(retourEnCours);
      var ecart = ((i + N + N / 2) % N) - N / 2;   /* -18..18, chemin court */
      var pas = ecart > 0 ? -1 : 1;
      retourEnCours = setInterval(function () {
        if (saisi) { clearInterval(retourEnCours); retourEnCours = null; return; }
        if (ecart === 0) {
          clearInterval(retourEnCours); retourEnCours = null;
          boite.classList.remove('ophero-manuel');
          return;
        }
        ecart += pas;
        afficher(ecart);
      }, 45);
    }

    boite.addEventListener('pointerdown', function (e) {
      saisi = true; tourne = false; x0 = e.clientX; i0 = i;
      boite.classList.add('ophero-saisi');
      prendreLaMain();
      boite.setPointerCapture(e.pointerId);
    });
    boite.addEventListener('pointermove', function (e) {
      if (!saisi) return;
      var pas = Math.max(8, boite.clientWidth / N * 1.4);
      var d = Math.round((e.clientX - x0) / pas);
      if (d !== 0 && !tourne) { tourne = true; boite.classList.add('ophero-vu'); }
      afficher(i0 - d);
    });
    function relacher() {
      if (!saisi) return;
      saisi = false;
      boite.classList.remove('ophero-saisi');
      rendreLaMain();
    }
    boite.addEventListener('pointerup', relacher);
    boite.addEventListener('pointercancel', relacher);
    boite.addEventListener('pointerleave', relacher);

    boite.addEventListener('keydown', function (e) {
      if (e.key !== 'ArrowLeft' && e.key !== 'ArrowRight') return;
      e.preventDefault();
      prendreLaMain();
      boite.classList.add('ophero-vu');
      afficher(i + (e.key === 'ArrowRight' ? 1 : -1));
    });
  }

  pret(function () {
    if (!window.ONIRALA_HERO_URL) return;
    var planche = (window.ONIRALA_360_URL || '').trim();

    var media = document.querySelector('[id$="image_banner_TVECWz"] .banner__media img');
    if (media && !media.classList.contains('ophero-img')) monter(media, planche);

    var solos = document.querySelectorAll('.ophero-solo');
    for (var k = 0; k < solos.length; k++) {
      if (solos[k].querySelector('.ophero-img')) continue;
      var img = document.createElement('img');
      img.alt = 'Masque de sommeil Onirala, vue rotative';
      solos[k].appendChild(img);
      monter(img, planche);
    }
  });
})();
