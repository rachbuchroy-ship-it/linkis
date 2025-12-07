from flask import Flask, jsonify, request
from flask_cors import CORS
from flask_sqlalchemy import SQLAlchemy
from datetime import datetime
import os
import random
from datetime import datetime, timedelta
import smtplib
from email.mime.text import MIMEText

app = Flask(__name__)
CORS(app)

# ---------------- DB CONFIG ----------------
# Use DATABASE_URL from environment if exists; fallback to local PostgreSQL
app.config["SQLALCHEMY_DATABASE_URI"] = os.getenv(
    "DATABASE_URL",
    "postgresql://postgres:sfhr1357@localhost:5432/linkis_db"
)

app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

db = SQLAlchemy(app)


# ---------------- MODELS ----------------

def generate_verification_code() -> str:
    return f"{random.randint(100000, 999999)}"

GMAIL_ADDRESS = "rachbuchroy@gmail.com"
GMAIL_APP_PASSWORD = "yxpe rtuh nanq ugrf"

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
class User(db.Model):
    __tablename__ = "users"

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    username = db.Column(db.String(255), unique=True, nullable=False)
    email = db.Column(db.String(255), unique=True, nullable=False)
    password = db.Column(db.String(255), nullable=False)

    is_verified = db.Column(db.Boolean, default=False, nullable=False)
    verification_code = db.Column(db.String(10), nullable=True)
    verification_expires_at = db.Column(db.DateTime, nullable=True)

    links = db.relationship("Link", backref="user", lazy=True)


class Link(db.Model):
    __tablename__ = "links"

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False)
    url = db.Column(db.String(1024), nullable=False)
    title = db.Column(db.String(255), nullable=False)
    description = db.Column(db.Text, nullable=True)
    tags = db.Column(db.Text, nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)


def init_db():
    with app.app_context():
        db.create_all()


# ---------------- ROUTES ----------------

# קובץ server.py
# ...
@app.route("/links", methods=["GET"])
def get_links():
    query_text = request.args.get('q', default='', type=str).strip()
    user_id = 1 # **שים לב: כרגע אנחנו מניחים user_id=1 לצורך בדיקה!** # בהמשך, צריך להשיג את user_id מטוקן אימות.

    links_query = db.session.query(Link)
    
    # 1. סינון לפי משתמש (חובה!)
    links_query = links_query.filter(Link.user_id == user_id)

    if query_text:
        # 2. הוספת לוגיקת דירוג
        
        # דירוג 1: התאמה מדויקת לכותרת (ציון גבוה)
        # דירוג 2: התאמה חלקית לכותרת או תגיות (ציון בינוני)
        # דירוג 3: התאמה לתיאור (ציון נמוך)
        
        search_pattern = f"%{query_text}%"
        
        rank_score = db.case(
            (Link.title.ilike(query_text), 3),
            (Link.title.ilike(search_pattern), 2),
            (Link.tags.ilike(search_pattern), 2),
            (Link.description.ilike(search_pattern), 1),
            else_=0
        ).label('rank_score')

        # סנן רק פריטים עם ציון רלוונטיות כלשהו
        links_query = links_query.add_columns(rank_score).filter(rank_score > 0)

        # 3. מיון: לפי הדירוג שיצרנו (rank_score) ולפי העדכניות (created_at)
        links_query = links_query.order_by(
            db.desc(rank_score),
            db.desc(Link.created_at)
        )

    links_results = links_query.all()
    
    # 4. המרת התוצאות לפורמט מלא יותר (נדרש כדי לשלוף את ה-url)
    results = []
    for link_tuple in links_results:
        # אם יש rank_score, הוא נמצא באינדקס האחרון
        link = link_tuple[0] if isinstance(link_tuple, tuple) else link_tuple
        
        results.append({
            "id": link.id,
            "url": link.url, # זה הלינק לקבוצת ווצאפ
            "title": link.title,
            "description": link.description,
            "tags": link.tags,
            "created_at": link.created_at.isoformat() 
        })
        
    return jsonify(results), 200

