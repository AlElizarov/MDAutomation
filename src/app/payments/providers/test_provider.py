from app.payments.providers.base import ProviderPayment


class TestPaymentProviderAdapter:
    provider = "test"

    def create_payment(self, *, payment_id: str, amount: int, currency: str) -> ProviderPayment:
        provider_payment_id = f"test_pay_{payment_id.replace('-', '')}"

        return ProviderPayment(
            provider_payment_id=provider_payment_id,
            payment_url=f"https://test-payment-provider/pay/{provider_payment_id}",
        )
