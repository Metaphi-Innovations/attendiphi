import base64
from pathlib import Path
import sys
import cv2
import numpy as np
import pytest
from fastapi.testclient import TestClient

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.main import app
from app.services.face_matching import face_matching_service
from app.services.face_quality import compute_sharpness, compute_brightness
from app.services.liveness import liveness_service

client = TestClient(app)

def create_dummy_base64_image(color=(200, 200, 200), draw_face: bool = True) -> str:
    img = np.zeros((300, 300, 3), dtype=np.uint8)
    img[:] = color
    if draw_face:
        # Draw face oval
        cv2.ellipse(img, (150, 150), (60, 80), 0, 0, 360, (180, 190, 230), -1)
        # Eyes
        cv2.circle(img, (130, 130), 6, (40, 40, 40), -1)
        cv2.circle(img, (170, 130), 6, (40, 40, 40), -1)
        # Nose
        cv2.line(img, (150, 145), (150, 165), (100, 100, 100), 2)
        # Mouth
        cv2.ellipse(img, (150, 185), (20, 5), 0, 0, 180, (50, 50, 160), -1)
    
    _, buffer = cv2.imencode(".jpg", img)
    return base64.b64encode(buffer).decode("utf-8")

def test_health_check():
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert "model" in data
    assert "match_threshold" in data

def test_face_quality_no_face():
    blank_b64 = create_dummy_base64_image(draw_face=False)
    response = client.post("/face/quality", json={"photo_base64": blank_b64})
    assert response.status_code == 200
    data = response.json()
    assert data["is_valid"] is False
    assert data["faces_detected"] == 0

def test_face_quality_with_face():
    face_b64 = create_dummy_base64_image(draw_face=True)
    response = client.post("/face/quality", json={"photo_base64": face_b64})
    assert response.status_code == 200
    data = response.json()
    assert "faces_detected" in data
    assert "sharpness" in data
    assert "brightness" in data

def test_verify_rejects_empty_chapter(monkeypatch):
    from app.firebase.firebase_admin import firebase_service
    monkeypatch.setattr(firebase_service, "get_chapter_candidates", lambda cid: [])

    face_b64 = create_dummy_base64_image(draw_face=True)
    response = client.post("/face/verify", json={
        "photo_base64": face_b64,
        "chapter_id": "non_existent_chapter_999"
    })
    assert response.status_code == 200
    data = response.json()
    assert data["matched"] is False
    assert data["reason"] in ["NO_ENROLLED_MEMBERS_IN_CHAPTER", "NO_FACE_DETECTED", "POOR_IMAGE_QUALITY"]

def test_matching_confidence_margin_rejection():
    # Probe vector
    probe = [1.0, 0.0, 0.0]
    # Two candidates that are nearly identical (ambiguous runner-up)
    candidates = [
        {"member_id": "m1", "name": "Member 1", "embedding": [0.95, 0.05, 0.0]},
        {"member_id": "m2", "name": "Member 2", "embedding": [0.94, 0.06, 0.0]},
    ]
    result = face_matching_service.match_probe(
        probe_vector=probe,
        candidates=candidates,
        match_threshold=0.72,
        margin_threshold=0.12,
    )
    # Both are high similarity (~0.95 vs ~0.94), margin is only ~0.01 (< 0.12)
    # Must reject as AMBIGUOUS_MATCH rather than blindly picking m1!
    assert result.matched is False
    assert result.reason == "AMBIGUOUS_MATCH"

def test_matching_clear_winner():
    probe = [1.0, 0.0, 0.0]
    candidates = [
        {"member_id": "m1", "name": "Member 1", "embedding": [0.98, 0.02, 0.0]},
        {"member_id": "m2", "name": "Member 2", "embedding": [0.20, 0.80, 0.0]},
    ]
    result = face_matching_service.match_probe(
        probe_vector=probe,
        candidates=candidates,
        match_threshold=0.72,
        margin_threshold=0.12,
    )
    assert result.matched is True
    assert result.best_member_id == "m1"
    assert result.confidence >= 90.0


def test_matching_max_score_across_member_templates():
    probe = [1.0, 0.0, 0.0]
    candidates = [
        {
            "member_id": "m1",
            "name": "Member 1",
            "embeddings": [
                [0.20, 0.80, 0.0],
                [0.98, 0.02, 0.0],
                [0.10, 0.90, 0.0],
            ],
        },
        {"member_id": "m2", "name": "Member 2", "embedding": [0.15, 0.85, 0.0]},
    ]
    result = face_matching_service.match_probe(
        probe_vector=probe,
        candidates=candidates,
        match_threshold=0.72,
        margin_threshold=0.12,
    )
    assert result.matched is True
    assert result.best_member_id == "m1"
    assert result.similarity >= 0.97


def test_matching_same_member_templates_are_not_rivals():
    probe = [1.0, 0.0, 0.0]
    candidates = [
        {
            "member_id": "m1",
            "name": "Member 1",
            "embeddings": [
                [0.98, 0.02, 0.0],
                [0.97, 0.03, 0.0],
            ],
        },
    ]
    result = face_matching_service.match_probe(
        probe_vector=probe,
        candidates=candidates,
        match_threshold=0.72,
        margin_threshold=0.12,
    )
    assert result.matched is True
    assert result.best_member_id == "m1"
    assert result.reason is None


def test_matching_legacy_single_embedding_still_matches():
    probe = [1.0, 0.0, 0.0]
    candidates = [
        {"member_id": "m1", "name": "Member 1", "embedding": [0.99, 0.01, 0.0]},
        {"member_id": "m2", "name": "Member 2", "embedding": [0.05, 0.95, 0.0]},
    ]
    result = face_matching_service.match_probe(
        probe_vector=probe,
        candidates=candidates,
    )
    assert result.matched is True
    assert result.best_member_id == "m1"


def test_enrollment_consistency_and_centroid():
    similar = [
        [1.0, 0.0, 0.0],
        [0.99, 0.01, 0.0],
        [0.98, 0.02, 0.0],
    ]
    assert face_matching_service.validate_enrollment_consistency(similar) is True
    centroid = face_matching_service.compute_centroid(similar)
    assert len(centroid) == 3
    assert abs((centroid[0] ** 2 + centroid[1] ** 2 + centroid[2] ** 2) ** 0.5 - 1.0) < 1e-5

    divergent = [
        [1.0, 0.0, 0.0],
        [0.0, 1.0, 0.0],
    ]
    assert face_matching_service.validate_enrollment_consistency(divergent) is False
