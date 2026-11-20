"""Run the existing sibling API against disposable mobile-test data only.

No backend source, real database, SMTP mailbox, or account is modified.
Run with the backend virtual environment's Python, then use the opt-in Dart test.
"""

import argparse
import os
from pathlib import Path
import secrets
import sys
from tempfile import TemporaryDirectory


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--backend", type=Path, default=Path(__file__).resolve().parents[2] / "biletflow")
    parser.add_argument("--port", type=int, default=18001)
    args = parser.parse_args()
    sys.dont_write_bytecode = True
    sys.path.insert(0, str(args.backend.resolve()))
    with TemporaryDirectory(prefix="biletflow-mobile-contract-") as temporary:
        os.environ.update(
            APP_DATABASE_URL=f"sqlite:///{temporary}/contract.sqlite",
            APP_ENV="test",
            APP_SECRET_KEY=secrets.token_urlsafe(48),
            EMAIL_BACKEND="memory",
        )
        from app.main import app
        from app.core.database import SessionLocal
        from app.core.security import hash_password
        from app.users.models import User
        import uvicorn

        with SessionLocal() as db:
            for role, name in [("platform_admin", "admin"), ("organizer", "organizer"), ("event_admin", "staff")]:
                db.add(User(email=f"mobile.qa.{name}@example.com", full_name=f"Mobile QA {name}",
                            password_hash=hash_password("MobileQa123!"), roles=[role],
                            email_verified=True, is_active=True))
            db.commit()
        print(f"Disposable mobile contract fixture on http://127.0.0.1:{args.port}", flush=True)
        uvicorn.run(app, host="127.0.0.1", port=args.port, log_level="warning", access_log=False)


if __name__ == "__main__":
    main()
