import math
from typing import Tuple, Optional
import cv2
import numpy as np

from app.config import settings

class LivenessService:
    """
    Passive anti-spoofing analyzer to distinguish genuine live faces from:
    1. Phone / tablet / monitor displays (moiré artifacts, screen pixel grid, RGB channel banding).
    2. Printed paper photos (flat specular reflection, color loss, halftone pattern).
    """

    def __init__(self):
        self.enabled = settings.LIVENESS_ENABLED
        self.min_liveness_score = settings.MIN_LIVENESS_SCORE

    def evaluate_liveness(
        self,
        image: np.ndarray,
        bbox: Tuple[int, int, int, int]
    ) -> Tuple[bool, float, Optional[str]]:
        if not self.enabled:
            return True, 1.0, None

        x, y, w, h = bbox
        img_h, img_w = image.shape[:2]

        x1 = max(0, x)
        y1 = max(0, y)
        x2 = min(img_w, x + w)
        y2 = min(img_h, y + h)

        face_crop = image[y1:y2, x1:x2]
        if face_crop.size == 0 or face_crop.shape[0] < 40 or face_crop.shape[1] < 40:
            return False, 0.0, "Face region too small for liveness analysis."

        scores = []

        # 1. High-Frequency Fourier Analysis (Detects screen moiré & printed halftone)
        gray = cv2.cvtColor(face_crop, cv2.COLOR_BGR2GRAY)
        resized_gray = cv2.resize(gray, (128, 128))
        f = np.fft.fft2(resized_gray)
        fshift = np.fft.fftshift(f)
        magnitude_spectrum = 20 * np.log(np.abs(fshift) + 1e-9)

        # Center low frequencies vs outer high frequencies ratio
        rows, cols = 128, 128
        crow, ccol = rows // 2, cols // 2
        # Mask out center (low freq)
        mask = np.ones((rows, cols), np.uint8)
        r = 20
        mask[crow - r : crow + r, ccol - r : ccol + r] = 0
        high_freq_energy = np.mean(magnitude_spectrum[mask == 1])
        total_energy = np.mean(magnitude_spectrum)
        
        freq_ratio = high_freq_energy / (total_energy + 1e-6)
        # Genuine faces have balanced frequency decay (typically 0.40 - 0.85)
        # Screens often have extreme peaks or low cutoffs
        freq_score = float(np.clip((freq_ratio - 0.25) / 0.45, 0.0, 1.0))
        scores.append(freq_score)

        # 2. Specular reflection / screen glare check
        # Screens and glossy prints have concentrated clusters of pure white/clipped pixels
        hsv = cv2.cvtColor(face_crop, cv2.COLOR_BGR2HSV)
        v_channel = hsv[:, :, 2]
        s_channel = hsv[:, :, 1]
        glare_mask = (v_channel > 248) & (s_channel < 30)
        glare_ratio = np.sum(glare_mask) / (v_channel.size + 1e-6)
        
        # If glare occupies > 3% of face, likely phone screen reflection
        glare_score = float(np.clip(1.0 - (glare_ratio / 0.035), 0.0, 1.0))
        scores.append(glare_score)

        # 3. Color channel standard deviation / natural dispersion
        b, g, r_ch = cv2.split(face_crop)
        std_r = np.std(r_ch)
        std_g = np.std(g)
        std_b = np.std(b)
        
        # Real human skin exhibits specific R > G > B absorption
        mean_r = np.mean(r_ch)
        mean_b = np.mean(b)
        # Real skin under standard lighting has mean_r noticeably above mean_b
        color_balance = (mean_r - mean_b) / (mean_r + mean_b + 1e-6)
        color_score = float(np.clip((color_balance + 0.05) / 0.25, 0.3, 1.0))
        scores.append(color_score)

        # Composite liveness confidence
        composite_score = float(np.mean(scores))

        if composite_score < self.min_liveness_score:
            return False, composite_score, "Anti-spoofing check failed. Please ensure a live physical face without screen reflection."

        return True, composite_score, None

liveness_service = LivenessService()
