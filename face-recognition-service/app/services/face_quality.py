import base64
import math
from typing import Optional, Tuple
import cv2
import numpy as np

from app.config import settings

def decode_base64_image(photo_base64: str) -> Optional[np.ndarray]:
    """Decodes a base64 encoded photo (with or without data URI prefix) into a BGR image."""
    try:
        raw_str = photo_base64.strip()
        if "," in raw_str:
            raw_str = raw_str.split(",", 1)[1]
        img_bytes = base64.b64decode(raw_str)
        nparr = np.frombuffer(img_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        return img
    except Exception:
        return None

def compute_sharpness(gray: np.ndarray) -> float:
    """Computes sharpness using the variance of the Laplacian.
    Higher values indicate sharp, in-focus images; lower values indicate blur."""
    return float(cv2.Laplacian(gray, cv2.CV_64F).var())

def compute_brightness(gray: np.ndarray) -> float:
    """Computes the mean pixel intensity (0 to 255)."""
    return float(np.mean(gray))

def estimate_eye_roll_angle(left_eye: Tuple[float, float], right_eye: Tuple[float, float]) -> float:
    """Calculates head roll angle (ear-to-shoulder tilt) in degrees based on 2D eye positions."""
    dx = right_eye[0] - left_eye[0]
    dy = right_eye[1] - left_eye[1]
    if abs(dx) < 1e-6:
        return 0.0
    return float(math.degrees(math.atan2(dy, dx)))

def estimate_yaw_symmetry(left_eye: Tuple[float, float], right_eye: Tuple[float, float], nose: Tuple[float, float]) -> float:
    """Estimates head yaw (left/right turn) by calculating the asymmetry ratio
    between left-eye-to-nose and right-eye-to-nose distances.
    0 degrees means perfectly symmetrical front-facing."""
    d_left = math.hypot(nose[0] - left_eye[0], nose[1] - left_eye[1])
    d_right = math.hypot(right_eye[0] - nose[0], right_eye[1] - nose[1])
    total = d_left + d_right
    if total < 1e-5:
        return 0.0
    ratio = (d_left - d_right) / total
    # Approximate yaw angle: ratio of ~0.35 corresponds to ~25-30 degrees
    return float(ratio * 75.0)

class FaceQualityService:
    def __init__(self):
        self.min_sharpness = settings.MIN_SHARPNESS_SCORE
        self.min_brightness = settings.MIN_BRIGHTNESS
        self.max_brightness = settings.MAX_BRIGHTNESS
        self.min_face_size = settings.MIN_FACE_SIZE_PX
        self.max_yaw = settings.MAX_HEAD_YAW_DEG
        self.max_roll = settings.MAX_HEAD_ROLL_DEG
        self.enroll_min_sharpness = settings.ENROLL_MIN_SHARPNESS_SCORE
        self.enroll_min_face_size = settings.ENROLL_MIN_FACE_SIZE_PX
        self.enroll_max_yaw = settings.ENROLL_MAX_HEAD_YAW_DEG
        self.enroll_max_roll = settings.ENROLL_MAX_HEAD_ROLL_DEG

    def validate_quality(
        self,
        image: np.ndarray,
        bbox: Tuple[int, int, int, int],  # x, y, w, h
        landmarks: Optional[np.ndarray] = None,  # 5 landmarks: [left_eye, right_eye, nose, left_mouth, right_mouth]
        for_enroll: bool = False,
    ) -> Tuple[bool, Optional[str], dict]:
        """
        Validates whether a detected face image satisfies quality standards:
        - Sufficient face size
        - Not blurry
        - Proper illumination (neither dark nor overexposed)
        - Front-facing angle
        """
        min_sharpness = self.enroll_min_sharpness if for_enroll else self.min_sharpness
        min_face_size = self.enroll_min_face_size if for_enroll else self.min_face_size
        max_yaw = self.enroll_max_yaw if for_enroll else self.max_yaw
        max_roll = self.enroll_max_roll if for_enroll else self.max_roll

        x, y, w, h = bbox
        img_h, img_w = image.shape[:2]

        # 1. Face size check
        if w < min_face_size or h < min_face_size:
            return False, "Face is too far away. Please move closer to the camera.", {
                "size": min(w, h), "min_required": min_face_size
            }

        # Crop face region with 10% safety margin for localized checks
        margin_x = int(w * 0.1)
        margin_y = int(h * 0.1)
        x1 = max(0, x - margin_x)
        y1 = max(0, y - margin_y)
        x2 = min(img_w, x + w + margin_x)
        y2 = min(img_h, y + h + margin_y)
        face_crop = image[y1:y2, x1:x2]

        if face_crop.size == 0:
            return False, "Invalid face crop.", {}

        gray_face = cv2.cvtColor(face_crop, cv2.COLOR_BGR2GRAY)

        # 2. Sharpness check
        sharpness = compute_sharpness(gray_face)
        if sharpness < min_sharpness:
            return False, "Image is blurry. Please hold steady and try again.", {
                "sharpness": round(sharpness, 1), "min_required": min_sharpness
            }

        # 3. Brightness check
        brightness = compute_brightness(gray_face)
        if brightness < self.min_brightness:
            return False, "Lighting is too dark. Please move to a brighter area.", {
                "brightness": round(brightness, 1), "min_required": self.min_brightness
            }
        if brightness > self.max_brightness:
            return False, "Lighting is too bright or washed out. Please avoid strong backlight.", {
                "brightness": round(brightness, 1), "max_allowed": self.max_brightness
            }

        # 4. Pose angles check
        yaw = 0.0
        roll = 0.0
        if landmarks is not None and len(landmarks) >= 3:
            left_eye = (float(landmarks[0][0]), float(landmarks[0][1]))
            right_eye = (float(landmarks[1][0]), float(landmarks[1][1]))
            nose = (float(landmarks[2][0]), float(landmarks[2][1]))

            roll = estimate_eye_roll_angle(left_eye, right_eye)
            yaw = estimate_yaw_symmetry(left_eye, right_eye, nose)

            if abs(roll) > max_roll:
                return False, "Please hold your head straight.", {
                    "roll": round(roll, 1), "max_allowed": max_roll
                }

            if abs(yaw) > max_yaw:
                return False, "Please look directly at the camera.", {
                    "yaw": round(yaw, 1), "max_allowed": max_yaw
                }

        metrics = {
            "sharpness": round(sharpness, 1),
            "brightness": round(brightness, 1),
            "yaw": round(yaw, 1),
            "roll": round(roll, 1),
            "width": w,
            "height": h,
        }
        return True, None, metrics

face_quality_service = FaceQualityService()
