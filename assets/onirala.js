/* Onirala — interactions (progressive enhancement, échoue en silence) */
(function () {
  'use strict';
  if (window.__oniralaLoaded) return;
  window.__oniralaLoaded = true;
  var reduceMotion = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  var isTouch = window.matchMedia && window.matchMedia('(hover: none), (pointer: coarse)').matches;
  var HERO = '[id$="image_banner_TVECWz"]';

  function ready(fn) {
    if (document.readyState === 'loading') { document.addEventListener('DOMContentLoaded', fn); } else { fn(); }
  }

  function initHero() {
    try {
      var section = document.querySelector(HERO);
      if (!section || reduceMotion) return;
      var banner = section.querySelector('.banner');
      var media = section.querySelector('.banner__media');
      var img = media ? media.querySelector('img') : null;
      if (!banner) return;

      banner.addEventListener('pointermove', function (e) {
        var r = banner.getBoundingClientRect();
        banner.style.setProperty('--op-mx', ((e.clientX - r.left) / r.width) * 100 + '%');
        banner.style.setProperty('--op-my', ((e.clientY - r.top) / r.height) * 100 + '%');
      });

      if (img && media && !isTouch) {
        media.addEventListener('pointermove', function (e) {
          var r = media.getBoundingClientRect();
          var rotY = (((e.clientX - r.left) / r.width - 0.5) * 20).toFixed(2);
          var rotX = (((e.clientY - r.top) / r.height - 0.5) * -20).toFixed(2);
          img.style.transform = 'scale3d(1.08,1.08,1.08) rotateX(' + rotX + 'deg) rotateY(' + rotY + 'deg)';
        });
        media.addEventListener('pointerleave', function () { img.style.transform = ''; });
      }
    } catch (e) {}
  }

  function initHeroScroll() {
    try {
      var section = document.querySelector(HERO);
      if (!section || reduceMotion) return;
      var media = section.querySelector('.banner__media');
      if (!media) return;
      var ticking = false;

      function update() {
        ticking = false;
        var r = section.getBoundingClientRect();
        var vh = window.innerHeight || document.documentElement.clientHeight;
        var total = r.height + vh;
        var p = total > 0 ? 1 - r.bottom / total : 0;
        p = Math.max(0, Math.min(1, p));
        media.style.transform = 'translate3d(0,' + (-p * 70).toFixed(1) + 'px,0) scale(' + (1 - p * 0.14).toFixed(3) + ')';
        media.style.opacity = (1 - p * 0.85).toFixed(3);
      }
      function onScroll() { if (!ticking) { ticking = true; requestAnimationFrame(update); } }

      window.addEventListener('scroll', onScroll, { passive: true });
      window.addEventListener('resize', onScroll);
      update();
    } catch (e) {}
  }

  function initReveal() {
    try {
      var targets = document.querySelectorAll('[data-reveal]');
      if (!targets.length) return;
      if (reduceMotion || !('IntersectionObserver' in window)) {
        targets.forEach(function (el) { el.classList.add('op-visible'); });
        return;
      }
      var obs = new IntersectionObserver(function (entries) {
        entries.forEach(function (entry) {
          if (!entry.isIntersecting) return;
          var d = parseInt(entry.target.getAttribute('data-reveal-delay') || '0', 10);
          setTimeout(function () { entry.target.classList.add('op-visible'); }, d);
          obs.unobserve(entry.target);
        });
      }, { threshold: 0.15, rootMargin: '0px 0px -60px 0px' });
      targets.forEach(function (el) { obs.observe(el); });
    } catch (e) {}
  }


  /* --- Inclinaison 3D au curseur --- */
  function tilt(el, max, scale) {
    if (isTouch || reduceMotion) return;
    el.classList.add('op-tilt');
    el.addEventListener('pointermove', function (e) {
      var r = el.getBoundingClientRect();
      var rx = (((e.clientY - r.top) / r.height) - 0.5) * -2 * max;
      var ry = (((e.clientX - r.left) / r.width) - 0.5) * 2 * max;
      el.classList.add('op-tilting');
      el.style.transform = 'perspective(900px) rotateX(' + rx.toFixed(2) + 'deg) rotateY(' + ry.toFixed(2) + 'deg) scale(' + scale + ')';
    });
    el.addEventListener('pointerleave', function () {
      el.classList.remove('op-tilting');
      el.style.transform = '';
    });
  }

  function initTilt() {
    try {
      document.querySelectorAll('.op-card').forEach(function (el) { tilt(el, 9, 1.02); });
      document.querySelectorAll('.op-pdp-feature').forEach(function (el) { tilt(el, 5, 1.01); });
    } catch (e) {}
  }

  /* --- Galerie produit : profondeur 3D au survol --- */
  function initGallery3d() {
    try {
      if (isTouch || reduceMotion) return;
      var sec = document.querySelector('[id$="shop_product_details_JbqzwH"]');
      if (!sec) return;
      var imgs = Array.prototype.slice.call(sec.querySelectorAll('img'));
      var img = null;
      for (var i = 0; i < imgs.length; i++) {
        if (imgs[i].offsetWidth > 260 && imgs[i].offsetHeight > 260) { img = imgs[i]; break; }
      }
      if (!img) return;
      var host = img.parentElement;
      if (!host || /slick|swiper|track|slider/i.test(host.className || '')) return;
      host.style.perspective = '1100px';
      img.classList.add('op-gallery-3d');
      host.addEventListener('pointermove', function (e) {
        var r = host.getBoundingClientRect();
        var rx = (((e.clientY - r.top) / r.height) - 0.5) * -10;
        var ry = (((e.clientX - r.left) / r.width) - 0.5) * 14;
        img.classList.add('op-tilting');
        img.style.transform = 'rotateX(' + rx.toFixed(2) + 'deg) rotateY(' + ry.toFixed(2) + 'deg) scale(1.04)';
        img.style.filter = 'drop-shadow(0 24px 30px rgba(0,0,0,.18))';
      });
      host.addEventListener('pointerleave', function () {
        img.classList.remove('op-tilting');
        img.style.transform = '';
        img.style.filter = '';
      });
    } catch (e) {}
  }

  /* --- Chiffres qui s'incrementent --- */
  function initCounters() {
    try {
      var nums = document.querySelectorAll('.op-pdp-num');
      if (!nums.length || !('IntersectionObserver' in window)) return;
      var obs = new IntersectionObserver(function (entries) {
        entries.forEach(function (entry) {
          if (!entry.isIntersecting) return;
          var el = entry.target;
          obs.unobserve(el);
          var raw = el.textContent.trim();
          var m = raw.match(/^(\d+)(.*)$/);
          if (!m) return;
          var target = parseInt(m[1], 10);
          var suffix = m[2];
          if (reduceMotion || target === 0) return;
          var start = null, dur = 1100;
          function step(ts) {
            if (start === null) start = ts;
            var p = Math.min(1, (ts - start) / dur);
            var eased = 1 - Math.pow(1 - p, 3);
            el.textContent = Math.round(target * eased) + suffix;
            if (p < 1) requestAnimationFrame(step);
          }
          el.textContent = '0' + suffix;
          requestAnimationFrame(step);
        });
      }, { threshold: 0.6 });
      nums.forEach(function (n) { obs.observe(n); });
    } catch (e) {}
  }

  ready(function () { initHero(); initHeroScroll(); initReveal(); initTilt(); initGallery3d(); initCounters(); });
})();
