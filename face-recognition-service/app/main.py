import logging
from typing import Optional
from fastapi import FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.firebase.firebase_admin import firebase_service
from app.schemas.face import (
    EnrollRequest,
    EnrollResponse,
    QualityRequest,
    QualityResponse,
    VerifyRequest,
    VerifyResponse,
)
from app.services.face_detection import face_detection_service
from app.services.face_embedding import face_embedding_service
from app.services.face_matching import face_matching_service
from app.services.face_quality import decode_base64_image, face_quality_service
from app.services.liveness import liveness_service

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("face_recognition_service")

app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description="Production-grade Face Verification API for Attendephi with ArcFace / SFace biometrics",
)

# CORS configuration for Flutter Web
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/health")
def health_check():
    return {
        "status": "healthy",
        "service": settings.APP_NAME,
        "version": settings.APP_VERSION,
        "model": settings.FACE_MODEL_NAME,
        "model_version": settings.FACE_MODEL_VERSION,
        "match_threshold": settings.FACE_MATCH_THRESHOLD,
        "margin_threshold": settings.FACE_MARGIN_THRESHOLD,
        "enroll_consistency_threshold": settings.ENROLL_CONSISTENCY_THRESHOLD,
    }

@app.post("/face/quality", response_model=QualityResponse)
def evaluate_face_quality(request: QualityRequest):
    """
    Evaluates face presence, blurriness, illumination, and head pose.
    Provides fast, non-blocking feedback to client viewfinders.
    """
    image = decode_base64_image(request.photo_base64)
    if image is None:
        return QualityResponse(
            is_valid=False,
            error_message="Invalid image format. Could not decode base64 photo.",
        )

    faces = face_detection_service.detect_faces(image)
    if not faces:
        return QualityResponse(
            is_valid=False,
            faces_detected=0,
            error_message="No face detected. Please position your face inside the frame.",
        )

    if len(faces) > 1:
        return QualityResponse(
            is_valid=False,
            faces_detected=len(faces),
            error_message=f"Multiple faces detected ({len(faces)}). Ensure only one person is in the frame.",
        )

    face = faces[0]
    is_valid, error_msg, metrics = face_quality_service.validate_quality(
        image, face.bbox, face.landmarks
    )

    return QualityResponse(
        is_valid=is_valid,
        faces_detected=1,
        sharpness=metrics.get("sharpness", 0.0),
        brightness=metrics.get("brightness", 0.0),
        yaw=metrics.get("yaw", 0.0),
        roll=metrics.get("roll", 0.0),
        error_message=error_msg,
    )

def _extract_enrollment_embedding(photo_base64: str) -> tuple:
    image = decode_base64_image(photo_base64)
    if image is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Failed to decode base64 photo.",
        )

    faces = face_detection_service.detect_faces(image)
    if len(faces) == 0:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="No face detected in photo. Please ensure face is clearly visible.",
        )
    if len(faces) > 1:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Multiple faces detected ({len(faces)}). Only the enrolling member should be in the photo.",
        )

    face = faces[0]
    is_valid, quality_error, metrics = face_quality_service.validate_quality(
        image, face.bbox, face.landmarks, for_enroll=True
    )
    if not is_valid:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=quality_error or "Photo does not meet biometric quality criteria.",
        )

    aligned_face = face_embedding_service.align_and_crop_face(image, face.raw_face_array)
    embedding = face_embedding_service.extract_embedding(aligned_face)
    return embedding, metrics


