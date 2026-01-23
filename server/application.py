from __future__ import annotations
from flask import Flask, jsonify, request
from flask_cors import CORS
from flask_sqlalchemy import SQLAlchemy
from datetime import datetime, timedelta
import os
import random
import smtplib
from email.mime.text import MIMEText
from sqlalchemy import func, or_
import secrets
from urllib.parse import quote_plus
from sqlalchemy.dialects.postgresql import TSVECTOR
from sqlalchemy import text
from rank_bm25 import BM25Okapi 
from pydantic import BaseModel, ValidationError
from typing import List
import cohere
import json
from pathlib import Path
from flask import send_file

from database import db
from db_configuration import sync_db
from get_image import get_whatsapp_image_url
from models import User, Link, Category, LinkLike
 
# ---------------- COHERE API KEY ----------------
COHERE_API_KEY = "DUveGw7OXleT0sTG0MxeV4Hjd9oKUrl43bStQPby"
COHERE_RERANK_MODEL = "COHERE_RERANK_MODEL=rerank-v3.5"

co = cohere.Client(COHERE_API_KEY)  # Initialize Cohere client

app = Flask(__name__)
CORS(app)

# ---------------- DB CONFIG ----------------
app.config["SQLALCHEMY_DATABASE_URI"] = os.getenv(
    "DATABASE_URL",
    "postgresql://postgres:sfhr1357@localhost:5432/linkis_db"
)
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

db.init_app(app)
# ---------------- EMAIL / VERIFICATION ----------------

def generate_verification_code() -> str:
    return f"{random.randint(100000, 999999)}"

GMAIL_ADDRESS = "linkiz12321@gmail.com"
GMAIL_APP_PASSWORD = "fhaq lcdq jiri ivcd" 

def send_verification_email(email: str, code: str):
    msg = MIMEText(f"Your verification code is: {code}")
    msg["Subject"] = "Your Verification Code"
    msg["From"] = GMAIL_ADDRESS
    msg["To"] = email

    try:
        with smtplib.SMTP_SSL("smtp.gmail.com", 465) as smtp:
            smtp.login(GMAIL_ADDRESS, GMAIL_APP_PASSWORD)
            smtp.send_message(msg)
        print(f"[EMAIL SENT] Code sent to {email}")
    except Exception as e:
        print("[EMAIL ERROR]", e)


def send_password_reset_email(email: str, reset_link: str):
    msg = MIMEText(
        "You requested a password reset.\n\n"
        f"Click this link to reset your password:\n{reset_link}\n\n"
        "This link expires in 30 minutes.\n"
        "If you didn't request this, ignore this email."
    )
    msg["Subject"] = "Reset your password"
    msg["From"] = GMAIL_ADDRESS
    msg["To"] = email

    try:
        with smtplib.SMTP_SSL("smtp.gmail.com", 465) as smtp:
            smtp.login(GMAIL_ADDRESS, GMAIL_APP_PASSWORD)
            smtp.send_message(msg)
        print(f"[RESET EMAIL SENT] to {email}")
    except Exception as e:
        print("[RESET EMAIL ERROR]", e)

# ---------------- PASSWORD RESET ----------------

@app.route("/requestPasswordReset", methods=["POST"])
def request_password_reset():
    data = request.get_json(silent=True) or {}
    email = (data.get("email") or "").strip()

    if not email:
        return jsonify(success=False, message="Email is required"), 400

    user = User.query.filter_by(email=email).first()

    # real-world behavior: don't reveal if user exists
    if not user:
        return jsonify(success=True, message="If the email exists, a reset link was sent."), 200

    token = secrets.token_urlsafe(32)
    expires_at = datetime.utcnow() + timedelta(minutes=30)

    user.password_reset_token = token
    user.password_reset_expires_at = expires_at
    db.session.commit()

    base_url = os.getenv("PUBLIC_BASE_URL", "http://127.0.0.1:5000")
    reset_link = f"{base_url}/reset-password?token={quote_plus(token)}"

    send_password_reset_email(email, reset_link)

    return jsonify(success=True, message="If the email exists, a reset link was sent."), 200

