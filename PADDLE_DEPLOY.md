# DEPRECATED

We moved off self-hosted PaddleOCR because free-tier hosts (Render 512MB)
couldn't fit the model at inference time — it OOM-crashed on every card.

The current OCR chain is:

1. **Google ML Kit** — on-device, mobile only, no key needed
2. **OCR.space** — hosted free API, web, 500 req/day, email signup only
3. NVIDIA / Gemini / tesseract.js — optional fallback tiers

See [`OCR_SETUP.md`](./OCR_SETUP.md) for setup.

**Safe to delete:**
- this file (`PADDLE_DEPLOY.md`)
- `paddle_ocr_service/` folder at the repo root
- `lib/features/scan/data/paddle_ocr_extraction_service.dart`