@app.post("/face/enroll", response_model=EnrollResponse)
def enroll_member_face(request: EnrollRequest):
    """
    Enrolls a member's face into the protected biometric template store:
    1. Validates presence of exactly one face per frame.
    2. Enforces enroll-quality criteria (sharpness, lighting, pose).
    3. Computes deep neural embedding vector(s).
    4. Writes protected template to 'faceTemplates/{memberId}'.
    5. Flags 'faceEnrolled: true' on employee document.
    """
    photos: list[str] = []
    if request.photos_base64:
        photos.extend([p for p in request.photos_base64 if p])
    if request.photo_base64:
        if request.photo_base64 not in photos:
            photos.insert(0, request.photo_base64)

    if not photos:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Provide photo_base64 or photos_base64 for enrollment.",
        )

    extracted: list[list[float]] = []
    quality_scores: list[float] = []
    last_error: Optional[HTTPException] = None
    for photo in photos:
        try:
            embedding, metrics = _extract_enrollment_embedding(photo)
            extracted.append(embedding)
            quality_scores.append(min(1.0, metrics.get("sharpness", 60.0) / 100.0))
        except HTTPException as exc:
            last_error = exc

    if not extracted:
        if last_error is not None:
            raise last_error
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Photo does not meet biometric quality criteria.",
        )

    is_burst = len(photos) > 1
    if is_burst and len(extracted) < settings.MIN_ENROLLMENT_TEMPLATES:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=(
                f"Need at least {settings.MIN_ENROLLMENT_TEMPLATES} clear enrollment frames. "
                "Please keep your face centered in good lighting and try again."
            ),
        )

    if len(extracted) > 1 and not face_matching_service.validate_enrollment_consistency(extracted):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Face enrollment is inconsistent across frames. Please keep your face centered in good lighting and try again.",
        )

    centroid = face_matching_service.compute_centroid(extracted)
    quality_score = float(sum(quality_scores) / len(quality_scores)) if quality_scores else 0.0
    stored = firebase_service.store_face_template(
        member_id=request.member_id,
        chapter_id=request.chapter_id,
        embedding=centroid,
        quality_score=quality_score,
        embeddings=extracted,
    )

    if not stored:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to persist biometric template to secure storage.",
        )

    return EnrollResponse(
        success=True,
        member_id=request.member_id,
        message="Face biometrics successfully enrolled.",
        face_model=settings.FACE_MODEL_NAME,
        face_model_version=settings.FACE_MODEL_VERSION,
        quality_score=quality_score,
    )

@app.post("/face/verify", response_model=VerifyResponse)
def verify_member_face(request: VerifyRequest):
    """
    Production face verification endpoint for attendance check-in:
    1. Validates selfie photo.
    2. Performs face detection (rejects 0 or >1 face).
    3. Runs quality checks (blur, illumination, pose).
    4. Evaluates passive anti-spoofing / liveness.
    5. Retrieves chapter candidates and protected biometric templates.
    6. Extracts probe embedding from live selfie.
    7. Evaluates dual-condition confidence (threshold + runner-up margin).
    8. Returns decision without exposing raw biometric vectors to client.
    """
    image = decode_base64_image(request.photo_base64)
    if image is None:
        return VerifyResponse(
            success=False,
            matched=False,
            reason="INVALID_IMAGE_FORMAT",
            face_detected=False,
        )

    # 1. Face Detection
    faces = face_detection_service.detect_faces(image)
    if len(faces) == 0:
        return VerifyResponse(
            success=True,
            matched=False,
            face_detected=False,
            reason="NO_FACE_DETECTED",
        )

    if len(faces) > 1:
        return VerifyResponse(
            success=True,
            matched=False,
            face_detected=True,
            reason="MULTIPLE_FACES_DETECTED",
        )

    face = faces[0]

    # 2. Quality Check
    is_valid, quality_error, metrics = face_quality_service.validate_quality(
        image, face.bbox, face.landmarks
    )
    if not is_valid:
        return VerifyResponse(
            success=True,
            matched=False,
            quality_passed=False,
            reason=quality_error or "POOR_IMAGE_QUALITY",
        )

    # 3. Liveness / Anti-spoofing check
    liveness_ok, liveness_score, liveness_reason = liveness_service.evaluate_liveness(
        image, face.bbox
    )
    if not liveness_ok:
        return VerifyResponse(
            success=True,
            matched=False,
            liveness_passed=False,
            reason=liveness_reason or "SPOOF_SUSPECTED",
        )

    # 4. Retrieve candidate templates for this chapter
    candidates = firebase_service.get_chapter_candidates(request.chapter_id)
    if not candidates:
        return VerifyResponse(
            success=True,
            matched=False,
            candidates_evaluated=0,
            reason="NO_ENROLLED_MEMBERS_IN_CHAPTER",
        )

    # 5. Extract probe embedding
    aligned_face = face_embedding_service.align_and_crop_face(image, face.raw_face_array)
    probe_embedding = face_embedding_service.extract_embedding(aligned_face)

    # 6. Biometric Candidate Matching
    match_result = face_matching_service.match_probe(
        probe_vector=probe_embedding,
        candidates=candidates,
    )

    return VerifyResponse(
        success=True,
        matched=match_result.matched,
        member_id=match_result.best_member_id,
        member_name=match_result.best_member_name,
        confidence=match_result.confidence,
        similarity=match_result.similarity,
        margin=match_result.margin,
        reason=match_result.reason,
        candidates_evaluated=match_result.total_candidates,
    )
