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

app = Flask(__name__)
CORS(app)

# ---------------- DB CONFIG ----------------
app.config["SQLALCHEMY_DATABASE_URI"] = os.getenv(
    "DATABASE_URL",
    "postgresql://postgres:sfhr1357@localhost:5432/linkis_db"
)
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

db = SQLAlchemy(app)

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

# ---------------- MODELS ----------------

class User(db.Model):
    __tablename__ = "users"

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    username = db.Column(db.String(255), unique=True, nullable=False)
    email = db.Column(db.String(255), unique=True, nullable=False)

    # plain text for now (as you requested). Still validate + reset tokens.
    password = db.Column(db.String(255), nullable=False)

    # reset mechanism
    password_reset_token = db.Column(db.String(128), nullable=True)
    password_reset_expires_at = db.Column(db.DateTime, nullable=True)

    is_verified = db.Column(db.Boolean, default=False, nullable=False)
    verification_code = db.Column(db.String(10), nullable=True)
    verification_expires_at = db.Column(db.DateTime, nullable=True)

    links = db.relationship("Link", backref="user", lazy=True)


class Link(db.Model):
    __tablename__ = "links"

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    creator_id = db.Column(
        "user_id",
        db.Integer,
        db.ForeignKey("users.id"),
        nullable=False
    )

    url = db.Column(db.String(1024), nullable=False)
    title = db.Column(db.String(255), nullable=False)
    description = db.Column(db.Text, nullable=True)
    tags = db.Column(db.Text, nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow, nullable=False)

    search_vector = db.Column(TSVECTOR)

def is_strong_password(p: str) -> bool:
    if not p or len(p) < 8:
        return False
    if not any(ch.isupper() for ch in p):
        return False
    if not any(ch.isdigit() for ch in p):
        return False
    return True
class LinkLike(db.Model):
    __tablename__ = "link_likes"

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False)
    link_id = db.Column(db.Integer, db.ForeignKey("links.id"), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow, nullable=False)

    __table_args__ = (
        db.UniqueConstraint("user_id", "link_id", name="uq_user_link_like"),
    )


def init_db():
    with app.app_context():
        db.create_all()

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

    base_url = os.getenv("PUBLIC_BASE_URL", "http://44.222.98.94:5000")
    reset_link = f"{base_url}/reset-password?token={quote_plus(token)}"

    send_password_reset_email(email, reset_link)

    return jsonify(success=True, message="If the email exists, a reset link was sent."), 200


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

# ---------------- TOGGLE LIKE ----------------

@app.route("/links/<int:link_id>/toggleLike", methods=["POST"])
def toggle_like(link_id):
    data = request.get_json(silent=True) or {}
    user_id = data.get("user_id")

    if not user_id:
        return jsonify(success=False, message="Missing user_id"), 400

    user = User.query.get(user_id)
    if not user:
        return jsonify(success=False, message="User not found"), 404

    if not user.is_verified:
        return jsonify(success=False, message="User is not verified"), 403

    link = Link.query.get(link_id)
    if not link:
        return jsonify(success=False, message="Link not found"), 404

    try:
        existing = LinkLike.query.filter_by(user_id=user_id, link_id=link_id).first()

        if existing:
            db.session.delete(existing)
            liked = False
        else:
            db.session.add(LinkLike(user_id=user_id, link_id=link_id))
            liked = True

        db.session.commit()

        likes_count = LinkLike.query.filter_by(link_id=link_id).count()

        return jsonify(success=True, liked=liked, likes_count=likes_count), 200

    except Exception as e:
        print("Error toggling like:", e)
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

    user = User.query.get(user_id)
    if not user:
        return jsonify({"error": "User not found"}), 404

    if not user.is_verified:
        return jsonify({"error": "User is not verified"}), 403

    if not title:
        title = url

    try:
        new_link = Link(
            creator_id=user_id,
            url=url,
            title=title,
            description=description or None,
            tags=tags or None,
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

@app.route("/search", methods=["GET"])
def search():
    query = (request.args.get("query") or "").strip()
    viewer_user_id = request.args.get("user_id", type=int)

    if not query:
        return jsonify(ok=True, results=[])

    ts_query = func.plainto_tsquery("english", query)

    results = (
        db.session.query(
            Link,
            func.ts_rank(Link.search_vector, ts_query).label("rank")
        )
        .filter(Link.search_vector.op("@@")(ts_query))
        .order_by(func.ts_rank(Link.search_vector, ts_query).desc())
        .limit(50)
        .all()
    )

    link_ids = [l.id for l, _ in results]

    like_counts = dict(
        db.session.query(LinkLike.link_id, func.count(LinkLike.id))
        .filter(LinkLike.link_id.in_(link_ids))
        .group_by(LinkLike.link_id)
        .all()
    )

    liked_set = set()
    if viewer_user_id:
        liked_set = {
            x[0] for x in
            db.session.query(LinkLike.link_id)
            .filter(
                LinkLike.user_id == viewer_user_id,
                LinkLike.link_id.in_(link_ids)
            )
            .all()
        }

    output = []
    for link, rank in results:
        output.append({
            "id": link.id,
            "url": link.url,
            "title": link.title,
            "description": link.description,
            "tags": link.tags,
            "created_at": link.created_at.isoformat(),
            "creator_id": link.creator_id,
            "creator_username": link.user.username,
            "likes_count": int(like_counts.get(link.id, 0)),
            "liked_by_me": link.id in liked_set,
            "rank": float(rank)
        })

    return jsonify(ok=True, results=output)

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


if __name__ == "__main__":
    init_db()
    app.run(host="0.0.0.0", port=5000, debug=True)
