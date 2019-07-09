defmodule Braintree.HTTPTest do
  use ExUnit.Case

  import ExUnit.CaptureLog

  alias Braintree.{ConfigError, HTTP}

  test "build_url/2 builds a url from application config without options" do
    with_applicaton_config(:merchant_id, "qwertyid", fn ->
      assert HTTP.build_url("customer", []) =~
               "sandbox.braintreegateway.com/merchants/qwertyid/customer"
    end)
  end

  test "build_url/2 builds a url from provided options" do
    assert HTTP.build_url("customer", environment: "production", merchant_id: "opts_merchant_id") =~
             "api.braintreegateway.com/merchants/opts_merchant_id/customer"
  end

  test "build_url/2 raises a helpful error message without config" do
    assert_config_error(:merchant_id, fn ->
      HTTP.build_url("customer", [])
    end)
  end

  test "encode_body/1 converts the request body to xml" do
    params = %{company: "Soren", first_name: "Parker"}

    assert HTTP.encode_body(params) ==
             ~s|<?xml version="1.0" encoding="UTF-8" ?>\n<company>Soren</company>\n<first-name>Parker</first-name>|
  end

  test "encode_body/1 ignores empty bodies" do
    assert HTTP.encode_body("") == ""
    assert HTTP.encode_body(%{}) == ""
  end

  test "decode_body/1 converts the request back from xml" do
    xml =
      compress(~s|<?xml version="1.0" encoding="UTF-8" ?>\n<company><name>Soren</name></company>|)

    assert HTTP.decode_body(xml) == %{"company" => %{"name" => "Soren"}}
  end

  test "decode_body/1 safely handles empty responses" do
    assert HTTP.decode_body(compress("")) == %{}
    assert HTTP.decode_body(compress(" ")) == %{}
  end

  test "decode_body/1 logs unhandled errors" do
    assert capture_log(fn ->
             HTTP.decode_body("asdf")
           end) =~ "unprocessable response"
  end

  test "build_options/0 considers the application environment" do
    with_applicaton_config(:http_options, [timeout: 9000], fn ->
      options = HTTP.build_options()

      assert :with_body in options
      assert {:timeout, 9000} in options
    end)
  end

  describe "request/3" do
    test "unauthorized response with an invalid merchant id" do
      with_applicaton_config(:merchant_id, "junkmerchantid", fn ->
        assert {:error, :unauthorized} = HTTP.request(:get, "customers")
      end)
    end
  end

  describe "build_headers/1" do
    test "building an auth header from application config" do
      with_applicaton_config(:private_key, "the_private_key", fn ->
        with_applicaton_config(:public_key, "the_public_key", fn ->
          {_, auth_header} = List.keyfind(HTTP.build_headers([]), "Authorization", 0)

          assert auth_header == "Basic dGhlX3B1YmxpY19rZXk6dGhlX3ByaXZhdGVfa2V5"
        end)
      end)
    end

    test "building an auth header from only an access token" do
      with_applicaton_config(:access_token, "special_access_token", fn ->
        {_, auth_header} = List.keyfind(HTTP.build_headers([]), "Authorization", 0)

        assert auth_header == "Bearer special_access_token"
      end)
    end

    test "building an auth header from provided options" do
      headers =
        HTTP.build_headers(
          access_token: nil,
          private_key: "dynamic_key",
          public_key: "dyn_pub_key"
        )

      {_, auth_header} = List.keyfind(headers, "Authorization", 0)

      assert auth_header == "Basic ZHluX3B1Yl9rZXk6ZHluYW1pY19rZXk="
    end

    test "build_headers/1 raises a helpful error message without config" do
      assert_config_error(:public_key, fn ->
        HTTP.build_headers([])
      end)
    end
  end

  defp compress(string), do: :zlib.gzip(string)

  defp assert_config_error(key, fun) do
    value = Braintree.get_env(key)

    try do
      Application.delete_env(:braintree, key)
      assert_raise ConfigError, "missing config for :#{key}", fun
    after
      Braintree.put_env(key, value)
    end
  end

  defp with_applicaton_config(key, value, fun) do
    original = Braintree.get_env(key, :none)

    try do
      Braintree.put_env(key, value)
      fun.()
    after
      Braintree.put_env(key, original)
    end
  end
end
