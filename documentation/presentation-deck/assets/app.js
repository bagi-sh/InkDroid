/* ==========================================================================
   INKDROID PRESENTATION DECK - KEYNOTE & STORYTELLING INTERACTIVE ENGINE
   Física Orgânica do M3, Lava Lamp Canvas, Barra Ondulada, Container Transform e Scroll Livre
   ========================================================================== */

document.addEventListener('DOMContentLoaded', () => {
  const slides = Array.from(document.querySelectorAll('.deck-slide'));
  const totalSlides = slides.length;
  let currentSlideIndex = 0;
  let isNavigating = false;

  const dock = document.querySelector('.keynote-dock');
  const dockCounter = document.getElementById('dock-counter');
  const btnPrev = document.getElementById('dock-prev');
  const btnNext = document.getElementById('dock-next');
  const btnFullscreen = document.getElementById('dock-fullscreen');
  const btnTheme = document.getElementById('dock-theme');
  const btnMode = document.getElementById('dock-mode');
  const viewport = document.getElementById('deck-viewport');

  // ==========================================================================
  // 1. MOTOR DO FUNDO ANIMADO LAVA LAMP MATERIAL YOU (M3 Polar Morphing)
  // ==========================================================================
  const lavaCanvas = document.getElementById('m3-lava-lamp');
  if (lavaCanvas) {
    const ctx = lavaCanvas.getContext('2d');
    let width = (lavaCanvas.width = window.innerWidth);
    let height = (lavaCanvas.height = window.innerHeight);

    window.addEventListener('resize', () => {
      width = lavaCanvas.width = window.innerWidth;
      height = lavaCanvas.height = window.innerHeight;
    });

    // Função polar da Pílula / Superelipse M3
    function getPillRadius(theta, a, b, n = 3.2) {
      const cosT = Math.abs(Math.cos(theta));
      const sinT = Math.abs(Math.sin(theta));
      return 1 / Math.pow(Math.pow(cosT / a, n) + Math.pow(sinT / b, n), 1 / n);
    }

    // Função polar da Estrela M3 de 8 pontas arredondada
    function getStarRadius(theta, R, A, points = 8) {
      return R + A * Math.cos(points * theta);
    }

    // Partículas orgânicas com visibilidade balanceada e estética M3
    const blobs = [
      { x: width * 0.18, y: height * 0.22, vx: 0.32, vy: 0.20, r: 160, time: 0.0, rot: 0.0, rotSpeed: 0.0050, speed: 0.014, color: 'rgba(61, 220, 132, 0.22)' },
      { x: width * 0.82, y: height * 0.28, vx: -0.26, vy: 0.18, r: 190, time: 2.1, rot: 1.2, rotSpeed: 0.0040, speed: 0.010, color: 'rgba(21, 70, 42, 0.35)' },
      { x: width * 0.48, y: height * 0.70, vx: 0.22, vy: -0.22, r: 175, time: 4.3, rot: 2.4, rotSpeed: 0.0045, speed: 0.012, color: 'rgba(53, 84, 63, 0.28)' },
      { x: width * 0.20, y: height * 0.80, vx: -0.18, vy: -0.20, r: 145, time: 1.2, rot: 0.8, rotSpeed: 0.0055, speed: 0.015, color: 'rgba(61, 220, 132, 0.18)' },
      { x: width * 0.80, y: height * 0.78, vx: 0.20, vy: 0.24, r: 165, time: 3.5, rot: 3.1, rotSpeed: 0.0038, speed: 0.011, color: 'rgba(166, 212, 222, 0.20)' }
    ];

    function drawLavaLamp() {
      if (document.hidden) {
        requestAnimationFrame(drawLavaLamp);
        return;
      }
      ctx.clearRect(0, 0, width, height);
      const isLight = document.documentElement.getAttribute('data-theme') === 'light';

      blobs.forEach(b => {
        b.x += b.vx;
        b.y += b.vy;
        if (b.x < -b.r) b.x = width + b.r;
        if (b.x > width + b.r) b.x = -b.r;
        if (b.y < -b.r) b.y = height + b.r;
        if (b.y > height + b.r) b.y = -b.r;

        ctx.save();
        ctx.translate(b.x, b.y);

        // Curva de interpolação sinusoidal natural (0 = estrela, 1 = pílula)
        const t = (Math.sin(b.time - Math.PI / 2) + 1) / 2;

        // Rotação contínua e unidirecional no sentido horário (nunca volta para trás)
        b.rot += b.rotSpeed * (1 + 0.35 * Math.sin(b.time * 2));
        ctx.rotate(b.rot);

        ctx.beginPath();
        const points = 120;
        const baseR = b.r;

        for (let i = 0; i <= points; i++) {
          const theta = (i / points) * Math.PI * 2;
          const rStar = getStarRadius(theta, baseR, baseR * 0.18, 8);
          const rPill = getPillRadius(theta, baseR * 1.25, baseR * 0.75, 3.2);
          const r = rStar * (1 - t) + rPill * t;

          const px = r * Math.cos(theta);
          const py = r * Math.sin(theta);
          if (i === 0) ctx.moveTo(px, py);
          else ctx.lineTo(px, py);
        }

        ctx.closePath();
        ctx.fillStyle = isLight ? b.color.replace(/0\.\d+\)/, '0.10)') : b.color;
        ctx.fill();
        ctx.restore();

        b.time += b.speed;
      });

      requestAnimationFrame(drawLavaLamp);
    }
    requestAnimationFrame(drawLavaLamp);
  }

  // ==========================================================================
  // 2. BARRA DE PROGRESSO ONDULADA M3 EXPRESSIVE (Android 14)
  // ==========================================================================
  const wavePathEl = document.getElementById('m3-wavy-path');
  const wavyFillEl = document.getElementById('m3-wavy-fill');

  if (wavePathEl) {
    let wavePath = "M 0 10 ";
    for (let i = 0; i < 125; i++) {
      let x = i * 40;
      wavePath += `Q ${x + 10} 2, ${x + 20} 10 T ${x + 40} 10 `;
    }
    wavePathEl.setAttribute('d', wavePath);
  }

  function updateProgressBar(percentage) {
    if (wavyFillEl) {
      wavyFillEl.style.width = `${Math.min(100, Math.max(4.76, percentage))}%`;
    }
  }

  // ==========================================================================
  // 3. M3 CONTAINER TRANSFORM (BASEADO EM CONTAINERTITIONEXAMPLE.HTML)
  // ==========================================================================
  const modalOverlay = document.getElementById('m3-modal-overlay');
  const modalDialog = document.getElementById('m3-modal-dialog');
  const dialogCollapsed = document.getElementById('m3-dialog-collapsed');
  const dialogExpanded = document.getElementById('m3-dialog-expanded');
  const modalCloseBtn = document.getElementById('m3-modal-close');
  const modalBackdrop = document.getElementById('m3-modal-backdrop');

  let activeCard = null;
  let isTransforming = false;

  function expandCard(card) {
    if (isTransforming || !modalOverlay || !modalDialog) return;
    if (modalDialog.classList.contains('expanded')) return;

    const collapsedEl = card.querySelector('.card-collapsed');
    const expandedEl = card.querySelector('.card-expanded');
    if (!collapsedEl || !expandedEl) return;

    isTransforming = true;
    activeCard = card;

    // 1. Captura a posição exata do card antes de expandir (conforme o exemplo)
    const rect = card.getBoundingClientRect();

    // 2. Prepara os conteúdos para o cross-fade interno
    dialogCollapsed.innerHTML = collapsedEl.innerHTML;
    dialogExpanded.innerHTML = expandedEl.innerHTML;

    // 3. Posiciona o dialog exatamente nas coordenadas do card inicial
    modalDialog.style.transition = 'none';
    modalDialog.classList.remove('expanded');
    modalDialog.style.top = `${rect.top}px`;
    modalDialog.style.left = `${rect.left}px`;
    modalDialog.style.width = `${rect.width}px`;
    modalDialog.style.height = `${rect.height}px`;

    // 4. Ativa o overlay e deixa o card original temporariamente invisível
    modalOverlay.classList.add('active');
    activeCard.style.opacity = '0';
    document.body.style.overflow = 'hidden';

    // 5. Força o reflow do navegador para aplicar os estilos iniciais (conforme o exemplo)
    modalDialog.getBoundingClientRect();

    // 6. Calcula dimensões e posição centralizada do card expandido (sem ser tela cheia)
    const targetW = Math.min(window.innerWidth * 0.90, 880);
    const targetH = Math.min(window.innerHeight * 0.86, 660);
    const targetX = (window.innerWidth - targetW) / 2;
    const targetY = (window.innerHeight - targetH) / 2;

    // 7. Dispara a transição cúbica idêntica ao containertransitionexample.html
    requestAnimationFrame(() => {
      modalDialog.style.transition = 'all 0.6s cubic-bezier(0.2, 0, 0, 1)';
      modalDialog.classList.add('expanded');
      modalDialog.style.top = `${targetY}px`;
      modalDialog.style.left = `${targetX}px`;
      modalDialog.style.width = `${targetW}px`;
      modalDialog.style.height = `${targetH}px`;

      setTimeout(() => {
        isTransforming = false;
      }, 600);
    });
  }

  function closeExpandedCard(e) {
    if (e) e.stopPropagation();
    if (isTransforming || !activeCard || !modalOverlay || !modalDialog) return;
    isTransforming = true;

    // Pega o retângulo atual do card original
    const rect = activeCard.getBoundingClientRect();

    // 1. Inicia recolhimento reverso para as coordenadas originais
    modalDialog.classList.remove('expanded');
    modalDialog.style.top = `${rect.top}px`;
    modalDialog.style.left = `${rect.left}px`;
    modalDialog.style.width = `${rect.width}px`;
    modalDialog.style.height = `${rect.height}px`;

    // 2. Transiciona o fade do overlay
    modalOverlay.classList.remove('active');

    // 3. Ao fim da animação, restaura estado original
    setTimeout(() => {
      if (activeCard) {
        activeCard.style.opacity = '1';
        activeCard = null;
      }
      dialogCollapsed.innerHTML = '';
      dialogExpanded.innerHTML = '';
      modalDialog.style.transition = 'none';
      document.body.style.overflow = '';
      isTransforming = false;
    }, 600);
  }

  document.querySelectorAll('.m3-expandable-card').forEach(card => {
    card.addEventListener('click', (e) => {
      e.stopPropagation();
      expandCard(card);
    });
  });

  if (modalCloseBtn) modalCloseBtn.addEventListener('click', closeExpandedCard);
  if (modalBackdrop) modalBackdrop.addEventListener('click', closeExpandedCard);
  window.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && modalOverlay && modalOverlay.classList.contains('active')) {
      closeExpandedCard(e);
    }
  });

  // ==========================================================================
  // 4. MODO SCROLL LIVRE (FREE SCROLL) & KEYNOTE SNAPPING
  // ==========================================================================
  let isFreeScroll = false;

  function initFreeScrollObserver() {
    const freeObserver = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          entry.target.classList.add('in-view');
          const idx = slides.indexOf(entry.target);
          if (idx !== -1 && isFreeScroll) {
            currentSlideIndex = idx;
            if (dockCounter) {
              dockCounter.textContent = `${String(idx + 1).padStart(2, '0')} / ${String(totalSlides).padStart(2, '0')}`;
            }
          }
        }
      });
    }, { root: viewport, threshold: 0.2 });

    slides.forEach(slide => freeObserver.observe(slide));
  }

  function setMode(freeScroll) {
    isFreeScroll = freeScroll;
    if (isFreeScroll) {
      viewport.classList.add('mode-free-scroll');
      if (btnMode) btnMode.textContent = '🎴 Modo Slides';
      initFreeScrollObserver();
    } else {
      viewport.classList.remove('mode-free-scroll');
      if (btnMode) btnMode.textContent = '📜 Scroll Livre';
      scrollToSlide(currentSlideIndex);
    }
  }

  if (btnMode) {
    btnMode.addEventListener('click', () => setMode(!isFreeScroll));
  }

  // Rastreamento contínuo de rolagem na barra ondulada (no modo Scroll Livre)
  viewport.addEventListener('scroll', () => {
    if (!isFreeScroll) return;
    const maxScroll = viewport.scrollHeight - viewport.clientHeight;
    if (maxScroll > 0) {
      const pct = (viewport.scrollTop / maxScroll) * 100;
      updateProgressBar(pct);
    }
  }, { passive: true });

  // ==========================================================================
  // 5. GERENCIAMENTO DO DOCK (APENAS NA PARTE INFERIOR DA TELA)
  // ==========================================================================
  const BOTTOM_THRESHOLD_PX = 75; // Zona de ativação na margem inferior
  let hideDockTimeout = null;
  let isMouseOverDock = false;

  function showDock() {
    if (!dock) return;
    clearTimeout(hideDockTimeout);
    dock.classList.add('visible');
  }

  function hideDock(delay = 200) {
    if (!dock || isMouseOverDock) return;
    clearTimeout(hideDockTimeout);
    hideDockTimeout = setTimeout(() => {
      if (!isMouseOverDock) {
        dock.classList.remove('visible');
      }
    }, delay);
  }

  if (dock) {
    dock.addEventListener('mouseenter', () => {
      isMouseOverDock = true;
      showDock();
    });
    dock.addEventListener('mouseleave', (e) => {
      isMouseOverDock = false;
      if (e.clientY < window.innerHeight - BOTTOM_THRESHOLD_PX) {
        hideDock(150);
      }
    });
  }

  window.addEventListener('mousemove', (e) => {
    // A dock só aparece se o mouse estiver encostado na margem inferior da tela
    if (e.clientY >= window.innerHeight - BOTTOM_THRESHOLD_PX) {
      showDock();
    } else if (!isMouseOverDock) {
      hideDock(150);
    }
  }, { passive: true });

  function updateDock(index) {
    currentSlideIndex = index;
    const formatted = `${String(index + 1).padStart(2, '0')} / ${String(totalSlides).padStart(2, '0')}`;
    if (dockCounter) dockCounter.textContent = formatted;

    if (!isFreeScroll) {
      const pct = ((index + 1) / totalSlides) * 100;
      updateProgressBar(pct);
    }

    triggerSlideAnimations(slides[index]);
  }

  function scrollToSlide(index) {
    if (index < 0 || index >= totalSlides) return;
    isNavigating = true;
    currentSlideIndex = index;
    slides[index].scrollIntoView({ behavior: 'smooth' });
    updateDock(index);
    setTimeout(() => {
      isNavigating = false;
    }, 650);
  }

  if (btnPrev) btnPrev.addEventListener('click', () => scrollToSlide(currentSlideIndex - 1));
  if (btnNext) btnNext.addEventListener('click', () => scrollToSlide(currentSlideIndex + 1));

  // Navegação por teclado
  window.addEventListener('keydown', (e) => {
    if (modalOverlay && modalOverlay.classList.contains('active')) return;
    if (['ArrowRight', 'Space', 'PageDown', 'KeyJ'].includes(e.code) && !isFreeScroll) {
      e.preventDefault();
      scrollToSlide(currentSlideIndex + 1);
    } else if (['ArrowLeft', 'PageUp', 'KeyK'].includes(e.code) && !isFreeScroll) {
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

  // Scroll Snap Observer para modo Keynote com bloqueio durante navegação programática
  const keynoteObserver = new IntersectionObserver((entries) => {
    if (isNavigating || isFreeScroll) return;
    entries.forEach(entry => {
      if (entry.isIntersecting && entry.intersectionRatio >= 0.65) {
        const idx = slides.indexOf(entry.target);
        if (idx !== -1 && idx !== currentSlideIndex) {
          updateDock(idx);
        }
      }
    });
  }, { root: viewport, threshold: 0.65 });

  slides.forEach(slide => keynoteObserver.observe(slide));

  // ==========================================================================
  // 6. ANIMAÇÕES DE ENTRADA DOS ELEMENTOS (Anime.js + Curvas Bézier M3)
  // ==========================================================================
  function triggerSlideAnimations(slideEl) {
    if (typeof anime === 'undefined' || !slideEl) return;

    const elementsToAnimate = slideEl.querySelectorAll('.slide-title, .floating-lead, .floating-paragraph, .hero-bullet-item, .bento-card, .colossal-metric, .m3-expandable-card');
    if (elementsToAnimate.length) {
      anime({
        targets: elementsToAnimate,
        translateY: [24, 0],
        opacity: [0, 1],
        easing: 'cubicBezier(0.05, 0.7, 0.1, 1.0)', // M3 Decelerate
        duration: 650,
        delay: anime.stagger(50)
      });
    }

    const mascot = slideEl.querySelector('.bugdroid-peeking-top, .bugdroid-floating-side, .bugdroid-perched');
    if (mascot) {
      anime({
        targets: mascot,
        scale: [0.88, 1],
        opacity: [0, 1],
        easing: 'cubicBezier(0.2, 0, 0, 1)',
        duration: 700
      });
    }

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

  // ==========================================================================
  // 7. SIMULADOR DO TABLET MULTILASER M8 4G (Slide 19)
  // ==========================================================================
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
        const stockContent = document.getElementById('sim-content-stock');
        const inkContent = document.getElementById('sim-content-ink');

        if (mode === 'monochrome') {
          if (simModeText) simModeText.textContent = 'E-Ink Monocromático';
          if (simHzText) simHzText.textContent = '30 Hz (Anims: 0.0x)';
          if (stockContent) stockContent.style.display = 'none';
          if (inkContent) inkContent.style.display = 'flex';
        } else if (mode === 'blue') {
          if (simModeText) simModeText.textContent = 'Filtro Luz Âmbar (3000K)';
          if (simHzText) simHzText.textContent = '30 Hz (Anims: 0.0x)';
          if (stockContent) stockContent.style.display = 'none';
          if (inkContent) inkContent.style.display = 'flex';
        } else {
          if (simModeText) simModeText.textContent = 'Padrão Fábrica (Bloatware)';
          if (simHzText) simHzText.textContent = '60 Hz (Anims: 1.0x)';
          if (stockContent) stockContent.style.display = 'flex';
          if (inkContent) inkContent.style.display = 'none';
        }
      });
    });
  }

  // Inicialização
  triggerSlideAnimations(slides[0]);
  updateProgressBar((1 / totalSlides) * 100);
});
