from fastapi import FastAPI

from app.api import health, leads, payments_webhooks


app = FastAPI(
    title="MDAutomation API",
    description="Backend API for the MDAutomation project.",
    version="0.1.0",
)


app.include_router(health.router)
app.include_router(leads.router)
app.include_router(payments_webhooks.router)
