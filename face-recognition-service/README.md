# Attendephi Face Recognition Microservice

Production-grade biometric face verification and enrollment service built with **Python 3.12 + FastAPI + ArcFace/SFace + OpenCV YuNet + Firebase Admin SDK**.

## Features

- **Neural Face Detection**: OpenCV YuNet ONNX with 5-point facial landmark alignment.
- **Deep Biometric Embeddings**: SFace / ArcFace L2-normalized 128-D / 512-D hyperspherical embeddings.
- **Biometric Quality Control**: Automatic checks for image blur (Laplacian variance), illumination, size, and head pose angles (yaw/roll).
- **Passive Anti-Spoofing**: High-frequency Fourier transform analysis and RGB channel balance to detect printed photos and phone screen replays.
- **Candidate Scoping**: Matches live selfies strictly against members enrolled in the scanned QR chapter.
- **Confidence & Margin Decision**: Requires both `similarity >= FACE_MATCH_THRESHOLD` (default 0.65) and `(best - runner_up) >= FACE_MARGIN_THRESHOLD` (default 0.10) to reject ambiguous near-misses.
- **Biometric Protection**: Securely stores templates in `faceTemplates/{memberId}` accessible only via the backend service; client apps never receive raw embeddings.

## API Endpoints

- `GET /health` - Service health status, model metadata, and configured thresholds.
- `POST /face/quality` - Evaluates image quality, blur, lighting, and pose for live viewfinder feedback.
- `POST /face/enroll` - Enrolls a member's face into protected storage after validating quality.
- `POST /face/verify` - Verifies live selfie against enrolled chapter members with confidence scoring.

## Local Execution

```bash
# 1. Create and activate virtualenv
python3.12 -m venv venv
source venv/bin/activate

# 2. Install dependencies
pip install -r requirements.txt

# 3. Run server
uvicorn app.main:app --reload --port 8080
```

## Running Tests and Calibration

```bash
# Run pytest test suite
pytest tests/ -v

# Run calibration benchmark
python scripts/calibrate.py
```
