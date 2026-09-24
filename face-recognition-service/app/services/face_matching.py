from dataclasses import dataclass
from typing import List, Optional, Tuple, Dict, Any
import numpy as np

from app.config import settings

@dataclass
class MatchResult:
    matched: bool
    best_member_id: Optional[str] = None
    best_member_name: Optional[str] = None
    confidence: float = 0.0
    similarity: float = 0.0
    margin: float = 0.0
    reason: Optional[str] = None
    second_similarity: float = 0.0
    total_candidates: int = 0

def calculate_cosine_similarity(vec1: np.ndarray, vec2: np.ndarray) -> float:
    """Calculates cosine similarity between two feature vectors."""
    dot = np.dot(vec1, vec2)
    norm1 = np.linalg.norm(vec1)
    norm2 = np.linalg.norm(vec2)
    if norm1 < 1e-9 or norm2 < 1e-9:
        return 0.0
    return float(np.clip(dot / (norm1 * norm2), -1.0, 1.0))

def cosine_to_confidence_percentage(similarity: float, threshold: float = 0.72) -> float:
    """
    Calibrated mapping from cosine similarity to an intuitive 0% - 100% confidence scale.
    - Similarity <= 0.25: 0% confidence
    - Similarity == threshold (0.72): 80% confidence
    - Similarity >= 0.90: 98% - 100% confidence
    """
    if similarity <= 0.25:
        return 0.0
    if similarity >= 0.95:
        return 99.5

    if similarity < threshold:
        # Scale between 0% and 79%
        ratio = (similarity - 0.25) / (threshold - 0.25)
        return float(np.clip(ratio * 79.0, 0.0, 79.0))
    else:
        # Scale between 80% and 99.5%
        ratio = (similarity - threshold) / (0.95 - threshold)
        return float(np.clip(80.0 + ratio * 19.5, 80.0, 99.5))

class FaceMatchingService:
    def __init__(self):
        self.match_threshold = settings.FACE_MATCH_THRESHOLD
        self.margin_threshold = settings.FACE_MARGIN_THRESHOLD
        self.enroll_consistency_threshold = settings.ENROLL_CONSISTENCY_THRESHOLD

    def _candidate_templates(self, cand: Dict[str, Any]) -> List[np.ndarray]:
        templates: List[np.ndarray] = []
        raw_list = cand.get("embeddings")
        if isinstance(raw_list, list) and raw_list:
            for item in raw_list:
                if item and len(item) > 0:
                    templates.append(np.asarray(item, dtype=np.float32))
        if not templates:
            raw_emb = cand.get("embedding")
            if raw_emb and len(raw_emb) > 0:
                templates.append(np.asarray(raw_emb, dtype=np.float32))
        return templates

    def validate_enrollment_consistency(
        self,
        embeddings: List[List[float]],
        threshold: Optional[float] = None,
    ) -> bool:
        floor = threshold if threshold is not None else self.enroll_consistency_threshold
        if len(embeddings) < 2:
            return False
        vectors = [np.asarray(e, dtype=np.float32) for e in embeddings]
        for i in range(len(vectors)):
            for j in range(i + 1, len(vectors)):
                if calculate_cosine_similarity(vectors[i], vectors[j]) < floor:
                    return False
        return True

    def compute_centroid(self, embeddings: List[List[float]]) -> List[float]:
        if not embeddings:
            return []
        stacked = np.asarray(embeddings, dtype=np.float32)
        centroid = np.mean(stacked, axis=0)
        norm = np.linalg.norm(centroid)
        if norm > 1e-9:
            centroid = centroid / norm
        return centroid.astype(float).tolist()

    def match_probe(
        self,
        probe_vector: np.ndarray,
        candidates: List[Dict[str, Any]],  # Each item: embedding and/or embeddings
        match_threshold: Optional[float] = None,
        margin_threshold: Optional[float] = None,
    ) -> MatchResult:
        """
        Performs robust 1:N candidate matching against chapter member templates.
        Per member, score is the max cosine across that member's templates.
        Enforces:
        1. best_similarity >= match_threshold
        2. (best_similarity - second_best_similarity) >= margin_threshold
        """
        threshold = match_threshold if match_threshold is not None else self.match_threshold
        margin = margin_threshold if margin_threshold is not None else self.margin_threshold

        if not candidates:
            return MatchResult(
                matched=False,
                reason="NO_CANDIDATES_IN_CHAPTER",
                total_candidates=0,
            )

        probe = np.asarray(probe_vector, dtype=np.float32)

        best_score = -1.0
        second_score = -1.0
        best_candidate: Optional[Dict[str, Any]] = None

        valid_candidate_count = 0

        for cand in candidates:
            templates = self._candidate_templates(cand)
            candidate_best = -1.0
            for template in templates:
                if template.shape != probe.shape:
                    continue
                sim = calculate_cosine_similarity(probe, template)
                if sim > candidate_best:
                    candidate_best = sim

            if candidate_best < 0:
                continue

            valid_candidate_count += 1
            if candidate_best > best_score:
                second_score = best_score
                best_score = candidate_best
                best_candidate = cand
            elif candidate_best > second_score:
                second_score = candidate_best

        if best_candidate is None or valid_candidate_count == 0:
            return MatchResult(
                matched=False,
                reason="NO_VALID_TEMPLATES",
                total_candidates=len(candidates),
            )

        # Runner-up margin calculation
        if second_score < 0:
            # Single candidate in chapter
            actual_margin = 1.0
        else:
            actual_margin = best_score - second_score

        confidence = cosine_to_confidence_percentage(best_score, threshold=threshold)

        # Evaluate decision conditions
        is_confident = best_score >= threshold
        is_separated = actual_margin >= margin or valid_candidate_count == 1

        if not is_confident:
            return MatchResult(
                matched=False,
                confidence=round(confidence, 1),
                similarity=round(best_score, 4),
                margin=round(actual_margin, 4),
                second_similarity=round(second_score, 4),
                reason="LOW_CONFIDENCE",
                total_candidates=valid_candidate_count,
            )

        if not is_separated:
            return MatchResult(
                matched=False,
                best_member_id=best_candidate.get("member_id"),
                confidence=round(confidence, 1),
                similarity=round(best_score, 4),
                margin=round(actual_margin, 4),
                second_similarity=round(second_score, 4),
                reason="AMBIGUOUS_MATCH",
                total_candidates=valid_candidate_count,
            )

        # Successful positive match
        return MatchResult(
            matched=True,
            best_member_id=best_candidate.get("member_id"),
            best_member_name=best_candidate.get("name"),
            confidence=round(confidence, 1),
            similarity=round(best_score, 4),
            margin=round(actual_margin, 4),
            second_similarity=round(second_score, 4),
            total_candidates=valid_candidate_count,
        )

face_matching_service = FaceMatchingService()
