/* ==========================================================================
   AI OS Dashboard — boot sequence, telemetry counters, live console.
   No dependencies. Re-initialises on Shopify theme editor section events.
   ========================================================================== */
(function () {
  'use strict';

  var REDUCED = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  function pad(n) {
    return n < 10 ? '0' + n : String(n);
  }

  function easeOutExpo(t) {
    return t === 1 ? 1 : 1 - Math.pow(2, -10 * t);
  }

  function AiOsDashboard(root) {
    this.root = root;
    this.rafs = [];
    this.timers = [];
    this.observers = [];
    this.destroyed = false;
    this.init();
  }

  AiOsDashboard.prototype.init = function () {
    this.randomiseWaveform();
    this.startClock();
    this.bindParallax();

    if (REDUCED) {
      this.activate(true);
      return;
    }

    // Only now that JS is running do we let CSS hide the frame behind the boot
    // sequence — without this class the dashboard renders fully as static HTML.
    this.root.classList.add('is-armed');

    var self = this;
    if (!('IntersectionObserver' in window)) {
      this.activate();
      return;
    }

    var io = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (!entry.isIntersecting) return;
          io.disconnect();
          self.activate();
        });
      },
      { threshold: 0.2 }
    );

    io.observe(this.root);
    this.observers.push(io);
  };

  /* ------------------------------------------------------------ activation */

  AiOsDashboard.prototype.activate = function (immediate) {
    if (this.activated) return;
    this.activated = true;

    var self = this;
    var boot = this.root.querySelector('[data-aios-boot]');

    var run = function () {
      self.root.classList.add('is-live');
      self.countUp();
      self.startConsole();
    };

    if (immediate || !boot || this.root.dataset.aiosBootEnabled !== 'true') {
      this.root.classList.add('is-booted');
      run();
      return;
    }

    this.runBoot(boot, run);
  };

  AiOsDashboard.prototype.runBoot = function (boot, done) {
    var self = this;
    var fill = boot.querySelector('[data-aios-boot-fill]');
    var label = boot.querySelector('[data-aios-boot-label]');
    var steps = ['Initialising core', 'Calibrating sensors', 'Linking modules', 'Systems online'];
    var start = performance.now();
    var duration = 1600;

    var tick = function (now) {
      if (self.destroyed) return;
      var progress = Math.min((now - start) / duration, 1);
      if (fill) fill.style.width = (progress * 100).toFixed(1) + '%';
      if (label) {
        var index = Math.min(Math.floor(progress * steps.length), steps.length - 1);
        if (label.textContent !== steps[index]) label.textContent = steps[index];
      }
      if (progress < 1) {
        self.rafs.push(requestAnimationFrame(tick));
      } else {
        self.root.classList.add('is-booted');
        done();
      }
    };

    this.rafs.push(requestAnimationFrame(tick));
  };

  /* -------------------------------------------------------------- counters */

  AiOsDashboard.prototype.countUp = function () {
    var self = this;
    var nodes = this.root.querySelectorAll('[data-aios-count]');

    Array.prototype.forEach.call(nodes, function (node) {
      var target = parseFloat(node.getAttribute('data-aios-count'));
      if (isNaN(target)) return;

      var decimals = parseInt(node.getAttribute('data-aios-decimals'), 10) || 0;

      if (REDUCED) {
        node.textContent = target.toFixed(decimals);
        return;
      }

      var duration = 1600;
      var start = performance.now();

      var tick = function (now) {
        if (self.destroyed) return;
        var progress = Math.min((now - start) / duration, 1);
        node.textContent = (target * easeOutExpo(progress)).toFixed(decimals);
        if (progress < 1) self.rafs.push(requestAnimationFrame(tick));
      };

      self.rafs.push(requestAnimationFrame(tick));
    });
  };

  /* ----------------------------------------------------------------- clock */

  AiOsDashboard.prototype.startClock = function () {
    var node = this.root.querySelector('[data-aios-clock]');
    if (!node) return;

    var render = function () {
      var now = new Date();
      node.textContent = pad(now.getHours()) + ':' + pad(now.getMinutes()) + ':' + pad(now.getSeconds());
    };

    render();
    this.timers.push(setInterval(render, 1000));
  };

  /* --------------------------------------------------------------- console */

  AiOsDashboard.prototype.startConsole = function () {
    var box = this.root.querySelector('[data-aios-console]');
    if (!box) return;

    var source = this.root.querySelector('[data-aios-logs]');
    var lines = [];

    if (source) {
      try {
        lines = JSON.parse(source.textContent) || [];
      } catch (error) {
        lines = [];
      }
    }

    lines = lines.filter(function (line) {
      return typeof line === 'string' && line.trim() !== '';
    });

    if (!lines.length) return;

    var maxLines = parseInt(this.root.dataset.aiosConsoleLines, 10) || 6;

    if (REDUCED) {
      box.innerHTML = '';
      lines.slice(0, maxLines).forEach(
        function (line) {
          box.appendChild(this.buildLogRow(line, line.length));
        }.bind(this)
      );
      return;
    }

    this.consoleState = { box: box, lines: lines, index: 0, maxLines: maxLines };
    box.innerHTML = '';
    this.typeNextLine();
  };

  AiOsDashboard.prototype.buildLogRow = function (text, revealed) {
    var row = document.createElement('div');
    row.className = 'ai-os__log';

    var time = document.createElement('span');
    time.className = 'ai-os__log-time';
    var now = new Date();
    time.textContent = pad(now.getHours()) + ':' + pad(now.getMinutes()) + ':' + pad(now.getSeconds());

    var body = document.createElement('span');
    body.className = 'ai-os__log-text';
    body.textContent = text.slice(0, revealed);

    row.appendChild(time);
    row.appendChild(body);
    return row;
  };

  AiOsDashboard.prototype.typeNextLine = function () {
    if (this.destroyed || !this.consoleState) return;

    var state = this.consoleState;
    var text = state.lines[state.index % state.lines.length];
    var row = this.buildLogRow(text, 0);
    var body = row.querySelector('.ai-os__log-text');
    var caret = document.createElement('i');
    caret.className = 'ai-os__caret';

    state.box.appendChild(row);
    body.appendChild(caret);

    while (state.box.children.length > state.maxLines) {
      state.box.removeChild(state.box.firstChild);
    }

    var self = this;
    var revealed = 0;
    var speed = parseInt(this.root.dataset.aiosTypingSpeed, 10) || 26;

    var step = function () {
      if (self.destroyed) return;
      revealed += 1;
      body.textContent = text.slice(0, revealed);
      if (revealed < text.length) {
        body.appendChild(caret);
        self.timers.push(setTimeout(step, speed));
      } else {
        body.appendChild(caret);
        state.index += 1;
        self.timers.push(
          setTimeout(function () {
            if (caret.parentNode) caret.parentNode.removeChild(caret);
            self.typeNextLine();
          }, 1400)
        );
      }
    };

    this.timers.push(setTimeout(step, speed));
  };

  /* -------------------------------------------------------------- waveform */

  AiOsDashboard.prototype.randomiseWaveform = function () {
    var bars = this.root.querySelectorAll('.ai-os__wave i');
    Array.prototype.forEach.call(bars, function (bar) {
      bar.style.animationDuration = (0.5 + Math.random() * 0.9).toFixed(2) + 's';
      bar.style.animationDelay = '-' + (Math.random() * 1.2).toFixed(2) + 's';
    });
  };

  /* -------------------------------------------------------------- parallax */

  AiOsDashboard.prototype.bindParallax = function () {
    if (REDUCED) return;
    if (this.root.dataset.aiosParallax !== 'true') return;
    if (!window.matchMedia || !window.matchMedia('(hover: hover) and (pointer: fine)').matches) return;

    var frame = this.root.querySelector('[data-aios-frame]');
    if (!frame) return;

    var self = this;

    this.onMove = function (event) {
      var rect = frame.getBoundingClientRect();
      if (!rect.width || !rect.height) return;
      var x = (event.clientX - rect.left) / rect.width - 0.5;
      var y = (event.clientY - rect.top) / rect.height - 0.5;
      frame.style.setProperty('--aios-tilt-y', (x * 5).toFixed(2) + 'deg');
      frame.style.setProperty('--aios-tilt-x', (-y * 3.5).toFixed(2) + 'deg');
    };

    this.onLeave = function () {
      frame.style.setProperty('--aios-tilt-y', '0deg');
      frame.style.setProperty('--aios-tilt-x', '0deg');
    };

    this.root.addEventListener('mousemove', this.onMove);
    this.root.addEventListener('mouseleave', this.onLeave);
    this.parallaxBound = true;
    void self;
  };

  /* --------------------------------------------------------------- destroy */

  AiOsDashboard.prototype.destroy = function () {
    this.destroyed = true;
    this.rafs.forEach(cancelAnimationFrame);
    this.timers.forEach(clearTimeout);
    this.timers.forEach(clearInterval);
    this.observers.forEach(function (observer) {
      observer.disconnect();
    });
    if (this.parallaxBound) {
      this.root.removeEventListener('mousemove', this.onMove);
      this.root.removeEventListener('mouseleave', this.onLeave);
    }
    delete this.root.aiOsDashboard;
  };

  /* ------------------------------------------------------------------ boot */

  function mount(scope) {
    var roots = (scope || document).querySelectorAll('[data-ai-os]');
    Array.prototype.forEach.call(roots, function (root) {
      if (root.aiOsDashboard) return;
      root.aiOsDashboard = new AiOsDashboard(root);
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function () {
      mount();
    });
  } else {
    mount();
  }

  document.addEventListener('shopify:section:load', function (event) {
    mount(event.target);
  });

  document.addEventListener('shopify:section:unload', function (event) {
    var roots = event.target.querySelectorAll('[data-ai-os]');
    Array.prototype.forEach.call(roots, function (root) {
      if (root.aiOsDashboard) root.aiOsDashboard.destroy();
    });
  });

  window.AiOsDashboard = AiOsDashboard;
})();
