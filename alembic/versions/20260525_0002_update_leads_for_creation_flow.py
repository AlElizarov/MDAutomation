"""update leads for creation flow

Revision ID: 20260525_0002
Revises: 20260525_0001
Create Date: 2026-05-25
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op


revision: str = "20260525_0002"
down_revision: str | None = "20260525_0001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "leads",
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.alter_column(
        "leads",
        "phone",
        existing_type=sa.String(length=64),
        type_=sa.String(length=32),
        existing_nullable=False,
    )
    op.alter_column(
        "leads",
        "status",
        existing_type=sa.String(length=64),
        server_default="created",
        existing_nullable=False,
    )


def downgrade() -> None:
    op.alter_column(
        "leads",
        "status",
        existing_type=sa.String(length=64),
        server_default=None,
        existing_nullable=False,
    )
    op.alter_column(
        "leads",
        "phone",
        existing_type=sa.String(length=32),
        type_=sa.String(length=64),
        existing_nullable=False,
    )
    op.drop_column("leads", "updated_at")
