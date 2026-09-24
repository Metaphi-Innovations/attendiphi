/**
 * Web SFace embeddings via ONNX Runtime Web (WASM).
 * Detect (TinyFaceDetector) → 68-pt landmarks → 5-point similarity align
 * into 112×112 (letterbox fallback) → BGR planar tensor → L2-normalized 128-d.
 */
(function () {
  let session = null;
  let initPromise = null;
  let detectorReady = false;
  let landmarksReady = false;
  let detectorPromise = null;

  const MSG_NO_FACE =
    'No face detected. Please position your face in front of the camera.';
  const MSG_MULTIPLE_FACES =
    'Please ensure only one person is in front of the camera.';
  const MSG_PREPARING = 'Preparing face recognition...';
  const MSG_CLOSER = 'Please move closer to the camera so your face fills the frame.';
  const MSG_DARK = 'Lighting is too dark. Please move to a brighter area.';
  const MSG_BRIGHT = 'Lighting is too bright. Please avoid strong backlight.';
  const MSG_BLUR = 'Image is blurry. Please hold steady and try again.';
  const MSG_LOOK = 'Look directly at the camera.';

  // InsightFace / OpenCV SFace 112×112 five-point template.
  const SFACE_REF = [
    [38.2946, 51.6963],
    [73.5318, 51.5014],
    [56.0252, 71.7366],
    [41.5493, 92.3655],
    [70.7299, 92.2041],
  ];

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
        session = await ort.InferenceSession.create(
          'models/face_recognition_sface_2021dec.onnx',
          { executionProviders: ['wasm'], graphOptimizationLevel: 'all' }
        );
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

  async function ensureDetector() {
    if (detectorReady) return true;
    if (detectorPromise) return detectorPromise;

    detectorPromise = (async () => {
      try {
        if (typeof faceapi === 'undefined' || !faceapi.nets || !faceapi.nets.tinyFaceDetector) {
          console.warn('[FaceVerifier] face-api.js tinyFaceDetector is not available.');
          return false;
        }
        await faceapi.nets.tinyFaceDetector.loadFromUri('face-api/weights');
        detectorReady = true;
        try {
          if (faceapi.nets.faceLandmark68TinyNet) {
            await faceapi.nets.faceLandmark68TinyNet.loadFromUri('face-api/weights');
            landmarksReady = true;
          }
        } catch (lmErr) {
          console.warn('[FaceVerifier] Landmark net unavailable, using letterbox crop.', lmErr);
          landmarksReady = false;
        }
        return true;
      } catch (err) {
        console.error('[FaceVerifier] Error loading face detector:', err);
        return false;
      }
    })();

    return detectorPromise;
  }

  function detectorOptions() {
    return new faceapi.TinyFaceDetectorOptions({
      inputSize: 320,
      scoreThreshold: 0.35,
    });
  }

  async function detectFacesOnImage(img) {
    const ready = await ensureDetector();
    if (!ready) {
      return { ok: false, faces: [], error: MSG_PREPARING };
    }
    try {
      if (landmarksReady) {
        const detections = await faceapi
          .detectAllFaces(img, detectorOptions())
          .withFaceLandmarks(true);
        return { ok: true, faces: detections || [], error: null };
      }
      const detections = await faceapi.detectAllFaces(img, detectorOptions());
      return { ok: true, faces: detections || [], error: null };
    } catch (err) {
      console.warn('[FaceVerifier] detect failed', err);
      return { ok: false, faces: [], error: MSG_PREPARING };
    }
  }

  function getBox(face) {
    if (face && face.detection && face.detection.box) return face.detection.box;
    return face && face.box ? face.box : null;
  }

  function fivePointsFrom68(landmarks) {
    if (!landmarks || !landmarks.positions || landmarks.positions.length < 68) {
      return null;
    }
    const p = landmarks.positions;
    const avg = function (idxs) {
      let x = 0;
      let y = 0;
      for (let i = 0; i < idxs.length; i++) {
        x += p[idxs[i]].x;
        y += p[idxs[i]].y;
      }
      return { x: x / idxs.length, y: y / idxs.length };
    };
    return [
      avg([36, 37, 38, 39, 40, 41]),
      avg([42, 43, 44, 45, 46, 47]),
      { x: p[30].x, y: p[30].y },
      { x: p[48].x, y: p[48].y },
      { x: p[54].x, y: p[54].y },
    ];
  }

  function similarityFromPoints(src, dst) {
    const n = src.length;
    let sMeanX = 0;
    let sMeanY = 0;
    let dMeanX = 0;
    let dMeanY = 0;
    for (let i = 0; i < n; i++) {
      sMeanX += src[i].x;
      sMeanY += src[i].y;
      dMeanX += dst[i][0];
      dMeanY += dst[i][1];
    }
    sMeanX /= n;
    sMeanY /= n;
    dMeanX /= n;
    dMeanY /= n;
    let den = 0;
    let numA = 0;
    let numB = 0;
    for (let i = 0; i < n; i++) {
      const sx = src[i].x - sMeanX;
      const sy = src[i].y - sMeanY;
      const dx = dst[i][0] - dMeanX;
      const dy = dst[i][1] - dMeanY;
      den += sx * sx + sy * sy;
      numA += sx * dx + sy * dy;
      numB += sx * dy - sy * dx;
    }
    if (den < 1e-6) return null;
    const a = numA / den;
    const b = numB / den;
    return {
      a: a,
      b: b,
      tx: dMeanX - a * sMeanX + b * sMeanY,
      ty: dMeanY - b * sMeanX - a * sMeanY,
    };
  }

  function letterboxSourceRect(box, imgW, imgH, padRatio) {
    const pad = Math.max(box.width, box.height) * padRatio;
    let x = box.x - pad;
    let y = box.y - pad;
    let w = box.width + pad * 2;
    let h = box.height + pad * 2;
    if (x < 0) {
      w += x;
      x = 0;
    }
    if (y < 0) {
      h += y;
      y = 0;
    }
    if (x + w > imgW) w = imgW - x;
    if (y + h > imgH) h = imgH - y;
    return {
      x: Math.max(0, x),
      y: Math.max(0, y),
      w: Math.max(1, w),
      h: Math.max(1, h),
    };
  }

  function letterboxDest(srcW, srcH, dstSize) {
    const scale = dstSize / Math.max(srcW, srcH);
    const dw = srcW * scale;
    const dh = srcH * scale;
    return {
      dx: (dstSize - dw) / 2,
      dy: (dstSize - dh) / 2,
      dw: dw,
      dh: dh,
    };
  }

  function drawAligned112(img, face) {
    const canvas = document.createElement('canvas');
    canvas.width = 112;
    canvas.height = 112;
    const ctx = canvas.getContext('2d', { willReadFrequently: true });
    ctx.fillStyle = '#7f7f7f';
    ctx.fillRect(0, 0, 112, 112);

    const pts = face.landmarks ? fivePointsFrom68(face.landmarks) : null;
    const xf = pts ? similarityFromPoints(pts, SFACE_REF) : null;
    if (xf) {
      ctx.setTransform(xf.a, xf.b, -xf.b, xf.a, xf.tx, xf.ty);
      ctx.drawImage(img, 0, 0);
      ctx.setTransform(1, 0, 0, 1, 0, 0);
      return canvas;
    }

    const box = getBox(face);
    const origW = img.naturalWidth || img.width;
    const origH = img.naturalHeight || img.height;
    const src = letterboxSourceRect(box, origW, origH, 0.25);
    const dest = letterboxDest(src.w, src.h, 112);
    ctx.drawImage(img, src.x, src.y, src.w, src.h, dest.dx, dest.dy, dest.dw, dest.dh);
    return canvas;
  }

  function poseFromPoints(pts) {
    if (!pts) return { yaw: 0, roll: 0, label: 'unknown' };
    const le = pts[0];
    const re = pts[1];
    const nose = pts[2];
    const eyeDist = Math.hypot(re.x - le.x, re.y - le.y) || 1;
    const yaw = (nose.x - (le.x + re.x) / 2) / eyeDist;
    const roll = Math.atan2(re.y - le.y, re.x - le.x);
    let label = 'frontal';
    if (yaw > 0.18) label = 'left';
    else if (yaw < -0.18) label = 'right';
    return { yaw: yaw, roll: roll, label: label };
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
    const lumaVariance = lumaSqSum / totalPixels - avgBrightness * avgBrightness;
    const contrast = Math.sqrt(Math.max(0, lumaVariance));

    const step = Math.max(1, Math.floor(Math.min(w, h) / 64));
    for (let y = 2; y < h - 2; y += step) {
      for (let x = 2; x < w - 2; x += step) {
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
    const sharpness = lapCount > 0 ? lapSqSum / lapCount - lapMean * lapMean : 0;
    return { brightness: avgBrightness, contrast: contrast, sharpness: sharpness };
  }

  function qualityFromBox(img, box) {
    const origW = img.naturalWidth || img.width;
    const origH = img.naturalHeight || img.height;
    const x = Math.max(0, Math.floor(box.x));
    const y = Math.max(0, Math.floor(box.y));
    const w = Math.max(8, Math.min(origW - x, Math.floor(box.width)));
    const h = Math.max(8, Math.min(origH - y, Math.floor(box.height)));
    const canvas = document.createElement('canvas');
    canvas.width = w;
    canvas.height = h;
    const ctx = canvas.getContext('2d', { willReadFrequently: true });
    ctx.drawImage(img, x, y, w, h, 0, 0, w, h);
    const data = ctx.getImageData(0, 0, w, h).data;
    const q = calculateQualityMetrics(data, w, h);
    q.faceSizeRatio = Math.min(box.width, box.height) / Math.max(origW, origH);
    return q;
  }

  function guidanceFromAssess(faceCount, quality, pose, options) {
    if (faceCount === 0) return MSG_NO_FACE;
    if (faceCount > 1) return MSG_MULTIPLE_FACES;
    const minFace = (options && options.minFaceSizeRatio) || 0.12;
    const minBright = (options && options.minBrightness) || 40;
    const maxBright = (options && options.maxBrightness) || 230;
    const minSharp = (options && options.minSharpness) || 18;
    if (quality.faceSizeRatio > 0 && quality.faceSizeRatio < minFace) return MSG_CLOSER;
    if (quality.brightness > 0 && quality.brightness < minBright) return MSG_DARK;
    if (quality.brightness > maxBright) return MSG_BRIGHT;
    if (quality.sharpness > 0 && quality.sharpness < minSharp) return MSG_BLUR;
    if (options && options.requireFrontal && pose && Math.abs(pose.yaw) > 0.42) {
      return MSG_LOOK;
    }
    return null;
  }

  if (typeof window !== 'undefined') {
    window.addEventListener('load', function () {
      setTimeout(function () {
        ensureDetector();
        getSession();
      }, 400);
    });
  }

  async function processImageToEmbedding(sess, img, doQualityCheck, options) {
    const origW = img.naturalWidth || img.width;
    const origH = img.naturalHeight || img.height;
    const minImageSide = (options && options.minImageSide) || 160;
    const forEnrollment = !!(options && options.forEnrollment);

    if (origW < 60 || origH < 60) {
      return { valid: false, error: 'Image resolution too low', embedding: null, faceCount: 0 };
    }
    if (doQualityCheck && Math.min(origW, origH) < minImageSide) {
      return {
        valid: false,
        error: MSG_CLOSER,
        embedding: null,
        faceCount: 0,
        quality: { brightness: 0, contrast: 0, sharpness: 0, faceSizeRatio: 0 },
      };
    }

    const detection = await detectFacesOnImage(img);
    if (!detection.ok) {
      return { valid: false, error: detection.error || MSG_PREPARING, embedding: null, faceCount: 0 };
    }

    const faceCount = detection.faces.length;
    if (faceCount === 0) {
      return { valid: false, error: MSG_NO_FACE, embedding: null, faceCount: 0 };
    }
    if (faceCount > 1) {
      return { valid: false, error: MSG_MULTIPLE_FACES, embedding: null, faceCount: faceCount };
    }

    const face = detection.faces[0];
    const box = getBox(face);
    const quality = qualityFromBox(img, box);
    const pts = face.landmarks ? fivePointsFrom68(face.landmarks) : null;
    const pose = poseFromPoints(pts);

    if (doQualityCheck) {
      const hard = guidanceFromAssess(faceCount, quality, pose, options);
      if (hard && hard !== MSG_LOOK) {
        return { valid: false, error: hard, embedding: null, quality: quality, faceCount: 1, pose: pose };
      }
      if (forEnrollment && hard === MSG_LOOK && Math.abs(pose.yaw) > 0.55) {
        return { valid: false, error: MSG_LOOK, embedding: null, quality: quality, faceCount: 1, pose: pose };
      }
    }

    const aligned = drawAligned112(img, face);
    const imgData = aligned.getContext('2d').getImageData(0, 0, 112, 112).data;

    const tensorData = new Float32Array(1 * 3 * 112 * 112);
    const planeSize = 112 * 112;
    for (let i = 0; i < planeSize; i++) {
      const r = imgData[i * 4];
      const g = imgData[i * 4 + 1];
      const b = imgData[i * 4 + 2];
      tensorData[i] = b;
      tensorData[planeSize + i] = g;
      tensorData[planeSize * 2 + i] = r;
    }

    const inputTensor = new ort.Tensor('float32', tensorData, [1, 3, 112, 112]);
    const results = await sess.run({ data: inputTensor });
    const rawVector = results.fc1.data;

    let sumSq = 0.0;
    for (let i = 0; i < rawVector.length; i++) {
      sumSq += rawVector[i] * rawVector[i];
    }
    const norm = Math.sqrt(sumSq);
    if (norm < 1e-9) {
      return { valid: false, error: 'Zero embedding norm', embedding: null, quality: quality, faceCount: 1 };
    }

    const normalized = new Array(rawVector.length);
    for (let i = 0; i < rawVector.length; i++) {
      normalized[i] = rawVector[i] / norm;
    }

    const warn = doQualityCheck ? guidanceFromAssess(faceCount, quality, pose, options) : null;
    return {
      valid: true,
      error: warn === MSG_LOOK ? warn : null,
      embedding: normalized,
      quality: quality,
      faceCount: 1,
      pose: pose,
      landmarks: { x: box.x, y: box.y, width: box.width, height: box.height },
    };
  }

  function loadImageFromBase64(base64Photo) {
    const img = new Image();
    const loadPromise = new Promise(function (resolve, reject) {
      img.onload = function () { resolve(img); };
      img.onerror = function (e) { reject(e); };
    });
    if (!base64Photo.startsWith('data:')) {
      img.src = 'data:image/jpeg;base64,' + base64Photo;
    } else {
      img.src = base64Photo;
    }
    return loadPromise;
  }

  window.initializeFaceRecognition = async function () {
    const detectorOk = await ensureDetector();
    const sess = await getSession();
    return !!(detectorOk && sess);
  };

  window.assessLiveFaceFrame = async function (base64Photo, options) {
    try {
      const img = await loadImageFromBase64(base64Photo);
      const detection = await detectFacesOnImage(img);
      if (!detection.ok) {
        return { ok: false, faceCount: 0, guidance: detection.error || MSG_PREPARING };
      }
      const faceCount = detection.faces.length;
      if (faceCount === 0) {
        return { ok: false, faceCount: 0, guidance: MSG_NO_FACE };
      }
      if (faceCount > 1) {
        return { ok: false, faceCount: faceCount, guidance: MSG_MULTIPLE_FACES };
      }
      const face = detection.faces[0];
      const box = getBox(face);
      const quality = qualityFromBox(img, box);
      const pts = face.landmarks ? fivePointsFrom68(face.landmarks) : null;
      const pose = poseFromPoints(pts);
      const guidance = guidanceFromAssess(faceCount, quality, pose, options || {});
      return {
        ok: !guidance,
        faceCount: 1,
        faceSizeRatio: quality.faceSizeRatio,
        brightness: quality.brightness,
        sharpness: quality.sharpness,
        yaw: pose.yaw,
        poseLabel: pose.label,
        guidance: guidance || 'Hold still',
      };
    } catch (e) {
      return { ok: false, faceCount: 0, guidance: String(e) };
    }
  };

  window.validateAndExtractFaceFrame = async function (base64Photo, options) {
    try {
      const sess = await getSession();
      if (!sess) {
        return { valid: false, error: 'SFace engine not initialized', embedding: null };
      }
      const img = await loadImageFromBase64(base64Photo);
      return await processImageToEmbedding(sess, img, true, options || {});
    } catch (e) {
      console.error('[FaceVerifier] Frame processing error:', e);
      return { valid: false, error: String(e), embedding: null };
    }
  };

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
