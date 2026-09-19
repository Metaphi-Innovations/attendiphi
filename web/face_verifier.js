/**
 * Web Neural Face Embedding Extractor using ONNX Runtime Web (WASM).
 * Runs SFace directly in browser (iOS Safari, Android Chrome, Desktop)
 * to produce 128-dimensional L2-normalized biometric embeddings.
 *
 * Preprocessing specification:
 * - Target resolution: 112x112 portrait face crop
 * - Color space: BGR (OpenCV standard)
 * - Channel layout: Planar [1, 3, 112, 112] (B first, then G, then R)
 * - Value scaling: Float32 in range [0..255]
 * - Model: OpenCV SFace (face_recognition_sface_2021dec.onnx)
 * - Output: 128-dimensional hyperspherical vector L2-normalized to unit sphere
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
        console.log('[FaceVerifier] Loading neural SFace model:', modelPath);
        session = await ort.InferenceSession.create(modelPath, {
          executionProviders: ['wasm'],
          graphOptimizationLevel: 'all',
        });
        console.log('[FaceVerifier] Neural SFace model loaded successfully.');
        return session;
      } catch (err) {
        console.error('[FaceVerifier] Error loading SFace model:', err);
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
      setTimeout(() => getSession(), 1000);
    });
  }

  function calculateQualityMetrics(imgData, w, h) {
    let lumaSum = 0;
    let lumaSqSum = 0;
    let lapSum = 0;
    let lapSqSum = 0;
    let lapCount = 0;

    const totalPixels = w * h;
    const lumaArray = new Float32Array(totalPixels);

    for (let i = 0; i < totalPixels; i++) {
      const idx = i * 4;
      const luma = 0.299 * imgData[idx] + 0.587 * imgData[idx + 1] + 0.114 * imgData[idx + 2];
      lumaArray[i] = luma;
      lumaSum += luma;
      lumaSqSum += luma * luma;
    }

    const avgBrightness = lumaSum / totalPixels;
    const lumaVariance = (lumaSqSum / totalPixels) - (avgBrightness * avgBrightness);
    const contrast = Math.sqrt(Math.max(0, lumaVariance));

    // Laplacian variance for sharpness measurement
    for (let y = 2; y < h - 2; y += 2) {
      for (let x = 2; x < w - 2; x += 2) {
        const c = lumaArray[y * w + x];
        const up = lumaArray[(y - 1) * w + x];
        const down = lumaArray[(y + 1) * w + x];
        const left = lumaArray[y * w + x - 1];
        const right = lumaArray[y * w + x + 1];
        const lap = 4 * c - up - down - left - right;
        lapSum += lap;
        lapSqSum += lap * lap;
        lapCount++;
      }
    }

    const lapMean = lapCount > 0 ? lapSum / lapCount : 0;
    const sharpness = lapCount > 0 ? (lapSqSum / lapCount) - (lapMean * lapMean) : 0;

    return {
      brightness: avgBrightness,
      contrast: contrast,
      sharpness: sharpness,
    };
  }

  /**
   * Internal routine to process an HTML Image into an L2-normalized 128-d SFace embedding.
   */
  async function processImageToEmbedding(sess, img, doQualityCheck) {
    const origW = img.naturalWidth || img.width;
    const origH = img.naturalHeight || img.height;

    if (origW < 60 || origH < 60) {
      return { valid: false, error: 'Image resolution too low', embedding: null };
    }

    // Centered portrait face crop (focus on face oval region)
    const cropSize = Math.min(origW, origH) * 0.72;
    const cropX = Math.max(0, (origW - cropSize) / 2);
    const cropY = Math.max(0, (origH - cropSize) / 2.3);

    const canvas = document.createElement('canvas');
    canvas.width = 112;
    canvas.height = 112;
    const ctx = canvas.getContext('2d', { willReadFrequently: true });
    ctx.drawImage(img, cropX, cropY, cropSize, cropSize, 0, 0, 112, 112);

    const imgData = ctx.getImageData(0, 0, 112, 112).data;

    // Quality check
    const quality = calculateQualityMetrics(imgData, 112, 112);
    if (doQualityCheck) {
      if (quality.brightness < 32) {
        return { valid: false, error: 'Frame too dark. Please increase lighting.', embedding: null, quality };
      }
      if (quality.brightness > 238) {
        return { valid: false, error: 'Frame overexposed. Avoid direct glare behind you.', embedding: null, quality };
      }
      if (quality.sharpness < 15.0) {
        return { valid: false, error: 'Frame blurred. Please hold steady.', embedding: null, quality };
      }
      if (quality.contrast < 15.0) {
        return { valid: false, error: 'Low facial contrast. Reposition face into the frame.', embedding: null, quality };
      }
    }

    // Format BGR Tensor [1, 3, 112, 112]
    const tensorData = new Float32Array(1 * 3 * 112 * 112);
    const planeSize = 112 * 112;

    for (let i = 0; i < planeSize; i++) {
      const r = imgData[i * 4];
      const g = imgData[i * 4 + 1];
      const b = imgData[i * 4 + 2];

      tensorData[i] = b;                 // B
      tensorData[planeSize + i] = g;     // G
      tensorData[planeSize * 2 + i] = r; // R
    }

    const inputTensor = new ort.Tensor('float32', tensorData, [1, 3, 112, 112]);
    const results = await sess.run({ data: inputTensor });
    const rawVector = results.fc1.data;

    // L2 Normalization
    let sumSq = 0.0;
    for (let i = 0; i < rawVector.length; i++) {
      sumSq += rawVector[i] * rawVector[i];
    }
    const norm = Math.sqrt(sumSq);
    if (norm < 1e-9) {
      return { valid: false, error: 'Zero embedding norm', embedding: null, quality };
    }

    const normalized = new Array(rawVector.length);
    for (let i = 0; i < rawVector.length; i++) {
      normalized[i] = rawVector[i] / norm;
    }

    return { valid: true, error: null, embedding: normalized, quality };
  }

  function loadImageFromBase64(base64Photo) {
    const img = new Image();
    const loadPromise = new Promise((resolve, reject) => {
      img.onload = () => resolve(img);
      img.onerror = (e) => reject(e);
    });

    if (!base64Photo.startsWith('data:')) {
      img.src = 'data:image/jpeg;base64,' + base64Photo;
    } else {
      img.src = base64Photo;
    }

    return loadPromise;
  }

  /**
   * Validates face frame quality and extracts SFace embedding.
   * Returns: { valid: bool, error: string?, embedding: number[]?, quality: object? }
   */
  window.validateAndExtractFaceFrame = async function (base64Photo) {
    try {
      const sess = await getSession();
      if (!sess) {
        return { valid: false, error: 'SFace engine not initialized', embedding: null };
      }

      const img = await loadImageFromBase64(base64Photo);
      return await processImageToEmbedding(sess, img, true);
    } catch (e) {
      console.error('[FaceVerifier] Frame processing error:', e);
      return { valid: false, error: String(e), embedding: null };
    }
  };

  /**
   * Simple embedding extractor for backwards compatibility.
   * Returns: number[] | null
   */
  window.extractNeuralFaceEmbedding = async function (base64Photo) {
    try {
      const sess = await getSession();
      if (!sess) return null;

      const img = await loadImageFromBase64(base64Photo);
      const res = await processImageToEmbedding(sess, img, false);
      return res.valid ? res.embedding : null;
    } catch (e) {
      console.error('[FaceVerifier] Failed to extract embedding:', e);
      return null;
    }
  };
})();
