from fastapi import FastAPI
from fastapi.responses import JSONResponse

from app.database import check_database_connection


app = FastAPI(
    title="MDAutomation API",
    description="Backend API for the MDAutomation project.",
    version="0.1.0",
)


@app.get("/health", tags=["health"])
def health():
    if check_database_connection():
        return {"status": "ok", "database": "connected"}

    return JSONResponse(
        status_code=503,
        content={"status": "degraded", "database": "unavailable"},
    )
