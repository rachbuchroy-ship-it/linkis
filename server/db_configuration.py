from __future__ import annotations

from sqlalchemy import inspect, text
from sqlalchemy.sql.sqltypes import (
    String, Text, Integer, BigInteger, SmallInteger,
    Boolean, DateTime, Float, Numeric, LargeBinary
)
from datetime import datetime


def _default_for_column(col) -> tuple[str, object]:
    """
    Returns (sql_default_fragment, python_value_for_update)
    sql_default_fragment: something you can place after DEFAULT in SQL
    python_value_for_update: value to UPDATE existing rows
    """

    t = col.type

    # Strings / Text
    if isinstance(t, (String, Text)):
        return "''", ""

    # Integers
    if isinstance(t, (Integer, BigInteger, SmallInteger)):
        return "0", 0

    # Boolean
    if isinstance(t, Boolean):
        return "FALSE", False

    # Floats / Numeric
    if isinstance(t, (Float, Numeric)):
        return "0", 0

    # DateTime
    if isinstance(t, DateTime):
        # pick NOW() as default; for existing rows we can set current time
        return "NOW()", datetime.utcnow()

    # LargeBinary (images, etc.)
    if isinstance(t, LargeBinary):
        # placeholder empty bytes by default (can be changed later)
        # In SQL: E'\\x' is empty bytea in Postgres
        return "E'\\\\x'::bytea", b""

    # Fallback: NULL (but then we won't autofill)
    return "NULL", None


def _quote_identifier(name: str) -> str:
    # Basic quoting to avoid issues with reserved words / casing.
    return '"' + name.replace('"', '""') + '"'


def sync_db(app, db) -> None:
    """
    ✅ Single function to import.
    - Creates missing tables
    - Adds missing columns based on db.metadata
    - For each newly added column:
        - Adds DEFAULT (based on type)
        - Updates existing rows where column IS NULL
    """

    with app.app_context():
        print("[DB] Auto-sync schema with defaults...")

        # 1) Create missing tables
        db.create_all()

        inspector = inspect(db.engine)

        for table_name, table in db.metadata.tables.items():
            if not inspector.has_table(table_name):
                # If it was missing, create_all created it already with all cols
                continue

            existing_cols = {c["name"] for c in inspector.get_columns(table_name)}

            for col in table.columns:
                if col.name in existing_cols:
                    continue  # already exists

                # Decide default based on type
                sql_default, update_value = _default_for_column(col)

                if update_value is None:
                    # If we can't safely choose a default, skip
                    print(f"[SKIP] {table_name}.{col.name} (no safe default)")
                    continue

                q_table = _quote_identifier(table_name)
                q_col = _quote_identifier(col.name)

                # 2) ALTER TABLE ADD COLUMN ... (nullable first)
                coltype_sql = col.type.compile(dialect=db.engine.dialect)
                add_sql = f"ALTER TABLE {q_table} ADD COLUMN {q_col} {coltype_sql};"
                db.session.execute(text(add_sql))

                # 3) Set DEFAULT for future inserts
                def_sql = f"ALTER TABLE {q_table} ALTER COLUMN {q_col} SET DEFAULT {sql_default};"
                db.session.execute(text(def_sql))

                # 4) Backfill existing rows (only where NULL)
                upd_sql = text(f"UPDATE {q_table} SET {q_col} = :v WHERE {q_col} IS NULL;")
                db.session.execute(upd_sql, {"v": update_value})

                print(f"[DB] Added + defaulted + backfilled: {table_name}.{col.name}")

        db.session.commit()
        print("[DB] Schema sync done.")
