from flask import Flask, jsonify, request
from flask_cors import CORS
from flask_sqlalchemy import SQLAlchemy
from datetime import datetime, timedelta
import os
import random
import smtplib
from email.mime.text import MIMEText

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
GMAIL_APP_PASSWORD = "fhaq lcdq jiri ivcd"  # better to use env var in real app

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

# ---------------- MODELS ----------------

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

    # NOTE: 'user_id' is the actual column name in the DB
    # but in Python you access it as link.creator_id
    creator_id = db.Column(
        'user_id',                 # <--- DB column name
        db.Integer,
        db.ForeignKey("users.id"),
        nullable=False
    )

    url = db.Column(db.String(1024), nullable=False)
    title = db.Column(db.String(255), nullable=False)
    description = db.Column(db.Text, nullable=True)
    tags = db.Column(db.Text, nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)


def init_db():
    with app.app_context():
        db.create_all()

# ---------------- LOGIN ----------------

@app.route("/login", methods=["POST"])
def login():
    data = request.get_json(silent=True) or {}

    email = (data.get("email") or "").strip()
    password = (data.get("password") or "").strip()

    if not email or not password:
        return jsonify({
            "success": False,
            "message": "Email and password are required"
        }), 400

    try:
        user = User.query.filter_by(email=email).first()

        if not user:
            return jsonify({
                "success": False,
                "message": "User not found"
            }), 401

        if user.password != password:
            return jsonify({
                "success": False,
                "message": "Incorrect password"
            }), 401

        if not user.is_verified:
            return jsonify({
                "success": False,
                "message": "Email not verified. Please verify your email first."
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
        return jsonify({
            "success": False,
            "message": "Internal server error"
        }), 500

# ---------------- LINKS ----------------

@app.route("/links", methods=["GET"])
def get_links():
    links = Link.query.order_by(Link.created_at.desc()).all()
    # For now just return titles (you can expand later)
    titles = [link.title for link in links]
    return jsonify(titles), 200


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

    # Optional: only verified users can add links
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

    existing_by_email = User.query.filter_by(email=email).first()
    if not existing_by_email:
        return jsonify({"success": False, "message": "User not found"}), 404

    code = generate_verification_code()
    expires_at = datetime.utcnow() + timedelta(minutes=10)

    existing_by_email.verification_code = code
    existing_by_email.verification_expires_at = expires_at
    db.session.commit()

    send_verification_email(existing_by_email.email, code)
    return jsonify({
        "success": True,
        "message": "Verification code resent"
    }), 200

# ---------------- SIGN UP ----------------

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
        existing_by_email = User.query.filter_by(email=email).first()
        existing_by_username = User.query.filter_by(username=username).first()

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
                return jsonify({
                    "success": False,
                    "message": "Username or email already in use"
                }), 409

        if existing_by_email or existing_by_username:
            return jsonify({
                "success": False,
                "message": "Username or email already in use"
            }), 409

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
        return jsonify({
            "success": False,
            "message": "Internal server error"
        }), 500

# ---------------- VERIFY EMAIL ----------------

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