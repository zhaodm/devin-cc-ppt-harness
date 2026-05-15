(function() {
  if (window.__pptNavInit) return;
  window.__pptNavInit = true;

  var pages = window.__pptPages || [];
  var currentIndex = -1;
  var steps = [];
  var stepIndex = 0;

  function findCurrentIndex() {
    var current = location.pathname.split('/').pop();
    for (var i = 0; i < pages.length; i++) {
      if (pages[i] === current) return i;
    }
    return -1;
  }

  function initSteps() {
    steps = Array.prototype.slice.call(document.querySelectorAll('.step'));
    if (steps.length === 0) return;
    steps.forEach(function(el, i) {
      if (i === 0) {
        el.classList.add('step-visible');
      } else {
        el.classList.remove('step-visible');
      }
    });
    stepIndex = 0;
  }

  function navigatePage(direction) {
    if (pages.length === 0) return;
    if (currentIndex === -1) currentIndex = findCurrentIndex();
    var next = currentIndex + direction;
    if (next >= 0 && next < pages.length) {
      location.href = pages[next];
    }
  }

  function forward() {
    if (steps.length > 0 && stepIndex < steps.length - 1) {
      stepIndex++;
      steps[stepIndex].classList.add('step-visible');
    } else {
      navigatePage(1);
    }
  }

  function backward() {
    if (steps.length > 0 && stepIndex > 0) {
      steps[stepIndex].classList.remove('step-visible');
      stepIndex--;
    } else {
      navigatePage(-1);
    }
  }

  function goToIndex() {
    // 支持从 pages/ 子目录或同级目录返回 index.html
    var path = location.pathname;
    if (path.indexOf('/pages/') !== -1) {
      location.href = '../index.html';
    } else {
      location.href = 'index.html';
    }
  }

  document.addEventListener('keydown', function(e) {
    switch(e.key) {
      case 'ArrowRight':
      case 'ArrowDown':
        e.preventDefault();
        forward();
        break;
      case 'ArrowLeft':
      case 'ArrowUp':
        e.preventDefault();
        backward();
        break;
      case 'Escape':
        e.preventDefault();
        goToIndex();
        break;
    }
  });

  currentIndex = findCurrentIndex();

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initSteps);
  } else {
    initSteps();
  }
})();
