import os
from pathlib import Path
from pydantic_settings import BaseSettings, SettingsConfigDict

BASE_DIR = Path(__file__).resolve().parent.parent

class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # Service Information
    APP_NAME: str = "Attendephi Face Recognition API"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = False
    PORT: int = 8080
    HOST: str = "0.0.0.0"

    # Firebase Admin SDK credentials
    # Checks local serviceAccountKey.json first, then repository root, then env var
    FIREBASE_CREDENTIALS_PATH: str = str(
        os.getenv(
            "FIREBASE_CREDENTIALS_PATH",
            str(BASE_DIR / "serviceAccountKey.json")
            if (BASE_DIR / "serviceAccountKey.json").exists()
            else str(BASE_DIR.parent / "serviceAccountKey.json")
        )
    )

    # Face Recognition Model
    FACE_MODEL_NAME: str = "arcface"
    FACE_MODEL_VERSION: str = "v1"
    EMBEDDING_DIM: int = 512

    # Biometric Matching Thresholds (Calibrated for Cosine Similarity)
    FACE_MATCH_THRESHOLD: float = 0.72
    FACE_MARGIN_THRESHOLD: float = 0.12
    ENROLL_CONSISTENCY_THRESHOLD: float = 0.80
    MIN_ENROLLMENT_TEMPLATES: int = 3

    # Face Quality Cutoffs (verify — slightly looser than enroll)
    MIN_FACE_SIZE_PX: int = 80
    MIN_SHARPNESS_SCORE: float = 60.0  # Laplacian variance
    MIN_BRIGHTNESS: float = 35.0      # Average pixel intensity
    MAX_BRIGHTNESS: float = 230.0
    MAX_HEAD_YAW_DEG: float = 25.0
    MAX_HEAD_ROLL_DEG: float = 22.0

    # Face Quality Cutoffs (enroll — stricter so bad templates never persist)
    ENROLL_MIN_FACE_SIZE_PX: int = 120
    ENROLL_MIN_SHARPNESS_SCORE: float = 80.0
    ENROLL_MAX_HEAD_YAW_DEG: float = 18.0
    ENROLL_MAX_HEAD_ROLL_DEG: float = 18.0

    # Anti-spoofing / Liveness
    LIVENESS_ENABLED: bool = True
    MIN_LIVENESS_SCORE: float = 0.60

    # CORS
    CORS_ORIGINS: list[str] = ["*"]

settings = Settings()
