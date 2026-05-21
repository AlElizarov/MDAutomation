from fastapi import FastAPI


app = FastAPI(
    title="MDAutomation API",
    description="Backend API for the MDAutomation project.",
    version="0.1.0",
)


@app.get("/health", tags=["health"])
def health() -> dict[str, str]:
    return {"status": "ok"}
