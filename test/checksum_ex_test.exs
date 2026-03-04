defmodule ChecksumExTest do
  use ExUnit.Case

  alias ChecksumEx.Client
  alias ChecksumEx.Schemas

  describe "client/1" do
    test "creates client with defaults" do
      client = ChecksumEx.client()
      assert %Client{base_url: "http://localhost:4000", api_key: nil} = client
    end

    test "creates client with explicit options" do
      client = ChecksumEx.client(base_url: "https://api.example.com", api_key: "sk_test")
      assert client.base_url == "https://api.example.com"
      assert client.api_key == "sk_test"
    end

    test "creates client with req_options" do
      client = ChecksumEx.client(req_options: [receive_timeout: 30_000])
      assert client.req_options == [receive_timeout: 30_000]
    end
  end

  describe "AnchorResponse schema" do
    test "from_map converts a valid map" do
      map = %{
        "data" => %{
          "id" => "abc-123",
          "chain_id" => "my-chain",
          "sequence_number" => 1,
          "checksum" => "deadbeef" <> String.duplicate("0", 56),
          "signature" => "base64sig==",
          "signing_key_id" => "key-456",
          "anchored_at" => "2024-01-01T00:00:00Z"
        }
      }

      result = Schemas.AnchorResponse.from_map(map)
      assert %Schemas.AnchorResponse{data: data} = result
      assert data["id"] == "abc-123"
      assert data["chain_id"] == "my-chain"
    end

    test "from_map handles nil" do
      assert nil == Schemas.AnchorResponse.from_map(nil)
    end

    test "from_map ignores unknown fields" do
      map = %{"data" => %{"id" => "1"}, "unknown_field" => "ignored"}
      result = Schemas.AnchorResponse.from_map(map)
      assert %Schemas.AnchorResponse{} = result
    end
  end

  describe "VerificationResponse schema" do
    test "from_map converts a valid map" do
      map = %{
        "data" => %{
          "valid" => true,
          "match" => true,
          "anchor" => %{
            "id" => "anchor-id",
            "chain_id" => "chain-1",
            "sequence_number" => 0,
            "checksum" => String.duplicate("a", 64),
            "signature" => "sig==",
            "signing_key_id" => "key-id",
            "anchored_at" => "2024-01-01T00:00:00Z"
          }
        }
      }

      result = Schemas.VerificationResponse.from_map(map)
      assert %Schemas.VerificationResponse{data: data} = result
      assert data["valid"] == true
      assert data["anchor"]["id"] == "anchor-id"
    end
  end

  describe "AnchorListResponse schema" do
    test "from_map converts a paginated list" do
      map = %{
        "data" => [
          %{"id" => "1", "chain_id" => "c1", "checksum" => "abc", "sequence_number" => 0}
        ],
        "pagination" => %{"has_more" => false, "next_cursor" => nil}
      }

      result = Schemas.AnchorListResponse.from_map(map)
      assert %Schemas.AnchorListResponse{data: [anchor], pagination: pagination} = result
      assert anchor["id"] == "1"
      assert pagination["has_more"] == false
    end
  end

  describe "generated API functions" do
    test "all expected functions are exported" do
      Code.ensure_loaded!(ChecksumEx)

      # No path params, no body
      assert function_exported?(ChecksumEx, :well_known_show, 1)
      assert function_exported?(ChecksumEx, :well_known_show, 2)
      assert function_exported?(ChecksumEx, :anchor_index, 1)
      assert function_exported?(ChecksumEx, :anchor_index, 2)
      assert function_exported?(ChecksumEx, :tree_index, 1)
      assert function_exported?(ChecksumEx, :tree_index, 2)

      # Body, no path params
      assert function_exported?(ChecksumEx, :anchor_create, 2)
      assert function_exported?(ChecksumEx, :anchor_create, 3)
      assert function_exported?(ChecksumEx, :verification_create, 2)
      assert function_exported?(ChecksumEx, :verification_create, 3)

      # Path params, no body
      assert function_exported?(ChecksumEx, :anchor_show, 2)
      assert function_exported?(ChecksumEx, :anchor_show, 3)
      assert function_exported?(ChecksumEx, :tree_show, 2)
      assert function_exported?(ChecksumEx, :tree_show, 3)
      assert function_exported?(ChecksumEx, :tree_proof, 3)
      assert function_exported?(ChecksumEx, :tree_proof, 4)

      # No body, no path params (POST)
      assert function_exported?(ChecksumEx, :tree_build, 1)
      assert function_exported?(ChecksumEx, :tree_build, 2)
    end
  end
end