@app.route("/categories", methods=["GET"])
def list_categories():
    cats = Category.query.order_by(Category.name.asc()).all()
    return jsonify(ok=True, results=[{"id": c.id, "name": c.name} for c in cats])
    
@app.route("/reset-password", methods=["GET"])
def reset_password_page():
    token = (request.args.get("token") or "").strip()
    if not token:
        return "Missing token", 400

    user = User.query.filter_by(password_reset_token=token).first()
    if not user or not user.password_reset_expires_at or datetime.utcnow() > user.password_reset_expires_at:
        return "Invalid or expired reset link", 400

    return f"""
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <title>Reset Password · Linkis</title>
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <style>
    * {{
      box-sizing: border-box;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif;
    }}
    body {{
      background: #f4f6fb;
      margin: 0;
      padding: 0;
    }}
    .container {{
      max-width: 420px;
      margin: 80px auto;
      background: #ffffff;
      border-radius: 14px;
      padding: 28px;
      box-shadow: 0 12px 30px rgba(0,0,0,0.08);
    }}
    .brand {{
      text-align: center;
      margin-bottom: 18px;
    }}
    .brand h1 {{
      margin: 0;
      font-size: 28px;
      color: #2563eb;
      letter-spacing: 0.5px;
    }}
    .brand span {{
      font-size: 13px;
      color: #666;
    }}
    h2 {{
      margin-top: 10px;
      font-size: 20px;
      text-align: center;
      color: #111;
    }}
    .rules {{
      background: #f1f5ff;
      border-radius: 10px;
      padding: 12px 14px;
      font-size: 13px;
      color: #333;
      margin-bottom: 16px;
    }}
    .rules ul {{
      margin: 6px 0 0 18px;
      padding: 0;
    }}
    label {{
      display: block;
      margin-top: 14px;
      font-size: 14px;
      color: #333;
    }}
    input {{
      width: 100%;
      padding: 11px;
      margin-top: 6px;
      border-radius: 10px;
      border: 1px solid #d0d7e2;
      font-size: 14px;
    }}
    input:focus {{
      outline: none;
      border-color: #2563eb;
    }}
    button {{
      width: 100%;
      margin-top: 22px;
      padding: 12px;
      background: #2563eb;
      border: none;
      color: white;
      font-size: 15px;
      border-radius: 12px;
      cursor: pointer;
    }}
    button:hover {{
      background: #1e4fd8;
    }}
    .msg {{
      margin-top: 12px;
      font-size: 14px;
      display: none;
    }}
    .error {{
      color: #b00020;
    }}
    .footer {{
      margin-top: 18px;
      text-align: center;
      font-size: 12px;
      color: #777;
    }}
  </style>
</head>
<body>
  <div class="container">
    <div class="brand">
      <h1>Linkis</h1>
      <span>Save · Share · Discover links</span>
    </div>

    <h2>Reset your password</h2>

    <div class="rules">
      Password must contain:
      <ul>
        <li>At least 8 characters</li>
        <li>One uppercase letter</li>
        <li>One number</li>
      </ul>
    </div>

    <form id="resetForm" method="POST" action="/reset-password" novalidate>
      <input type="hidden" name="token" value="{token}" />

      <label>New password</label>
      <input id="pw" type="password" name="new_password" required />

      <label>Confirm password</label>
      <input id="confirm" type="password" required />

      <div id="msg" class="msg error"></div>

      <button type="submit">Reset password</button>
    </form>

    <div class="footer">
      © {datetime.utcnow().year} Linkis
    </div>
  </div>

  <script>
    const form = document.getElementById('resetForm');
    const pw = document.getElementById('pw');
    const confirm = document.getElementById('confirm');
    const msg = document.getElementById('msg');

    function showError(text) {{
      msg.style.display = 'block';
      msg.textContent = text;
    }}

    function hideError() {{
      msg.style.display = 'none';
      msg.textContent = '';
    }}

    function validPassword(p) {{
      return p.length >= 8 && /[A-Z]/.test(p) && /[0-9]/.test(p);
    }}

    form.addEventListener('submit', (e) => {{
      hideError();
      if (!validPassword(pw.value)) {{
        e.preventDefault();
        showError('Password does not meet security requirements.');
        return;
      }}
      if (pw.value !== confirm.value) {{
        e.preventDefault();
        showError('Passwords do not match.');
      }}
    }});
  </script>
</body>
</html>
"""


