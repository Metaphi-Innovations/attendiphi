from pathlib import Path
from typing import List, Optional
import cv2
import numpy as np

from app.config import settings

class FaceEmbeddingService:
    def __init__(self, model_path: Optional[str] = None):
        if model_path is None:
            model_path = str(
                Path(__file__).resolve().parent.parent / "models" / "face_recognition_sface_2021dec.onnx"
            )
        self.model_path = model_path
        self._recognizer: Optional[cv2.FaceRecognizerSF] = None
        self._load_model()

    def _load_model(self):
        if not Path(self.model_path).exists():
            raise FileNotFoundError(f"Face recognition model not found at {self.model_path}")
        self._recognizer = cv2.FaceRecognizerSF.create(self.model_path, "")

    def align_and_crop_face(self, image: np.ndarray, raw_face: np.ndarray) -> np.ndarray:
        """
        Applies similarity transformation using 5 landmarks to yield an aligned 112x112 face crop.
        """
        if self._recognizer is None:
            self._load_model()
        return self._recognizer.alignCrop(image, raw_face)

    def extract_embedding(self, aligned_face: np.ndarray) -> List[float]:
        """
        Extracts an L2-normalized deep face embedding vector.
        """
        if self._recognizer is None:
            self._load_model()

        raw_feature = self._recognizer.feature(aligned_face)
        feature = raw_feature.flatten()

        # Ensure L2 normalization
        norm = np.linalg.norm(feature)
        if norm > 1e-9:
            feature = feature / norm

        return feature.astype(float).tolist()

face_embedding_service = FaceEmbeddingService()
