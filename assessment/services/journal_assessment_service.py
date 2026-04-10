"""
Journal Assessment Service
============================

هذا هو الملف الذي يربط محرك تحليل اليوميات (external/journal_analyzer/engine.py)
بباقي النظام.

عندما ينتهي مطوّر المحرك، هذا الملف هو المكان الوحيد الذي سيتغير:
- فك تعليق `from external.journal_analyzer.engine import JournalAnalysisEngine`
- احذف الـ fallback response.

لا حاجة لتعديل أي ملف آخر في المشروع.
"""

import logging

logger = logging.getLogger(__name__)


def analyze_journal(journal_text: str) -> dict:
    """
    الدالة المركزية لتحليل اليومية.
    تُستدعى من المشروع وتتعامل مع المحرك الخارجي.

    Returns:
        dict بنفس الشكل الموصوف في engine.py:
        {
            "sentiment": str,
            "sentiment_score": float,
            "detected_keywords": list[str],
            "risk_flag": bool,
            "summary": str,
            "engine_ready": bool  # ← يخبرك إذا المحرك مُدمج أم لا
        }
    """
    try:
        # ─── اربط المحرك هنا عند الجاهزية ───────────────────────────────
        # from external.journal_analyzer.engine import JournalAnalysisEngine
        # engine = JournalAnalysisEngine()
        # result = engine.analyze(journal_text)
        # result["engine_ready"] = True
        # return result
        # ─────────────────────────────────────────────────────────────────

        # Fallback حتى يصبح المحرك جاهزاً
        logger.info("[JOURNAL ANALYSIS] Engine not connected yet — returning placeholder response.")
        return {
            "sentiment": "neutral",
            "sentiment_score": 0.0,
            "detected_keywords": [],
            "risk_flag": False,
            "summary": "",
            "engine_ready": False
        }

    except NotImplementedError:
        logger.warning("[JOURNAL ANALYSIS] Engine is implemented but analyze() not complete yet.")
        return {
            "sentiment": "neutral",
            "sentiment_score": 0.0,
            "detected_keywords": [],
            "risk_flag": False,
            "summary": "",
            "engine_ready": False
        }

    except Exception as e:
        logger.error(f"[JOURNAL ANALYSIS] Unexpected error: {e}")
        return {
            "sentiment": "neutral",
            "sentiment_score": 0.0,
            "detected_keywords": [],
            "risk_flag": False,
            "summary": "",
            "engine_ready": False
        }