def is_strong_password(p: str) -> bool:
    if not p or len(p) < 8:
        return False
    if not any(ch.isupper() for ch in p):
        return False
    if not any(ch.isdigit() for ch in p):
        return False
    return True

@app.route("/reset-password", methods=["POST"])
def reset_password_submit():
    token = (request.form.get("token") or "").strip()
    new_password = (request.form.get("new_password") or "").strip()

    if not token or not new_password:
        return "Missing token or password", 400

    if not is_strong_password(new_password):
        return "Password too weak. Use 8+ chars, 1 uppercase, 1 number.", 400

    user = User.query.filter_by(password_reset_token=token).first()
    if not user or not user.password_reset_expires_at:
        return "Invalid reset link", 400

    if datetime.utcnow() > user.password_reset_expires_at:
        return "Reset link expired", 400

    user.password = new_password
    user.password_reset_token = None
    user.password_reset_expires_at = None
    db.session.commit()

    return """
    <html>
      <head><meta name="viewport" content="width=device-width, initial-scale=1" /></head>
      <body style="font-family: Arial; max-width: 420px; margin: 40px auto;">
        <h2>Password updated</h2>
        <p>You can now go back to the app and log in.</p>
      </body>
    </html>
    """

# ---------------- USER LIKE ----------------
@app.route("/users/<int:user_id>/liked-links", methods=["GET"])
def get_user_likes(user_id):
    try:
        user = db.session.get(User, user_id)
        if not user:
            return jsonify(success=False, message="User not found"), 404
        
        liked_links = LinkLike.query.filter_by(user_id=user_id).all()
        
        liked_link_ids = [link.link_id for link in liked_links]
        
        return jsonify(liked_link_ids), 200
    
    except Exception as e:
        print(f"Error retrieving liked links for user {user_id}: {e}")
        return jsonify(success=False, message="Internal server error"), 500


# ---------------- TOGGLE LIKE ----------------
@app.route("/links/<int:link_id>/toggleLike", methods=["POST"])
def toggle_like(link_id):
    print(f"Request received for link_id: {link_id}")

    data = request.get_json(silent=True) or {}
    print(f"Received data: {data}")

    user_id = data.get("user_id")
    print(f"Extracted user_id: {user_id}")

    if not user_id:
        print("user_id is missing")
        return jsonify(success=False, message="Missing user_id"), 400

    user = db.session.get(User, user_id)
    print(f"Fetched user: {user}")

    if not user:
        print(f"User with id {user_id} not found")
        return jsonify(success=False, message="User not found"), 404

    if not user.is_verified:
        print(f"User with id {user_id} is not verified")
        return jsonify(success=False, message="User is not verified"), 403

    link = Link.query.get(link_id)
    print(f"Fetched link: {link}")

    if not link:
        print(f"Link with id {link_id} not found")
        return jsonify(success=False, message="Link not found"), 404

    try:
        existing = LinkLike.query.filter_by(user_id=user_id, link_id=link_id).first()
        print(f"Existing like: {existing}")

        if existing:
            print(f"Found existing like, deleting it")
            db.session.delete(existing)
            liked = False
        else:
            print(f"No existing like found, adding new like")
            db.session.add(LinkLike(user_id=user_id, link_id=link_id))
            liked = True

        db.session.commit()
        print(f"Database committed successfully")

        likes_count = LinkLike.query.filter_by(link_id=link_id).count()
        print(f"Likes count for link_id {link_id}: {likes_count}")

        return jsonify(success=True, liked=liked, likes_count=likes_count), 200

    except Exception as e:
        print(f"Error toggling like: {e}")
        db.session.rollback()
        return jsonify(success=False, message="Internal server error"), 500


