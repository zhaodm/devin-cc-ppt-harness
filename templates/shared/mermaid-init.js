(function() {
  if (window.__mermaidInit) return;
  window.__mermaidInit = true;

  function initMermaid() {
    var blocks = document.querySelectorAll('.mermaid');
    if (blocks.length === 0) return;

    if (typeof mermaid !== 'undefined') {
      mermaid.initialize({
        startOnLoad: false,
        theme: 'base',
        themeVariables: {
          primaryColor: '#F5F0E8',
          primaryTextColor: '#2C2418',
          primaryBorderColor: '#E07A5F',
          lineColor: '#5C4E3C',
          secondaryColor: '#FFF',
          tertiaryColor: '#F4A68C',
          fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", "PingFang SC", sans-serif'
        }
      });
      mermaid.run({ nodes: blocks });
    } else {
      var script = document.createElement('script');
      script.src = 'https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js';
      script.onload = function() {
        mermaid.initialize({
          startOnLoad: false,
          theme: 'base',
          themeVariables: {
            primaryColor: '#F5F0E8',
            primaryTextColor: '#2C2418',
            primaryBorderColor: '#E07A5F',
            lineColor: '#5C4E3C',
            secondaryColor: '#FFF',
            tertiaryColor: '#F4A68C',
            fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", "PingFang SC", sans-serif'
          }
        });
        mermaid.run({ nodes: blocks });
      };
      document.head.appendChild(script);
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initMermaid);
  } else {
    initMermaid();
  }
})();
