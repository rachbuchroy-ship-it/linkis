from datetime import datetime
from sqlalchemy.dialects.postgresql import TSVECTOR

from database import db


class User(db.Model):
    __tablename__ = "users"

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    username = db.Column(db.String(255), unique=True, nullable=False)
    email = db.Column(db.String(255), unique=True, nullable=False)

    password = db.Column(db.String(255), nullable=False)

    password_reset_token = db.Column(db.String(128), nullable=True)
    password_reset_expires_at = db.Column(db.DateTime, nullable=True)

    is_verified = db.Column(db.Boolean, default=False, nullable=False)
    verification_code = db.Column(db.String(10), nullable=True)
    verification_expires_at = db.Column(db.DateTime, nullable=True)

    links = db.relationship("Link", backref="user", lazy=True)


link_categories = db.Table(
    "link_categories",
    db.Column("link_id", db.Integer, db.ForeignKey("links.id"), primary_key=True),
    db.Column("category_id", db.Integer, db.ForeignKey("categories.id"), primary_key=True),
)


class Category(db.Model):
    __tablename__ = "categories"

    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(80), unique=True, nullable=False)


class Link(db.Model):
    __tablename__ = "links"

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    creator_id = db.Column("user_id", db.Integer, db.ForeignKey("users.id"), nullable=False)

    url = db.Column(db.String(1024), nullable=False)
    title = db.Column(db.String(255), nullable=False)
    description = db.Column(db.Text, nullable=True)
    tags = db.Column(db.Text, nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow, nullable=False)
    image_url = db.Column(db.String(2048), nullable=True)

    platform = db.Column(db.String(32), nullable=False, default="unknown", index=True)

    search_vector = db.Column(TSVECTOR)

    categories = db.relationship(
        "Category",
        secondary=link_categories,
        lazy="subquery",
    )


class LinkLike(db.Model):
    __tablename__ = "link_likes"

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False)
    link_id = db.Column(db.Integer, db.ForeignKey("links.id"), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow, nullable=False)

    __table_args__ = (
        db.UniqueConstraint("user_id", "link_id", name="uq_user_link_like"),
    )