# ---------------- LOGIN ----------------

@app.route("/login", methods=["POST"])
def login():
    data = request.get_json(silent=True) or {}

    email = (data.get("email") or "").strip()
    password = (data.get("password") or "").strip()

    if not email or not password:
        return jsonify({"success": False, "message": "Email and password are required"}), 400

    try:
        user = User.query.filter_by(email=email).first()

        if not user:
            return jsonify({"success": False, "message": "User not found"}), 401

        if user.password != password:
            return jsonify({"success": False, "message": "Incorrect password"}), 401

        if not user.is_verified:
            return jsonify({
                "success": False,
                "message": "Email not verified. Please verify your email first by sign up with the same email and username."
            }), 403

        return jsonify({
            "success": True,
            "message": "Login successful",
            "user_id": user.id,
            "username": user.username,
            "email": user.email,
        }), 200

    except Exception as e:
        print("Error during login:", e)
        return jsonify({"success": False, "message": "Internal server error"}), 500

# ---------------- LINKS ----------------

def get_image_url_or_default(link_url: str) -> str:
    try:
        img_url = get_whatsapp_image_url(link_url)
        img_url = (img_url or "").strip()
        if img_url:
            return img_url
    except Exception:
        pass

    return request.host_url.rstrip("/") + "/assets/default-chat-image"

@app.get("/assets/default-chat-image")
def default_chat_image():
    img_path = Path(__file__).resolve().parent / "assets" / "default_chat_image.png"
    return send_file(img_path, mimetype="image/png")


@app.route("/links", methods=["POST"])
def add_link():
    data = request.get_json(silent=True) or {}

    url = (data.get("url") or "").strip()
    title = (data.get("title") or "").strip()
    description = (data.get("description") or "").strip()
    tags = (data.get("tags") or "").strip()
    user_id = data.get("user_id")

    if not url:
        return jsonify({"error": "Missing 'url'"}), 400

    if not user_id:
        return jsonify({"error": "Missing 'user_id'"}), 400

    user = db.session.get(User, user_id)
    if not user:
        return jsonify({"error": "User not found"}), 404

    if not user.is_verified:
        return jsonify({"error": "User is not verified"}), 403

    if not title:
        title = url

    try:
        image_url = get_image_url_or_default(url)
        
        new_link = Link(
            creator_id=user_id,
            url=url,
            title=title,
            description=description or None,
            tags=tags or None,
            image_url=image_url
        )
        db.session.add(new_link)
        db.session.commit()
        # --- Update Postgres full-text search vector (requires new_link.id) ---
        db.session.execute(
            text("""
                UPDATE links
                SET search_vector =
                    setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
                    setweight(to_tsvector('english', coalesce(tags, '')), 'B') ||
                    setweight(to_tsvector('english', coalesce(description, '')), 'C')
                WHERE id = :id
            """),
            {"id": new_link.id}
        )
        db.session.commit()
        return jsonify({
            "success": True,
            "id": new_link.id,
            "url": new_link.url,
            "title": new_link.title,
            "description": new_link.description,
            "tags": new_link.tags,
            "image_url": new_link.image_url,
            "creator_id": new_link.creator_id,
        }), 201

    except Exception as e:
        print("Error inserting link:", e)
        db.session.rollback()
        return jsonify({"error": "Failed to add link"}), 500

# ---------------- RESEND VERIFICATION CODE ----------------

