defmodule ChecksumEx.IntegrationTest do
  use ExUnit.Case, async: true
  use Mimic

  alias ChecksumEx.Schemas

  setup :verify_on_exit!

  @client ChecksumEx.client(base_url: "http://localhost:4000", api_key: "sk_test_123")

  @anchor_id "550e8400-e29b-41d4-a716-446655440000"
  @tree_id "660e8400-e29b-41d4-a716-446655440000"

  defp json_response(status, body) do
    {:ok, %Req.Response{status: status, body: body}}
  end

  # -- Anchor endpoints --

  describe "anchor_create/2" do
    test "success — 201 returns AnchorResponse struct" do
      expect(Req, :request, fn opts ->
        assert opts[:method] == :post
        assert opts[:url] == "http://localhost:4000/api/v1/anchors"
        assert opts[:headers] == [{"authorization", "Bearer sk_test_123"}]

        assert opts[:json] == %{
                 chain_id: "my-chain",
                 sequence_number: 1,
                 checksum: String.duplicate("a", 64)
               }

        json_response(201, %{
          "data" => %{
            "id" => @anchor_id,
            "chain_id" => "my-chain",
            "sequence_number" => 1,
            "checksum" => String.duplicate("a", 64),
            "signature" => "c2lnbmF0dXJl",
            "signing_key_id" => "key-id",
            "anchored_at" => "2024-01-15T12:00:00Z"
          }
        })
      end)

      assert {:ok, %Schemas.AnchorResponse{data: data}} =
               ChecksumEx.anchor_create(@client, %{
                 chain_id: "my-chain",
                 sequence_number: 1,
                 checksum: String.duplicate("a", 64)
               })

      assert data["id"] == @anchor_id
      assert data["chain_id"] == "my-chain"
    end

    test "validation error — 422" do
      expect(Req, :request, fn _opts ->
        json_response(422, %{"errors" => %{"checksum" => ["is invalid"]}})
      end)

      assert {:error, %{status: 422, body: body}} =
               ChecksumEx.anchor_create(@client, %{
                 chain_id: "c",
                 sequence_number: 0,
                 checksum: "bad"
               })

      assert body["errors"]["checksum"] == ["is invalid"]
    end
  end

  describe "anchor_index/2" do
    test "success — returns AnchorListResponse" do
      expect(Req, :request, fn opts ->
        assert opts[:method] == :get
        assert opts[:url] == "http://localhost:4000/api/v1/anchors"
        assert opts[:params] == [chain_id: "my-chain", limit: 10]

        json_response(200, %{
          "data" => [
            %{
              "id" => @anchor_id,
              "chain_id" => "my-chain",
              "sequence_number" => 0,
              "checksum" => "abc"
            }
          ],
          "pagination" => %{"has_more" => false, "next_cursor" => nil}
        })
      end)

      assert {:ok, %Schemas.AnchorListResponse{data: [_anchor], pagination: pagination}} =
               ChecksumEx.anchor_index(@client, params: [chain_id: "my-chain", limit: 10])

      assert pagination["has_more"] == false
    end
  end

  describe "anchor_show/2" do
    test "success — returns AnchorResponse" do
      expect(Req, :request, fn opts ->
        assert opts[:method] == :get
        assert opts[:url] == "http://localhost:4000/api/v1/anchors/#{@anchor_id}"

        json_response(200, %{
          "data" => %{
            "id" => @anchor_id,
            "chain_id" => "my-chain",
            "sequence_number" => 0,
            "checksum" => String.duplicate("b", 64),
            "signature" => "sig==",
            "signing_key_id" => "key-1",
            "anchored_at" => "2024-01-15T12:00:00Z"
          }
        })
      end)

      assert {:ok, %Schemas.AnchorResponse{data: data}} =
               ChecksumEx.anchor_show(@client, @anchor_id)

      assert data["id"] == @anchor_id
    end

    test "not found — 404" do
      expect(Req, :request, fn _opts ->
        json_response(404, %{"errors" => %{"detail" => "Not Found"}})
      end)

      assert {:error, %{status: 404}} = ChecksumEx.anchor_show(@client, "nonexistent")
    end
  end

  # -- Tree endpoints --

  describe "tree_index/2" do
    test "success — returns TreeListResponse" do
      expect(Req, :request, fn opts ->
        assert opts[:method] == :get
        assert opts[:url] == "http://localhost:4000/api/v1/trees"

        json_response(200, %{
          "data" => [
            %{
              "id" => @tree_id,
              "root_hash" => String.duplicate("c", 64),
              "anchor_count" => 5,
              "published_at" => "2024-01-15T12:00:00Z",
              "period_start" => nil,
              "period_end" => nil,
              "previous_root_hash" => nil
            }
          ],
          "pagination" => %{"has_more" => false, "next_cursor" => nil}
        })
      end)

      assert {:ok, %Schemas.TreeListResponse{data: [tree]}} = ChecksumEx.tree_index(@client)
      assert tree["id"] == @tree_id
    end
  end

  describe "tree_show/2" do
    test "success — returns TreeResponse" do
      expect(Req, :request, fn opts ->
        assert opts[:method] == :get
        assert opts[:url] == "http://localhost:4000/api/v1/trees/#{@tree_id}"

        json_response(200, %{
          "data" => %{
            "id" => @tree_id,
            "root_hash" => String.duplicate("c", 64),
            "anchor_count" => 5,
            "published_at" => "2024-01-15T12:00:00Z"
          }
        })
      end)

      assert {:ok, %Schemas.TreeResponse{data: data}} = ChecksumEx.tree_show(@client, @tree_id)
      assert data["id"] == @tree_id
    end
  end

  describe "tree_build/1" do
    test "success — 202 returns BuildResponse" do
      expect(Req, :request, fn opts ->
        assert opts[:method] == :post
        assert opts[:url] == "http://localhost:4000/api/v1/trees/build"

        json_response(202, %{"data" => %{"message" => "Build enqueued"}})
      end)

      assert {:ok, %Schemas.BuildResponse{data: data}} = ChecksumEx.tree_build(@client)
      assert data["message"] == "Build enqueued"
    end
  end

  describe "tree_proof/3" do
    test "success — returns ProofResponse with dual path params" do
      expect(Req, :request, fn opts ->
        assert opts[:method] == :get
        assert opts[:url] == "http://localhost:4000/api/v1/trees/#{@tree_id}/proof/#{@anchor_id}"

        json_response(200, %{
          "data" => %{
            "root_hash" => String.duplicate("d", 64),
            "leaf_hash" => String.duplicate("e", 64),
            "proof" => [
              %{"hash" => "abc123", "direction" => "left"},
              %{"hash" => "def456", "direction" => "right"}
            ]
          }
        })
      end)

      assert {:ok, %Schemas.ProofResponse{data: data}} =
               ChecksumEx.tree_proof(@client, @tree_id, @anchor_id)

      assert length(data["proof"]) == 2
    end
  end

  # -- Verification --

  describe "verification_create/2" do
    test "success — verify by anchor_id" do
      expect(Req, :request, fn opts ->
        assert opts[:method] == :post
        assert opts[:url] == "http://localhost:4000/api/v1/verify"
        assert opts[:json] == %{anchor_id: @anchor_id}

        json_response(200, %{
          "data" => %{
            "valid" => true,
            "anchor" => %{
              "id" => @anchor_id,
              "chain_id" => "my-chain",
              "sequence_number" => 0,
              "checksum" => String.duplicate("a", 64),
              "signature" => "sig==",
              "signing_key_id" => "key-1",
              "anchored_at" => "2024-01-15T12:00:00Z"
            }
          }
        })
      end)

      assert {:ok, %Schemas.VerificationResponse{data: data}} =
               ChecksumEx.verification_create(@client, %{anchor_id: @anchor_id})

      assert data["valid"] == true
    end
  end

  # -- Transport errors --

  describe "transport errors" do
    test "connection refused" do
      expect(Req, :request, fn _opts ->
        {:error, %Req.TransportError{reason: :econnrefused}}
      end)

      assert {:error, %Req.TransportError{reason: :econnrefused}} =
               ChecksumEx.anchor_index(@client)
    end

    test "timeout" do
      expect(Req, :request, fn _opts ->
        {:error, %Req.TransportError{reason: :timeout}}
      end)

      assert {:error, %Req.TransportError{reason: :timeout}} =
               ChecksumEx.anchor_create(@client, %{
                 chain_id: "c",
                 sequence_number: 0,
                 checksum: "x"
               })
    end
  end

  # -- Client configuration --

  describe "client configuration" do
    test "no auth header when api_key is nil" do
      client = ChecksumEx.client(base_url: "http://localhost:4000")

      expect(Req, :request, fn opts ->
        assert opts[:headers] == []

        json_response(200, %{
          "data" => [],
          "pagination" => %{"has_more" => false, "next_cursor" => nil}
        })
      end)

      assert {:ok, _} = ChecksumEx.anchor_index(client)
    end

    test "req_options are merged into requests" do
      client =
        ChecksumEx.client(
          base_url: "http://localhost:4000",
          api_key: "sk_test",
          req_options: [receive_timeout: 30_000]
        )

      expect(Req, :request, fn opts ->
        assert opts[:receive_timeout] == 30_000

        json_response(200, %{
          "data" => [],
          "pagination" => %{"has_more" => false, "next_cursor" => nil}
        })
      end)

      assert {:ok, _} = ChecksumEx.anchor_index(client)
    end
  end

  # -- Well-known endpoint --

  describe "well_known_show/1" do
    test "returns raw map (inline schema)" do
      expect(Req, :request, fn opts ->
        assert opts[:method] == :get
        assert opts[:url] == "http://localhost:4000/.well-known/checksum-dev.json"

        json_response(200, %{
          "keys" => [
            %{
              "kty" => "OKP",
              "crv" => "Ed25519",
              "x" => "base64key",
              "kid" => "key-1",
              "use" => "sig",
              "status" => "active"
            }
          ]
        })
      end)

      assert {:ok, %{"keys" => [key]}} = ChecksumEx.well_known_show(@client)
      assert key["kty"] == "OKP"
    end
  end
end
