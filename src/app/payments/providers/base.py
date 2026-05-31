from dataclasses import dataclass
from typing import Protocol


@dataclass(frozen=True)
class ProviderPayment:
    provider_payment_id: str
    payment_url: str


class PaymentProviderAdapter(Protocol):
    provider: str

    def create_payment(self, *, payment_id: str, amount: int, currency: str) -> ProviderPayment:
        pass
