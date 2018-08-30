defmodule BlockScoutWeb.AddressViewTest do
  use BlockScoutWeb.ConnCase, async: true

  alias Explorer.Chain.{Address, Data, Hash}
  alias BlockScoutWeb.AddressView
  alias Explorer.ExchangeRates.Token

  describe "contract?/1" do
    test "with a smart contract" do
      {:ok, code} = Data.cast("0x000000000000000000000000862d67cb0773ee3f8ce7ea89b328ffea861ab3ef")
      address = insert(:address, contract_code: code)
      assert AddressView.contract?(address)
    end

    test "with an account" do
      address = insert(:address, contract_code: nil)
      refute AddressView.contract?(address)
    end
  end

  describe "formatted_usd/2" do
    test "without a fetched_balance returns nil" do
      address = build(:address, fetched_balance: nil)
      token = %Token{usd_value: Decimal.new(0.5)}
      assert nil == AddressView.formatted_usd(address, token)
    end

    test "without a usd_value returns nil" do
      address = build(:address)
      token = %Token{usd_value: nil}
      assert nil == AddressView.formatted_usd(address, token)
    end

    test "returns formatted usd value" do
      address = build(:address, fetched_balance: 10_000_000_000_000)
      token = %Token{usd_value: Decimal.new(0.5)}
      assert "$0.000005 USD" == AddressView.formatted_usd(address, token)
    end
  end

  describe "qr_code/1" do
    test "it returns an encoded value" do
      address = build(:address)
      assert {:ok, _} = Base.decode64(AddressView.qr_code(address))
    end
  end

  describe "smart_contract_verified?/1" do
    test "returns true when smart contract is verified" do
      smart_contract = insert(:smart_contract)
      address = insert(:address, smart_contract: smart_contract)

      assert AddressView.smart_contract_verified?(address)
    end

    test "returns false when smart contract is not verified" do
      address = insert(:address, smart_contract: nil)

      refute AddressView.smart_contract_verified?(address)
    end
  end

  describe "smart_contract_with_read_only_functions?/1" do
    test "returns true when abi has read only functions" do
      smart_contract =
        insert(
          :smart_contract,
          abi: [
            %{
              "constant" => true,
              "inputs" => [],
              "name" => "get",
              "outputs" => [%{"name" => "", "type" => "uint256"}],
              "payable" => false,
              "stateMutability" => "view",
              "type" => "function"
            }
          ]
        )

      address = insert(:address, smart_contract: smart_contract)

      assert AddressView.smart_contract_with_read_only_functions?(address)
    end

    test "returns false when there is no read only functions" do
      smart_contract =
        insert(
          :smart_contract,
          abi: [
            %{
              "constant" => false,
              "inputs" => [%{"name" => "x", "type" => "uint256"}],
              "name" => "set",
              "outputs" => [],
              "payable" => false,
              "stateMutability" => "nonpayable",
              "type" => "function"
            }
          ]
        )

      address = insert(:address, smart_contract: smart_contract)

      refute AddressView.smart_contract_with_read_only_functions?(address)
    end

    test "returns false when smart contract is not verified" do
      address = insert(:address, smart_contract: nil)

      refute AddressView.smart_contract_with_read_only_functions?(address)
    end
  end

  describe "hash/1" do
    test "gives a string version of an address's hash" do
      address = %Address{
        hash: %Hash{
          byte_count: 20,
          bytes: <<139, 243, 141, 71, 100, 146, 144, 100, 242, 212, 211, 165, 101, 32, 167, 106, 179, 223, 65, 91>>
        }
      }

      assert AddressView.hash(address) == "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
    end
  end

  describe "balance_block_number/1" do
    test "gives empty string with no fetched balance block number present" do
      assert AddressView.balance_block_number(%Address{}) == ""
    end

    test "gives block number when fetched balance block number is non-nil" do
      assert AddressView.balance_block_number(%Address{fetched_balance_block_number: 1_000_000}) == "1000000"
    end
  end

  describe "primary_name/1" do
    test "gives an address's primary name when present" do
      address = insert(:address)

      address_name = insert(:address_name, address: address, primary: true, name: "POA Foundation Wallet")
      insert(:address_name, address: address, name: "POA Wallet")

      preloaded_address = Explorer.Repo.preload(address, :names)

      assert AddressView.primary_name(preloaded_address) == address_name.name
    end

    test "returns nil when no primary available" do
      address_name = insert(:address_name, name: "POA Wallet")
      preloaded_address = Explorer.Repo.preload(address_name.address, :names)

      refute AddressView.primary_name(preloaded_address)
    end
  end
end
