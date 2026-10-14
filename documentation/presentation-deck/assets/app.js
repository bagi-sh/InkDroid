/* ==========================================================================
   INKDROID PRESENTATION DECK - KEYNOTE INTERACTIVE ENGINE
   Física Orgânica do M3, Anime.js Integrado, Contadores e Gestão de Slides
   ========================================================================== */

document.addEventListener('DOMContentLoaded', () => {
  const slides = Array.from(document.querySelectorAll('.deck-slide'));
  const totalSlides = slides.length;
  let currentSlideIndex = 0;

  const dock = document.querySelector('.keynote-dock');
  const dockCounter = document.getElementById('dock-counter');
  const btnPrev = document.getElementById('dock-prev');
  const btnNext = document.getElementById('dock-next');
  const btnFullscreen = document.getElementById('dock-fullscreen');
  const btnTheme = document.getElementById('dock-theme');
  const progressBar = document.getElementById('keynote-progress');
  const viewport = document.getElementById('deck-viewport');

  // Gerenciamento de visibilidade do dock flutuante (Auto-hide com timeout)
  let dockTimer = null;
  let isMouseOverDock = false;

  function showDockBriefly(duration = 2500) {
    if (!dock) return;
    dock.classList.add('visible');
    clearTimeout(dockTimer);
    if (!isMouseOverDock) {
      dockTimer = setTimeout(() => {
        dock.classList.remove('visible');
      }, duration);
    }
  }

  if (dock) {
    dock.addEventListener('mouseenter', () => {
      isMouseOverDock = true;
      clearTimeout(dockTimer);
      dock.classList.add('visible');
    });
    dock.addEventListener('mouseleave', () => {
      isMouseOverDock = false;
      showDockBriefly(1500);
    });
  }

  window.addEventListener('mousemove', () => showDockBriefly(), { passive: true });

  // Atualiza dock e barra de progresso
  function updateDock(index) {
    currentSlideIndex = index;
    const formatted = `${String(index + 1).padStart(2, '0')} / ${String(totalSlides).padStart(2, '0')}`;
    if (dockCounter) dockCounter.textContent = formatted;
    if (progressBar) {
      const pct = ((index + 1) / totalSlides) * 100;
      progressBar.style.width = `${pct}%`;
    }

    // Mostra brevemente ao trocar de slide
    showDockBriefly();

    // Dispara animação de entrada com Anime.js para o slide ativo
    triggerSlideAnimations(slides[index]);
  }

  function scrollToSlide(index) {
    if (index < 0 || index >= totalSlides) return;
    slides[index].scrollIntoView({ behavior: 'smooth' });
    updateDock(index);
  }

  if (btnPrev) btnPrev.addEventListener('click', () => scrollToSlide(currentSlideIndex - 1));
  if (btnNext) btnNext.addEventListener('click', () => scrollToSlide(currentSlideIndex + 1));

  // Navegação por teclado
  window.addEventListener('keydown', (e) => {
    if (['ArrowRight', 'Space', 'PageDown', 'KeyJ'].includes(e.code)) {
      e.preventDefault();
      scrollToSlide(currentSlideIndex + 1);
    } else if (['ArrowLeft', 'PageUp', 'KeyK'].includes(e.code)) {
      e.preventDefault();
      scrollToSlide(currentSlideIndex - 1);
    } else if (e.code === 'KeyF') {
      toggleFullscreen();
    }
  });

  function toggleFullscreen() {
    if (!document.fullscreenElement) {
      document.documentElement.requestFullscreen().catch(() => {});
    } else {
      document.exitFullscreen().catch(() => {});
    }
  }
  if (btnFullscreen) btnFullscreen.addEventListener('click', toggleFullscreen);

  // Alternador de tema M3
  function initTheme() {
    const saved = localStorage.getItem('inkdroid-theme') || 'dark';
    document.documentElement.setAttribute('data-theme', saved);
    if (btnTheme) btnTheme.textContent = saved === 'dark' ? '☀️ Claro' : '🌙 Escuro';

    if (btnTheme) {
      btnTheme.addEventListener('click', () => {
        const isDark = document.documentElement.getAttribute('data-theme') === 'dark';
        const next = isDark ? 'light' : 'dark';
        document.documentElement.setAttribute('data-theme', next);
        localStorage.setItem('inkdroid-theme', next);
        btnTheme.textContent = next === 'dark' ? '☀️ Claro' : '🌙 Escuro';
      });
    }
  }
  initTheme();

  // Scroll Snap Observer
  const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        const idx = slides.indexOf(entry.target);
        if (idx !== -1) updateDock(idx);
      }
    });
  }, { root: viewport, threshold: 0.6 });

  slides.forEach(slide => observer.observe(slide));

  // Animações de Entrada dos Slides com Anime.js
  function triggerSlideAnimations(slideEl) {
    if (typeof anime === 'undefined') return;

    // Animação de entrada dos textos e títulos com Bézier M3
    const elementsToAnimate = slideEl.querySelectorAll('.slide-title, .floating-lead, .floating-paragraph, .hero-bullet-item, .bento-card, .colossal-metric');
    if (elementsToAnimate.length) {
      anime({
        targets: elementsToAnimate,
        translateY: [20, 0],
        opacity: [0, 1],
        easing: 'cubicBezier(0.05, 0.7, 0.1, 1.0)', // M3 Emphasized Decelerate
        duration: 600,
        delay: anime.stagger(60)
      });
    }

    // Bugdroids flutuantes
    const mascot = slideEl.querySelector('.bugdroid-peeking-top, .bugdroid-floating-side, .bugdroid-perched');
    if (mascot) {
      anime({
        targets: mascot,
        scale: [0.85, 1],
        opacity: [0, 1],
        easing: 'cubicBezier(0.2, 0, 0, 1)',
        duration: 700
      });
    }

    // Contadores numéricos dinâmicos
    const statCounters = slideEl.querySelectorAll('[data-counter-target]');
    statCounters.forEach(stat => {
      const targetVal = parseFloat(stat.getAttribute('data-counter-target'));
      if (isNaN(targetVal)) return;

      const obj = { val: 0 };
      anime({
        targets: obj,
        val: targetVal,
        easing: 'cubicBezier(0.2, 0, 0, 1)',
        duration: 1200,
        round: targetVal % 1 === 0 ? 1 : 10,
        update: function() {
          stat.textContent = targetVal % 1 === 0 ? Math.round(obj.val) : obj.val.toFixed(1);
        }
      });
    });
  }

  // Simulador do Tablet M8 (Slide 19)
  const tabletFrame = document.getElementById('tablet-frame');
  const simButtons = document.querySelectorAll('.sim-trigger-btn');
  const simModeText = document.getElementById('sim-current-mode');
  const simHzText = document.getElementById('sim-current-hz');

  if (tabletFrame && simButtons.length) {
    simButtons.forEach(btn => {
      btn.addEventListener('click', () => {
        const mode = btn.getAttribute('data-mode');
        simButtons.forEach(b => b.classList.remove('active'));
        btn.classList.add('active');

        tabletFrame.className = `tablet-frame-m3 mode-${mode}`;
        if (mode === 'monochrome') {
          if (simModeText) simModeText.textContent = 'E-Ink Monocromático';
          if (simHzText) simHzText.textContent = '30 Hz (Anims: 0.0x)';
        } else if (mode === 'blue') {
          if (simModeText) simModeText.textContent = 'Filtro Luz Azul (3000K)';
          if (simHzText) simHzText.textContent = '30 Hz (Anims: 0.0x)';
        } else {
          if (simModeText) simModeText.textContent = 'Padrão Fábrica (Bloatware)';
          if (simHzText) simHzText.textContent = '60 Hz (Anims: 1.0x)';
        }
      });
    });
  }

  // Dispara animação inicial e mostra dock brevemente
  triggerSlideAnimations(slides[0]);
  showDockBriefly(2500);
});
