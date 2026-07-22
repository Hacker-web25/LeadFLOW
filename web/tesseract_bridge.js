// Small JS bridge used by the Dart app.
// - leadflowFetchBytes(url): fetch a blob:/data: URL, return Uint8Array.
// - leadflowExtractText(url): OCR fallback via tesseract.js.
(function () {
  window.leadflowFetchBytes = async function (url) {
    try {
      const resp = await fetch(url);
      const buf = await resp.arrayBuffer();
      return new Uint8Array(buf);
    } catch (e) {
      console.error('leadflowFetchBytes failed', e);
      return null;
    }
  };

  let tesseractPromise = null;
  function loadTesseract() {
    if (window.Tesseract) return Promise.resolve(window.Tesseract);
    if (tesseractPromise) return tesseractPromise;
    tesseractPromise = new Promise((resolve, reject) => {
      const s = document.createElement('script');
      s.src = 'https://cdn.jsdelivr.net/npm/tesseract.js@5.1.1/dist/tesseract.min.js';
      s.async = true;
      s.onload = () => resolve(window.Tesseract);
      s.onerror = () => reject(new Error('Failed to load tesseract.js'));
      document.head.appendChild(s);
    });
    return tesseractPromise;
  }

  window.leadflowExtractText = async function (imageUrl) {
    try {
      const T = await loadTesseract();
      const { data } = await T.recognize(imageUrl, 'eng');
      return data && data.text ? data.text : '';
    } catch (e) {
      console.error('leadflowExtractText failed', e);
      return '';
    }
  };
})();
