from typing import List, Optional
from pydantic import BaseModel, Field

class QualityRequest(BaseModel):
    photo_base64: str = Field(..., description="Base64 encoded JPEG or PNG image")

class QualityResponse(BaseModel):
    is_valid: bool
    faces_detected: int = 0
    sharpness: float = 0.0
    brightness: float = 0.0
    yaw: float = 0.0
    roll: float = 0.0
    error_message: Optional[str] = None

class LivenessResponse(BaseModel):
    passed: bool
    score: float
    reason: Optional[str] = None

class VerifyRequest(BaseModel):
    photo_base64: str = Field(..., description="Base64 encoded JPEG or PNG selfie")
    chapter_id: str = Field(..., description="Admin ID / Chapter ID to scope matching candidates")
    location_id: Optional[str] = Field(None, description="Optional venue location ID")

class CandidateMatchInfo(BaseModel):
    member_id: str
    member_name: str
    similarity: float

class VerifyResponse(BaseModel):
    success: bool
    matched: bool
    member_id: Optional[str] = None
    member_name: Optional[str] = None
    confidence: Optional[float] = None
    similarity: Optional[float] = None
    margin: Optional[float] = None
    reason: Optional[str] = None
    face_detected: bool = True
    liveness_passed: bool = True
    quality_passed: bool = True
    candidates_evaluated: int = 0

class EnrollRequest(BaseModel):
    member_id: str = Field(..., description="Target member document ID in employees collection")
    chapter_id: str = Field(..., description="Admin ID / Chapter ID")
    photo_base64: Optional[str] = Field(None, description="Base64 encoded photo for biometric enrollment")
    photos_base64: Optional[List[str]] = Field(None, description="Optional multi-frame burst for robust enrollment")
    member_name: Optional[str] = None

class EnrollResponse(BaseModel):
    success: bool
    member_id: str
    message: str
    face_model: str = "arcface"
    face_model_version: str = "v1"
    quality_score: float = 0.0