@app.route("/resendVerificationCode", methods=["POST"])
def resend_verification_code():
    data = request.get_json(silent=True) or {}
    email = (data.get("email") or "").strip()

    if not email:
        return jsonify({"success": False, "message": "Email is required"}), 400

    user = User.query.filter_by(email=email).first()
    if not user:
        return jsonify({"success": False, "message": "User not found"}), 404

    code = generate_verification_code()
    expires_at = datetime.utcnow() + timedelta(minutes=10)

    user.verification_code = code
    user.verification_expires_at = expires_at
    db.session.commit()

    send_verification_email(user.email, code)
    return jsonify({"success": True, "message": "Verification code resent"}), 200

# ---------------- SIGN UP ----------------

@app.route("/signUp", methods=["POST"])
def sign_up():
    data = request.get_json(silent=True) or {}

    username = (data.get("username") or "").strip()
    password = (data.get("password") or "").strip()
    email = (data.get("email") or "").strip()

    if not username or not password or not email:
        return jsonify({"success": False, "message": "Missing fields"}), 400

    try:
        existing_by_email = User.query.filter_by(email=email).first()
        existing_by_username = User.query.filter_by(username=username).first()

        if existing_by_email and existing_by_email.is_verified:
            return jsonify({"success": False, "message": "Email already in use"}), 409

        if existing_by_username and existing_by_username.is_verified:
            return jsonify({"success": False, "message": "Username already in use"}), 409

        if existing_by_email and existing_by_username:
            if existing_by_email.id == existing_by_username.id and not existing_by_email.is_verified:
                user = existing_by_email

                code = generate_verification_code()
                expires_at = datetime.utcnow() + timedelta(minutes=10)

                user.verification_code = code
                user.verification_expires_at = expires_at
                user.password = password
                db.session.commit()

                send_verification_email(user.email, code)

                return jsonify({
                    "success": True,
                    "message": "Account exists but not verified. Sent new verification code.",
                    "user_id": user.id,
                    "is_verified": user.is_verified
                }), 200
            else:
                return jsonify({"success": False, "message": "Username or email already in use"}), 409

        if existing_by_email or existing_by_username:
            return jsonify({"success": False, "message": "Username or email already in use"}), 409

        code = generate_verification_code()
        expires_at = datetime.utcnow() + timedelta(minutes=10)

        new_user = User(
            username=username,
            email=email,
            password=password,
            is_verified=False,
            verification_code=code,
            verification_expires_at=expires_at
        )

        db.session.add(new_user)
        db.session.commit()

        send_verification_email(email, code)

        return jsonify({
            "success": True,
            "message": "User created successfully. Verification code sent.",
            "user_id": new_user.id,
            "is_verified": new_user.is_verified
        }), 200

    except Exception as e:
        print("Error during sign-up:", e)
        db.session.rollback()
        return jsonify({"success": False, "message": "Internal server error"}), 500

# ---------------- SEARCH ----------------

class QueryRequest(BaseModel):
    q: str
    k: int = 5
    n: int = 50

# ---------------- Helper Functions ----------------
from rank_bm25 import BM25Okapi
def bm25_retriever(query: str, top_n: int = 50): # 'for futhere usege
    # Split query into tokens
    query_tokens = query.lower().split()

    # Query the database
    session = db.session
    links = session.query(Link).all()   # Retrieve all links from the database
    print(f"Retrieved {len(links)} links from the database.")
    
    # Tokenize the titles of all links
    documents = []
    for link in links:
        title_tokens = link.title.lower().split()  # Tokenize only the title
        documents.append(title_tokens)

    # Create BM25 model
    bm25 = BM25Okapi(documents)

    # Calculate scores for all documents
    scores = bm25.get_scores(query_tokens)

    # Prepare the results
    results = []
    for i, link in enumerate(links):
        results.append({
            "id": link.id,
            "title": link.title,
            "description": link.description,
            "score": scores[i]
        })

    # Sort results by score (highest to lowest)
    results = sorted(results, key=lambda x: x['score'], reverse=True)[:top_n]
    print(f"Top {top_n} results based on BM25 scores: {results}")

    return results

