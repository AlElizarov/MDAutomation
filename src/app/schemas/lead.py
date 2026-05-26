from enum import StrEnum

from pydantic import BaseModel, Field, field_validator


class PreferredContactChannel(StrEnum):
    telegram = "telegram"
    vk = "vk"
    max = "max"


class LeadCreate(BaseModel):
    name: str = Field(..., max_length=255)
    phone: str = Field(..., max_length=32)
    preferred_contact_channel: PreferredContactChannel

    @field_validator("name")
    @classmethod
    def validate_name(cls, value: str) -> str:
        normalized_value = value.strip()

        if not normalized_value:
            raise ValueError("name must not be empty")

        return normalized_value

    @field_validator("phone")
    @classmethod
    def validate_phone(cls, value: str) -> str:
        normalized_value = value.strip()

        if not normalized_value.startswith("+"):
            raise ValueError("phone must start with +")

        if not normalized_value[1:].isdigit():
            raise ValueError("phone must contain only digits after +")

        return normalized_value


class LeadCreateResponse(BaseModel):
    lead_id: str
    status: str
