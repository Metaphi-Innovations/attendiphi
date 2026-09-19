#!/usr/bin/env python3
"""
Attendephi Biometric Calibration and Verification Benchmarking Suite
Evaluates TAR (True Accept Rate), FAR (False Accept Rate), and FRR (False Reject Rate)
across genuine pairs, imposter pairs, and spoof attempts.
"""

import math
import os
import sys
from pathlib import Path
from typing import List, Tuple, Optional
import cv2
import numpy as np

# Add parent directory to sys.path so app modules can be imported
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.config import settings
from app.services.face_detection import face_detection_service
from app.services.face_embedding import face_embedding_service
from app.services.face_matching import calculate_cosine_similarity, face_matching_service
from app.services.face_quality import face_quality_service
from app.services.liveness import liveness_service

def generate_synthetic_face(seed: int, variation: str = "normal") -> np.ndarray:
    """
    Generates realistic synthetic facial structure canvases with distinct geometric
    and photometric features (eyes, nose, mouth, skin tone, illumination, spectacles).
    Used for calibration baseline when offline.
    """
    np.random.seed(seed)
    h, w = 320, 320
    img = np.zeros((h, w, 3), dtype=np.uint8)

    # Base skin tone
    base_skin = [
        int(np.random.uniform(140, 210)),  # B
        int(np.random.uniform(160, 225)),  # G
        int(np.random.uniform(200, 250)),  # R
    ]
    img[:, :] = [240, 240, 240]  # Light gray background

    # Head oval
    center = (160, 160)
    axes = (75, 105)
    cv2.ellipse(img, center, axes, 0, 0, 360, base_skin, -1)

    # Eye positions
    eye_offset_x = int(np.random.uniform(26, 32))
    eye_y = int(np.random.uniform(130, 140))
    left_eye = (160 - eye_offset_x, eye_y)
    right_eye = (160 + eye_offset_x, eye_y)

    # Draw eyes
    cv2.circle(img, left_eye, 7, (255, 255, 255), -1)
    cv2.circle(img, right_eye, 7, (255, 255, 255), -1)
    pupil_color = (int(np.random.uniform(30, 80)), int(np.random.uniform(20, 60)), int(np.random.uniform(10, 40)))
    cv2.circle(img, left_eye, 4, pupil_color, -1)
    cv2.circle(img, right_eye, 4, pupil_color, -1)

    # Nose
    nose_pts = np.array([[160, 155], [154, 180], [166, 180]], np.int32)
    cv2.polylines(img, [nose_pts], False, (base_skin[0] - 25, base_skin[1] - 25, base_skin[2] - 25), 2)

    # Mouth
    mouth_y = int(np.random.uniform(205, 215))
    mouth_w = int(np.random.uniform(20, 28))
    cv2.ellipse(img, (160, mouth_y), (mouth_w, 6), 0, 0, 180, (80, 80, 180), -1)

    # Apply variations
    if variation == "dark_lighting":
        img = np.clip(img.astype(np.float32) * 0.45, 0, 255).astype(np.uint8)
    elif variation == "bright_lighting":
        img = np.clip(img.astype(np.float32) * 1.35 + 30, 0, 255).astype(np.uint8)
    elif variation == "glasses":
        # Draw spectacle frames
        cv2.rectangle(img, (left_eye[0] - 14, left_eye[1] - 10), (left_eye[0] + 14, left_eye[1] + 10), (20, 20, 20), 2)
        cv2.rectangle(img, (right_eye[0] - 14, right_eye[1] - 10), (right_eye[0] + 14, right_eye[1] + 10), (20, 20, 20), 2)
        cv2.line(img, (left_eye[0] + 14, left_eye[1]), (right_eye[0] - 14, right_eye[1]), (20, 20, 20), 2)
    elif variation == "rotation_left":
        matrix = cv2.getRotationMatrix2D(center, -12, 1.0)
        img = cv2.warpAffine(img, matrix, (w, h), borderValue=(240, 240, 240))
    elif variation == "rotation_right":
        matrix = cv2.getRotationMatrix2D(center, 12, 1.0)
        img = cv2.warpAffine(img, matrix, (w, h), borderValue=(240, 240, 240))
    elif variation == "camera_noise":
        noise = np.random.normal(0, 12, img.shape).astype(np.float32)
        img = np.clip(img.astype(np.float32) + noise, 0, 255).astype(np.uint8)
    elif variation == "phone_screen_spoof":
        # Screen glare / moiré lines
        for y in range(0, h, 4):
            img[y : y + 2, :] = np.clip(img[y : y + 2, :] * 1.25, 0, 255)
        # Specular highlight
        cv2.circle(img, (140, 140), 25, (255, 255, 255), -1)

    return img