def rerank_with_cohere(query: str, documents: List[dict], model="rerank-v3.5"):
    if not documents:
        print("No documents to rerank.")
        return []

    texts = [f"{doc['title']}" for doc in documents] 

    print(f"[COHERE] Sending {len(texts)} documents to rerank...")
    response = co.rerank(model=model, query=query, documents=texts)
    print("[COHERE] Raw response:", response)

    reranked_results = []

    for item in response.results:
        original_doc = documents[item.index]
        reranked_results.append({
            "id": str(original_doc["id"]), 
            "title": original_doc["title"],
            "score": float(item.relevance_score),
        })

    print("[COHERE] Reranked results (top 10):", reranked_results[:10])
    return reranked_results

@app.route("/search", methods=["GET"])
def search():
    query = request.args.get("query", "")
    top_n = int(request.args.get("k", 5))
    n = int(request.args.get("n", 50))

    try:
        query_request = QueryRequest(q=query, k=top_n, n=n)
    except ValidationError as e:
        print(f"Validation error: {str(e)}")
        return jsonify({"error": str(e)}), 400

    # Step 1: Retrieve all the links from the database (only title for Cohere)
    session = db.session
    links = session.query(Link).all()  # Retrieve all links from the database

    # Prepare documents with only the essential fields (id, title) for BM25 and Cohere
    documents = [{
        "id": link.id,
        "title": link.title or "",
    } for link in links]

    if not documents:
        return jsonify({"error": "No links in database"}), 400

    reranked_results = rerank_with_cohere(query_request.q, documents, model="rerank-v3.5")

    # Step 2: Now that we have the ranked documents, we need to fetch the full data from DB
    reranked_ids = [result["id"] for result in reranked_results]  # Extract the ids of the reranked documents


    full_links = session.query(Link).filter(Link.id.in_(reranked_ids)).all()

    final_results = []


    full_links = session.query(Link).all()  # Make sure you fetch all the links from the database
   
    for result in reranked_results:

        link = next((link for link in full_links if str(link.id) == str(result["id"])), None)

        if link:
            
            creator_username = session.query(User).filter_by(id=link.creator_id).first().username if link.creator_id else "unknown"
            
            final_results.append({
                "id": str(link.id),
                "title": link.title,
                "description": link.description,
                "url": link.url,
                "tags": link.tags or "",  # if tags exists
                "creator_username": creator_username,
                "created_at": link.created_at.strftime("%Y-%m-%d %H:%M:%S"),
                "likes_count": len(session.query(LinkLike).filter_by(link_id=link.id).all()) or 0,  # Add likes_count from the DB
                "image_url": link.image_url,
                "score": result["score"],  # From Cohere rerank
            })
            
        else:
            print(f"No link found for ID {result['id']}")  

    print(f"Total final results: {final_results}")

    return json.dumps(final_results, ensure_ascii=False)

# ---------------- VERIFY EMAIL ----------------

@app.route("/verify", methods=["POST"])
def verify():
    data = request.get_json(silent=True) or {}

    email = (data.get("email") or "").strip()
    code = (data.get("code") or "").strip()

    if not email or not code:
        return jsonify({"success": False, "message": "Email and code are required"}), 400

    try:
        user = User.query.filter_by(email=email).first()

        if not user:
            return jsonify({"success": False, "message": "User not found"}), 404

        if user.is_verified:
            return jsonify({"success": True, "message": "Email already verified"}), 200

        if not user.verification_code or not user.verification_expires_at:
            return jsonify({"success": False, "message": "No verification code set for this user"}), 400

        if datetime.utcnow() > user.verification_expires_at:
            return jsonify({"success": False, "message": "Verification code has expired"}), 400

        if code != user.verification_code:
            return jsonify({"success": False, "message": "Invalid verification code"}), 400

        user.is_verified = True
        user.verification_code = None
        user.verification_expires_at = None
        db.session.commit()

        return jsonify({"success": True, "message": "Email verified successfully"}), 200

    except Exception as e:
        print("Error during email verification:", e)
        db.session.rollback()
        return jsonify({"success": False, "message": "Internal server error"}), 500

