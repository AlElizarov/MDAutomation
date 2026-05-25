from fastapi import APIRouter
from fastapi.responses import JSONResponse

from app.db.session import check_database_connection


router = APIRouter(tags=["health"])


@router.get("/health")
def health():
    if check_database_connection():
        return {"status": "ok", "database": "connected"}

    return JSONResponse(
        status_code=503,
        content={"status": "degraded", "database": "unavailable"},
    )
