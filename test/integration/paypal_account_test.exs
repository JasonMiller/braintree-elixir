defmodule Braintree.Integration.PaypalAccountTest do
  use ExUnit.Case, async: true

  alias Braintree.{Customer, PaymentMethod, PaypalAccount}
  alias Braintree.Testing.Nonces

  @moduletag :integration

  test "find/1 can successfully find a paypal account" do
    {:ok, customer} = Customer.create(%{first_name: "Test", last_name: "User"})

    {:ok, payment_method} =
      PaymentMethod.create(%{
        customer_id: customer.id,
        payment_method_nonce: Nonces.paypal_future_payment()
      })

    {:ok, paypal_account} = PaypalAccount.find(payment_method.token)

    assert paypal_account.email == "jane.doe@paypal.com"
    assert paypal_account.token =~ ~r/^\w+$/
  end

  test "find/1 fails with an invalid token" do
    assert {:error, :not_found} = PaypalAccount.find("bogus")
  end

  test "update/2 can successfully update a paypal account" do
    {:ok, customer} =
      Customer.create(%{
        first_name: "Test",
        last_name: "User"
      })

    {:ok, payment_method} =
      PaymentMethod.create(%{
        customer_id: customer.id,
        payment_method_nonce: Nonces.paypal_future_payment()
      })

    {:ok, paypal_account} =
      PaypalAccount.update(payment_method.token, %{
        options: %{make_default: true}
      })

    assert paypal_account.default
  end

  test "delete/1 can successfully delete a paypal account" do
    {:ok, customer} =
      Customer.create(%{
        first_name: "Test",
        last_name: "User"
      })

    {:ok, payment_method} =
      PaymentMethod.create(%{
        customer_id: customer.id,
        payment_method_nonce: Nonces.paypal_future_payment()
      })

    assert :ok = PaypalAccount.delete(payment_method.token)
  end
end