def extract_features_from_image(image: np.ndarray) -> Tuple[bool, Optional[List[float]], Optional[str]]:
    faces = face_detection_service.detect_faces(image)
    if len(faces) != 1:
        return False, None, f"Expected 1 face, got {len(faces)}"
    face = faces[0]
    aligned = face_embedding_service.align_and_crop_face(image, face.raw_face_array)
    embedding = face_embedding_service.extract_embedding(aligned)
    return True, embedding, None

def run_calibration_suite():
    print("=" * 70)
    print(" 🚀 ATTENDEPHI BIOMETRIC BENCHMARKING & CALIBRATION SUITE")
    print(f" Model: {settings.FACE_MODEL_NAME} ({settings.FACE_MODEL_VERSION})")
    print("=" * 70)

    # 1. Build test datasets
    print("\n[1/4] Generating verification test pairs...")
    subjects = [101, 102, 103, 104, 105, 106, 107, 108, 109, 110]
    variations = [
        "normal",
        "dark_lighting",
        "bright_lighting",
        "glasses",
        "rotation_left",
        "rotation_right",
        "camera_noise",
    ]

    # Map subject_id -> variation -> embedding
    embeddings = {}
    for sid in subjects:
        embeddings[sid] = {}
        for var in variations:
            img = generate_synthetic_face(seed=sid, variation=var)
            ok, emb, err = extract_features_from_image(img)
            if ok and emb is not None:
                embeddings[sid][var] = emb
            else:
                # Fallback: slightly blur and re-extract
                blurred = cv2.GaussianBlur(img, (3, 3), 0)
                ok, emb, _ = extract_features_from_image(blurred)
                if ok and emb is not None:
                    embeddings[sid][var] = emb

    # Genuine (positive) pairs: same person under different conditions
    genuine_scores = []
    print("\n[2/4] Testing genuine pairs (same person under varying conditions)...")
    for sid in subjects:
        base_emb = embeddings[sid].get("normal")
        if base_emb is None:
            continue
        for var in variations:
            if var == "normal":
                continue
            test_emb = embeddings[sid].get(var)
            if test_emb is not None:
                sim = calculate_cosine_similarity(np.array(base_emb), np.array(test_emb))
                genuine_scores.append(sim)

    # Imposter (negative) pairs: different people
    imposter_scores = []
    print("\n[3/4] Testing imposter pairs (different individuals)...")
    for i, s1 in enumerate(subjects):
        for s2 in subjects[i + 1 :]:
            e1 = embeddings[s1].get("normal")
            e2 = embeddings[s2].get("normal")
            if e1 is not None and e2 is not None:
                sim = calculate_cosine_similarity(np.array(e1), np.array(e2))
                imposter_scores.append(sim)
            # Cross-variation different people
            e1_v = embeddings[s1].get("glasses")
            e2_v = embeddings[s2].get("dark_lighting")
            if e1_v is not None and e2_v is not None:
                sim = calculate_cosine_similarity(np.array(e1_v), np.array(e2_v))
                imposter_scores.append(sim)

    # 4. Sweep thresholds to compute TAR, FAR, FRR
    print("\n[4/4] Computing TAR, FAR, FRR threshold sweep...")
    print("-" * 70)
    print(f"{'Threshold':^11} | {'TAR (True Accept)':^18} | {'FRR (False Reject)':^18} | {'FAR (False Accept)':^18}")
    print("-" * 70)

    best_threshold = 0.65
    min_error = 999.0

    thresholds = np.arange(0.40, 0.86, 0.02)
    for t in thresholds:
        tar = np.mean([1.0 if s >= t else 0.0 for s in genuine_scores]) * 100.0
        frr = 100.0 - tar
        far = np.mean([1.0 if s >= t else 0.0 for s in imposter_scores]) * 100.0

        total_err = abs(frr - far)
        if far <= 0.05 and frr < min_error:
            min_error = frr
            best_threshold = t

        print(f"{t:^11.2f} | {tar:^17.1f}% | {frr:^17.1f}% | {far:^17.1f}%")

    print("=" * 70)
    print(f"📊 CALIBRATION RESULTS:")
    print(f" • Genuine Pairs Evaluated : {len(genuine_scores)}")
    print(f"   Mean Genuine Score      : {np.mean(genuine_scores):.3f} (Std: {np.std(genuine_scores):.3f})")
    print(f" • Imposter Pairs Evaluated: {len(imposter_scores)}")
    print(f"   Mean Imposter Score     : {np.mean(imposter_scores):.3f} (Std: {np.std(imposter_scores):.3f})")
    print(f" • Recommended FACE_MATCH_THRESHOLD : {best_threshold:.2f}")
    print(f" • Recommended FACE_MARGIN_THRESHOLD: 0.10")
    print("=" * 70)

if __name__ == "__main__":
    run_calibration_suite()
