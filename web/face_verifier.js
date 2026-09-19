/**
 * Web Neural Face Embedding Extractor using ONNX Runtime Web (WASM).
 * Runs SFace directly in browser (iOS Safari, Android Chrome, Desktop)
 * to produce 128-dimensional L2-normalized biometric embeddings.
 */
(function () {
  let session = null;
  let initPromise = null;

  function initOrt() {
    if (typeof ort !== 'undefined' && ort.env && ort.env.wasm) {
      ort.env.wasm.numThreads = 1;
      ort.env.wasm.simd = true;
      ort.env.wasm.wasmPaths = './';
    }
  }

  async function getSession() {
    if (session) return session;
    if (initPromise) return initPromise;

    initPromise = (async () => {
      try {
        if (typeof ort === 'undefined') {
          console.warn('[FaceVerifier] ONNX Runtime Web (ort) not loaded.');
          return null;
        }

        initOrt();

        const modelPath = 'models/face_recognition_sface_2021dec.onnx';
        console.log('[FaceVerifier] Loading neural face recognition model:', modelPath);
        session = await ort.InferenceSession.create(modelPath, {
          executionProviders: ['wasm'],
          graphOptimizationLevel: 'all',
        });
        console.log('[FaceVerifier] Neural face model loaded successfully.');
        return session;
      } catch (err) {
        console.error('[FaceVerifier] Error loading face model:', err);
        return null;
      } finally {
        initPromise = null;
      }
    })();

    return initPromise;
  }

  // Preload session early
  if (typeof window !== 'undefined') {
    window.addEventListener('load', () => {
      setTimeout(() => getSession(), 1200);
    });
  }

  /**
   * Extracts a 128-d L2-normalized neural face embedding from a base64 photo.
   * @param {string} base64Photo JPEG/PNG image encoded in base64.
   * @returns {Promise<number[] | null>} 128-d normalized embedding or null.
   */
  window.extractNeuralFaceEmbedding = async function (base64Photo) {
    try {
      const sess = await getSession();
      if (!sess) {
        console.warn('[FaceVerifier] SFace session not available');
        return null;
      }

      // 1. Decode base64 to Image
      const img = new Image();
      const loadPromise = new Promise((resolve, reject) => {
        img.onload = () => resolve();
        img.onerror = (e) => reject(e);
      });

      if (!base64Photo.startsWith('data:')) {
        img.src = 'data:image/jpeg;base64,' + base64Photo;
      } else {
        img.src = base64Photo;
      }
      await loadPromise;

      const origW = img.naturalWidth || img.width;
      const origH = img.naturalHeight || img.height;
      if (origW < 20 || origH < 20) return null;

      // 2. Crop Face Region
      // Focus on the central portrait selfie frame
      const cropSize = Math.min(origW, origH) * 0.72;
      const cropX = Math.max(0, (origW - cropSize) / 2);
      const cropY = Math.max(0, (origH - cropSize) / 2.3);

      const canvas = document.createElement('canvas');
      canvas.width = 112;
      canvas.height = 112;
      const ctx = canvas.getContext('2d', { willReadFrequently: true });
      ctx.drawImage(img, cropX, cropY, cropSize, cropSize, 0, 0, 112, 112);

      const imgData = ctx.getImageData(0, 0, 112, 112).data;

      // 3. Prepare SFace Tensor: Shape [1, 3, 112, 112], Channel order: BGR, Values: [0..255] float32
      const tensorData = new Float32Array(1 * 3 * 112 * 112);
      const planeSize = 112 * 112;

      for (let i = 0; i < planeSize; i++) {
        const r = imgData[i * 4];
        const g = imgData[i * 4 + 1];
        const b = imgData[i * 4 + 2];

        // Channel 0: Blue (OpenCV BGR standard)
        tensorData[i] = b;
        // Channel 1: Green
        tensorData[planeSize + i] = g;
        // Channel 2: Red
        tensorData[planeSize * 2 + i] = r;
      }

      const inputTensor = new ort.Tensor('float32', tensorData, [1, 3, 112, 112]);
      const results = await sess.run({ data: inputTensor });
      const rawVector = results.fc1.data;

      // 4. L2 Normalize
      let sumSq = 0.0;
      for (let i = 0; i < rawVector.length; i++) {
        sumSq += rawVector[i] * rawVector[i];
      }
      const norm = Math.sqrt(sumSq);
      if (norm < 1e-9) return null;

      const normalized = new Array(rawVector.length);
      for (let i = 0; i < rawVector.length; i++) {
        normalized[i] = rawVector[i] / norm;
      }

      return normalized;
    } catch (e) {
      console.error('[FaceVerifier] Failed to extract embedding:', e);
      return null;
    }
  };
})();