# ...

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

    if not title:
        title = url

    try:
        new_link = Link(
            user_id=user_id,
            url=url,
            title=title,
            description=description or None,
            tags=tags or None,
        )
        db.session.add(new_link)
        db.session.commit()

        return jsonify({
            "ok": True,
            "id": new_link.id,
            "url": new_link.url,
            "title": new_link.title,
            "description": new_link.description,
            "tags": new_link.tags,
            "user_id": new_link.user_id,
        }), 201

    except Exception as e:
        print("Error inserting link:", e)
        db.session.rollback()
        return jsonify({"error": "Failed to add link"}), 500


@app.route("/signUp", methods=["POST"])
def sign_up():
    data = request.get_json(silent=True) or {}

    username = (data.get("username") or "").strip()
    password = (data.get("password") or "").strip()
    email = (data.get("email") or "").strip()

    if not username or not password or not email:
        return jsonify({
            "success": False,
            "message": "Missing fields"
        }), 400

    try:
        # Find any existing users by email / username
        existing_by_email = User.query.filter_by(email=email).first()
        existing_by_username = User.query.filter_by(username=username).first()

        # ---- CASE A: email or username used by a VERIFIED user → block ----
        if existing_by_email and existing_by_email.is_verified:
            return jsonify({
                "success": False,
                "message": "Email already in use"
            }), 409

        if existing_by_username and existing_by_username.is_verified:
            return jsonify({
                "success": False,
                "message": "Username already in use"
            }), 409

        # ---- CASE B: username + email match SAME UNVERIFIED user → resend code ----
        if existing_by_email and existing_by_username:
            if existing_by_email.id == existing_by_username.id and not existing_by_email.is_verified:
                user = existing_by_email  # same unverified user

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
                # username and email belong to different users → block
                return jsonify({
                    "success": False,
                    "message": "Username or email already in use"
                }), 409

        # ---- CASE C: only one matches (email OR username), even if unverified → block ----
        if existing_by_email or existing_by_username:
            return jsonify({
                "success": False,
                "message": "Username or email already in use"
            }), 409

        # ---- CASE D: no user exists → create new user + send code ----
        code = generate_verification_code()
        expires_at = datetime.utcnow() + timedelta(minutes=10)

        # TODO: hash the password in a real app
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
        return jsonify({
            "success": False,
            "message": "Internal server error"
        }), 500


@app.route("/verify", methods=["POST"])
def verify():
    data = request.get_json(silent=True) or {}

    email = (data.get("email") or "").strip()
    code = (data.get("code") or "").strip()

    if not email or not code:
        return jsonify({
            "success": False,
            "message": "Email and code are required"
        }), 400

    try:
        user = User.query.filter_by(email=email).first()

        if not user:
            return jsonify({
                "success": False,
                "message": "User not found"
            }), 404

        if user.is_verified:
            # Already verified – treat as success
            return jsonify({
                "success": True,
                "message": "Email already verified"
            }), 200

        if not user.verification_code or not user.verification_expires_at:
            return jsonify({
                "success": False,
                "message": "No verification code set for this user"
            }), 400

        now = datetime.utcnow()
        if now > user.verification_expires_at:
            return jsonify({
                "success": False,
                "message": "Verification code has expired"
            }), 400

        if code != user.verification_code:
            return jsonify({
                "success": False,
                "message": "Invalid verification code"
            }), 400

        # Success: mark as verified
        user.is_verified = True
        user.verification_code = None
        user.verification_expires_at = None
        db.session.commit()

        return jsonify({
            "success": True,
            "message": "Email verified successfully"
        }), 200

    except Exception as e:
        print("Error during email verification:", e)
        db.session.rollback()
        return jsonify({
            "success": False,
            "message": "Internal server error"
        }), 500

if __name__ == "__main__":
    init_db()
    app.run(host="0.0.0.0", port=5000, debug=True)