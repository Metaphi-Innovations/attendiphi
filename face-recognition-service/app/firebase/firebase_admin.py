import logging
import os
from pathlib import Path
from typing import List, Dict, Any, Optional
import firebase_admin
from firebase_admin import credentials, firestore

from app.config import settings

logger = logging.getLogger("face_recognition_service.firebase")

class FirebaseService:
    def __init__(self):
        self._db: Optional[firestore.firestore.Client] = None
        self._init_firebase()

    def _init_firebase(self):
        try:
            if not firebase_admin._apps:
                cred_path = settings.FIREBASE_CREDENTIALS_PATH
                if os.path.exists(cred_path):
                    cred = credentials.Certificate(cred_path)
                    firebase_admin.initialize_app(cred)
                    logger.info(f"Firebase Admin initialized with credentials from: {cred_path}")
                else:
                    # In GCP Cloud Run or Cloud Functions, use Application Default Credentials
                    firebase_admin.initialize_app()
                    logger.info("Firebase Admin initialized with Application Default Credentials (ADC)")
            self._db = firestore.client()
        except Exception as e:
            logger.warning(f"Could not initialize Firebase Admin SDK: {e}. Running in standalone mode.")
            self._db = None

    @property
    def db(self) -> Optional[firestore.firestore.Client]:
        if self._db is None:
            self._init_firebase()
        return self._db

    def get_chapter_candidates(self, chapter_id: str) -> List[Dict[str, Any]]:
        """
        Retrieves active members belonging to a chapter and loads their protected biometric templates.
        Biometric templates are stored in the protected 'faceTemplates/{memberId}' collection.
        """
        if self.db is None:
            logger.warning("Firestore client unavailable. Returning empty candidate list.")
            return []

        try:
            clean_chapter_id = chapter_id.strip()
            # 1. Fetch active employees in this chapter
            query = self.db.collection("employees").where("isActive", "==", True)
            if clean_chapter_id:
                query = query.where("adminId", "==", clean_chapter_id)

            employee_docs = query.get()
            candidates = []

            for emp_doc in employee_docs:
                emp_data = emp_doc.to_dict()
                member_id = emp_doc.id
                name = emp_data.get("name", "Unknown Member")

                # 2. Query protected face template from faceTemplates/{memberId}
                template_doc = self.db.collection("faceTemplates").doc(member_id).get()
                embedding = None

                if template_doc.exists:
                    tmpl_data = template_doc.to_dict()
                    embedding = tmpl_data.get("embedding")

                # Fallback to employee document embedding if template not yet migrated
                if not embedding and "faceEmbedding" in emp_data:
                    embedding = emp_data.get("faceEmbedding")

                if embedding and isinstance(embedding, list) and len(embedding) > 0:
                    candidates.append({
                        "member_id": member_id,
                        "name": name,
                        "embedding": embedding,
                    })

            logger.info(f"Retrieved {len(candidates)} candidate templates for chapter: {chapter_id}")
            return candidates
        except Exception as e:
            logger.error(f"Error retrieving chapter candidates for {chapter_id}: {e}", exc_info=True)
            return []

    def store_face_template(
        self,
        member_id: str,
        chapter_id: str,
        embedding: List[float],
        quality_score: float = 1.0,
    ) -> bool:
        """
        Securely stores biometric template in protected 'faceTemplates/{memberId}' collection
        and marks employee document as face-enrolled with model version metadata.
        """
        if self.db is None:
            logger.error("Firestore client unavailable for template storage.")
            return False

        try:
            # 1. Write protected template to faceTemplates
            template_ref = self.db.collection("faceTemplates").doc(member_id)
            template_ref.set({
                "memberId": member_id,
                "adminId": chapter_id,
                "embedding": embedding,
                "faceModel": settings.FACE_MODEL_NAME,
                "faceModelVersion": settings.FACE_MODEL_VERSION,
                "qualityScore": quality_score,
                "updatedAt": firestore.SERVER_TIMESTAMP,
            })

            # 2. Update employee metadata (never expose raw embedding directly in employees doc)
            emp_ref = self.db.collection("employees").doc(member_id)
            emp_ref.set({
                "faceEnrolled": True,
                "faceModel": settings.FACE_MODEL_NAME,
                "faceModelVersion": settings.FACE_MODEL_VERSION,
                "enrolledAt": firestore.SERVER_TIMESTAMP,
            }, merge=True)

            logger.info(f"Successfully stored protected face template for member: {member_id}")
            return True
        except Exception as e:
            logger.error(f"Failed to store face template for member {member_id}: {e}", exc_info=True)
            return False

    def delete_face_template(self, member_id: str) -> bool:
        """Removes a member's biometric template upon request."""
        if self.db is None:
            return False
        try:
            self.db.collection("faceTemplates").doc(member_id).delete()
            self.db.collection("employees").doc(member_id).set({
                "faceEnrolled": False,
                "faceModel": None,
                "faceModelVersion": None,
            }, merge=True)
            return True
        except Exception as e:
            logger.error(f"Failed to delete face template for {member_id}: {e}")
            return False

firebase_service = FirebaseService()
