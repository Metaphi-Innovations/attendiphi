from dataclasses import dataclass
from pathlib import Path
from typing import List, Optional, Tuple
import cv2
import numpy as np

from app.config import settings

@dataclass
class DetectedFace:
    bbox: Tuple[int, int, int, int]  # x, y, w, h
    landmarks: np.ndarray             # shape (5, 2)
    score: float
    raw_face_array: np.ndarray       # 15-element array from YuNet

class FaceDetectionService:
    def __init__(self, model_path: Optional[str] = None):
        if model_path is None:
            model_path = str(
                Path(__file__).resolve().parent.parent / "models" / "face_detection_yunet_2023mar.onnx"
            )
        self.model_path = model_path
        self._detector: Optional[cv2.FaceDetectorYN] = None
        self._current_size = (320, 320)
        self._load_model()

    def _load_model(self):
        if not Path(self.model_path).exists():
            raise FileNotFoundError(f"YuNet face detection model not found at {self.model_path}")
        self._detector = cv2.FaceDetectorYN.create(
            self.model_path,
            "",
            self._current_size,
            score_threshold=0.6,
            nms_threshold=0.3,
            top_k=5000
        )

    def detect_faces(self, image: np.ndarray) -> List[DetectedFace]:
        """
        Detects all faces in the provided BGR image.
        Returns a list of DetectedFace objects containing bbox and 5 landmarks.
        """
        if self._detector is None:
            self._load_model()

        h, w = image.shape[:2]
        if self._current_size != (w, h):
            self._detector.setInputSize((w, h))
            self._current_size = (w, h)

        status, faces = self._detector.detect(image)
        if status != 1 or faces is None or len(faces) == 0:
            return []

        results = []
        for face in faces:
            x, y, fw, fh = int(face[0]), int(face[1]), int(face[2]), int(face[3])
            # 5 landmarks: right_eye, left_eye, nose, right_mouth, left_mouth
            landmarks = np.array([
                [face[4], face[5]],
                [face[6], face[7]],
                [face[8], face[9]],
                [face[10], face[11]],
                [face[12], face[13]],
            ], dtype=np.float32)
            score = float(face[14])

            results.append(DetectedFace(
                bbox=(x, y, fw, fh),
                landmarks=landmarks,
                score=score,
                raw_face_array=face
            ))

        return results

face_detection_service = FaceDetectionService()
