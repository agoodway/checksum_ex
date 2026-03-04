# ChecksumEx

Elixir client for the Checksum API. Typed structs and API functions generated at compile time from the OpenAPI spec.

## Installation

Add `checksum_ex` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:checksum_ex, "~> 0.1.0"}
  ]
end
```

## Configuration

### Application config

```elixir
# config/config.exs
config :checksum_ex,
  base_url: "http://localhost:4000",
  api_key: "your-api-key"
```

### Runtime / per-request

```elixir
client = ChecksumEx.client(
  base_url: "http://localhost:4000",
  api_key: "sk_..."
)
```

You can also pass `req_options` to customize the underlying [Req](https://hexdocs.pm/req) HTTP client:

```elixir
client = ChecksumEx.client(
  api_key: "sk_...",
  req_options: [receive_timeout: 30_000]
)
```

## Usage

Every function takes a `%ChecksumEx.Client{}` as the first argument and returns `{:ok, struct}` or `{:error, reason}`.

### Create an anchor

```elixir
{:ok, %ChecksumEx.Schemas.AnchorResponse{data: data}} =
  ChecksumEx.anchor_create(client, %{
    chain_id: "my-chain",
    sequence_number: 1,
    checksum: "a1b2c3..." # SHA-256 hex digest
  })
```

### List anchors for a chain

```elixir
{:ok, %ChecksumEx.Schemas.AnchorListResponse{data: anchors, pagination: page}} =
  ChecksumEx.anchor_index(client, params: [chain_id: "my-chain", limit: 50])
```

### Get an anchor by ID

```elixir
{:ok, %ChecksumEx.Schemas.AnchorResponse{}} =
  ChecksumEx.anchor_show(client, "anchor-uuid")
```

### Verify an anchor receipt

```elixir
{:ok, %ChecksumEx.Schemas.VerificationResponse{data: result}} =
  ChecksumEx.verification_create(client, %{anchor_id: "anchor-uuid"})

result["valid"]  # => true
```

### List Merkle trees

```elixir
{:ok, %ChecksumEx.Schemas.TreeListResponse{}} = ChecksumEx.tree_index(client)
```

### Get inclusion proof

```elixir
{:ok, %ChecksumEx.Schemas.ProofResponse{data: proof}} =
  ChecksumEx.tree_proof(client, "tree-uuid", "anchor-uuid")
```

### Trigger on-demand tree build

```elixir
{:ok, %ChecksumEx.Schemas.BuildResponse{}} = ChecksumEx.tree_build(client)
```

### Public key discovery (JWKS)

```elixir
{:ok, %{"keys" => keys}} = ChecksumEx.well_known_show(client)
```

## Error handling

API errors return `{:error, %{status: integer, body: map}}`:

```elixir
case ChecksumEx.anchor_create(client, params) do
  {:ok, result} ->
    # handle success

  {:error, %{status: 422, body: body}} ->
    # validation error

  {:error, %{status: 401}} ->
    # invalid API key

  {:error, %{status: 409, body: body}} ->
    # duplicate anchor (idempotent — returns existing)

  {:error, %Req.TransportError{reason: reason}} ->
    # connection error (:econnrefused, :timeout, etc.)
end
```

## Response types

| Function | Response struct |
|----------|---------------|
| `anchor_create/2` | `AnchorResponse` |
| `anchor_index/1` | `AnchorListResponse` |
| `anchor_show/2` | `AnchorResponse` |
| `verification_create/2` | `VerificationResponse` |
| `tree_index/1` | `TreeListResponse` |
| `tree_show/2` | `TreeResponse` |
| `tree_build/1` | `BuildResponse` |
| `tree_proof/3` | `ProofResponse` |
| `well_known_show/1` | raw map (inline schema) |

## Testing

```sh
mix test
```

## Regeneration

Replace `openapi.json` at the project root and recompile — structs and API functions update automatically.
