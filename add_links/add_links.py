import argparse
import json
import time
from typing import Dict, Any, List, Optional

import pandas as pd
import requests


def load_whatsapp_groups(excel_path: str, sheet_name: str = "וואטסאפ") -> pd.DataFrame:
    """
    הקובץ כולל כמה שורות הסבר ואז טבלה. הטבלה מתחילה אחרי שורת כותרות,
    ובפועל הכותרות יושבות בשורה שמכילה: תחום | שם הקבוצה | אזור | קישור | מידע נוסף
    """
    # header=2 כי בקובץ הזה הכותרות מתחילות בשורה השלישית (אחרי שורות ההסבר)
    df = pd.read_excel(excel_path, sheet_name=sheet_name, header=2)

    # קובץ המקור מגיע עם "Unnamed:*" ולכן נמפה לשמות אמיתיים
    df = df.rename(
        columns={
            "Unnamed: 0": "תחום",
            "Unnamed: 1": "שם הקבוצה",
            "Unnamed: 2": "אזור",
            "Unnamed: 3": "קישור",
            "Unnamed: 4": "מידע נוסף",
        }
    )

    # לפעמים השורה הראשונה אחרי header היא שוב כותרות ("תחום", "שם הקבוצה"...)
    # וגם יש תאים ריקים - ננקה.
    df = df[df["קישור"].notna()]
    df = df[df["קישור"] != "קישור"]

    # ניקוי רווחים
    for col in ["תחום", "שם הקבוצה", "אזור", "קישור", "מידע נוסף"]:
        if col in df.columns:
            df[col] = df[col].astype(str).str.strip()

    # להחזיר NaN על "nan" שנוצר מ-cast ל-str
    df = df.replace({"nan": None, "NaN": None, "None": None})

    df = df.reset_index(drop=True)
    return df


def build_payload(row: Dict[str, Any], user_id: int) -> Dict[str, Any]:
    domain = (row.get("תחום") or "").strip()
    name = (row.get("שם הקבוצה") or "").strip()
    region = (row.get("אזור") or "").strip()
    link = (row.get("קישור") or "").strip()
    extra = (row.get("מידע נוסף") or "").strip()

    description_parts: List[str] = []
    if domain:
        description_parts.append(f"תחום: {domain}")
    if region:
        description_parts.append(f"אזור: {region}")
    if extra:
        description_parts.append(f"מידע נוסף: {extra}")

    description = " | ".join(description_parts) if description_parts else None

    # tags: תיוג מהיר לחיפוש/סינון אצלך
    tags_parts = []
    if domain:
        tags_parts.append(domain)
    if region:
        tags_parts.append(region)
    tags_parts.append("וואטסאפ")
    tags = ", ".join(tags_parts)

    payload = {
        "user_id": user_id,
        "url": link,
        "title": name or link,
        "description": description,
        "tags": tags,
        "platform": "WhatsApp",
    }
    return payload


def post_with_retries(
    session: requests.Session,
    url: str,
    json_payload: Dict[str, Any],
    timeout_sec: int = 20,
    max_retries: int = 4,
    backoff_sec: float = 0.8,
) -> requests.Response:
    last_exc: Optional[Exception] = None
    for attempt in range(1, max_retries + 1):
        try:
            resp = session.post(url, json=json_payload, timeout=timeout_sec)
            # אם קיבלנו שגיאת שרת/רשת - ננסה שוב
            if resp.status_code >= 500:
                time.sleep(backoff_sec * attempt)
                continue
            return resp
        except Exception as e:
            last_exc = e
            time.sleep(backoff_sec * attempt)

    raise RuntimeError(f"Failed after retries. Last error: {last_exc}")


def main():
    ap = argparse.ArgumentParser(description="Upload WhatsApp groups from Excel into Linkis server.")
    ap.add_argument("--excel", required=True, help="Path to the Excel file.")
    ap.add_argument("--base-url", default="http://127.0.0.1:5000", help="Server base URL.")
    ap.add_argument("--user-id", type=int, required=True, help="Verified user_id to create the links.")
    ap.add_argument("--sleep", type=float, default=0.05, help="Sleep between requests (seconds).")
    ap.add_argument("--limit", type=int, default=0, help="Optional limit of rows to upload (0 = all).")
    ap.add_argument("--log", default="upload_log.jsonl", help="Where to write a JSONL log.")
    args = ap.parse_args()

    df = load_whatsapp_groups(args.excel, sheet_name="וואטסאפ")
    if args.limit and args.limit > 0:
        df = df.head(args.limit)

    endpoint = args.base_url.rstrip("/") + "/links"

    session = requests.Session()
    ok_count = 0
    fail_count = 0

    with open(args.log, "w", encoding="utf-8") as f:
        for idx, row in df.iterrows():
            row_dict = row.to_dict()
            payload = build_payload(row_dict, args.user_id)

            # אם אין קישור – דילוג
            if not payload.get("url"):
                rec = {"row": int(idx), "ok": False, "reason": "missing url", "payload": payload}
                f.write(json.dumps(rec, ensure_ascii=False) + "\n")
                fail_count += 1
                continue

            try:
                resp = post_with_retries(session, endpoint, payload)
                if resp.status_code in (200, 201):
                    ok_count += 1
                    rec = {"row": int(idx), "ok": True, "status": resp.status_code, "response": safe_json(resp)}
                else:
                    fail_count += 1
                    rec = {
                        "row": int(idx),
                        "ok": False,
                        "status": resp.status_code,
                        "response_text": resp.text[:2000],
                        "payload": payload,
                    }
                f.write(json.dumps(rec, ensure_ascii=False) + "\n")
            except Exception as e:
                fail_count += 1
                rec = {"row": int(idx), "ok": False, "exception": str(e), "payload": payload}
                f.write(json.dumps(rec, ensure_ascii=False) + "\n")

            time.sleep(args.sleep)

    print(f"Done. success={ok_count} failed={fail_count} total={ok_count + fail_count}")


def safe_json(resp: requests.Response) -> Any:
    try:
        return resp.json()
    except Exception:
        return {"text": resp.text[:2000]}


if __name__ == "__main__":
    main()