# ---------------- MY LINKS (USER MANAGEMENT) ----------------

@app.route("/my-links", methods=["GET"])
def my_links():
    user_id = request.args.get("user_id", type=int)
    if not user_id:
        return jsonify(ok=False, message="Missing user_id"), 400

    user = db.session.get(User, user_id)
    if not user:
        return jsonify(ok=False, message="User not found"), 404

    # optional: require verified to manage
    if not user.is_verified:
        return jsonify(ok=False, message="User is not verified"), 403

    links = (
        Link.query
        .filter_by(creator_id=user_id)
        .order_by(Link.created_at.desc())
        .all()
    )

    # likes count (optional, like you do in search)
    link_ids = [l.id for l in links]
    like_counts = {}
    if link_ids:
        like_counts = dict(
            db.session.query(LinkLike.link_id, func.count(LinkLike.id))
            .filter(LinkLike.link_id.in_(link_ids))
            .group_by(LinkLike.link_id)
            .all()
        )

    results = []
    for link in links:
        results.append({
            "id": link.id,
            "url": link.url,
            "title": link.title,
            "description": link.description,
            "tags": link.tags,
            "created_at": link.created_at.isoformat(),
            "creator_id": link.creator_id,
            "image_url": link.image_url,
            "likes_count": int(like_counts.get(link.id, 0)),
        })

    return jsonify(ok=True, results=results)


@app.route("/links/<int:link_id>", methods=["PUT"])
def update_link(link_id):
    data = request.get_json(silent=True) or {}
    user_id = data.get("user_id")

    if not user_id:
        return jsonify(ok=False, message="Missing user_id"), 400

    user = db.session.get(User, user_id)
    if not user:
        return jsonify(ok=False, message="User not found"), 404
    if not user.is_verified:
        return jsonify(ok=False, message="User is not verified"), 403

    link = Link.query.get(link_id)
    if not link:
        return jsonify(ok=False, message="Link not found"), 404

    # security: only owner can edit
    if link.creator_id != user_id:
        return jsonify(ok=False, message="Not allowed"), 403

    # allow updating fields
    title = (data.get("title") or "").strip()
    url = (data.get("url") or "").strip()
    description = (data.get("description") or "").strip()
    tags = (data.get("tags") or "").strip()

    if url:
        link.url = url
    if title:
        link.title = title

    link.description = description or None
    link.tags = tags or None

    db.session.commit()

    # update FTS vector too (like in add_link)
    db.session.execute(
        text("""
            UPDATE links
            SET search_vector =
                setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
                setweight(to_tsvector('english', coalesce(tags, '')), 'B') ||
                setweight(to_tsvector('english', coalesce(description, '')), 'C')
            WHERE id = :id
        """),
        {"id": link.id}
    )
    db.session.commit()

    return jsonify(ok=True, message="Updated")


@app.route("/links/<int:link_id>", methods=["DELETE"])
def delete_link(link_id):
    user_id = request.args.get("user_id", type=int)
    if not user_id:
        return jsonify(ok=False, message="Missing user_id"), 400

    user = db.session.get(User, user_id)
    if not user:
        return jsonify(ok=False, message="User not found"), 404
    if not user.is_verified:
        return jsonify(ok=False, message="User is not verified"), 403

    link = Link.query.get(link_id)
    if not link:
        return jsonify(ok=False, message="Link not found"), 404

    # security: only owner can delete
    if link.creator_id != user_id:
        return jsonify(ok=False, message="Not allowed"), 403

    # delete likes first to avoid FK issues (depends on your FK settings)
    LinkLike.query.filter_by(link_id=link_id).delete()

    db.session.delete(link)
    db.session.commit()

    return jsonify(ok=True, message="Deleted")

if __name__ == "__main__":
    sync_db(app, db)
    app.run(host="0.0.0.0", port=5000, debug=True)