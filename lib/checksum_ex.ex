defmodule ChecksumEx do
  @moduledoc """
  Elixir client for the Checksum API, generated from the OpenAPI specification.

  ## Configuration

      config :checksum_ex,
        base_url: "http://localhost:4000",
        api_key: "your-api-key"

  ## Usage

      client = ChecksumEx.client(api_key: "sk_...")
      {:ok, result} = ChecksumEx.anchor_create(client, %{chain_id: "my-chain", sequence_number: 1, checksum: "abc..."})
  """

  @spec_path Path.join([__DIR__, "..", "openapi.json"])
  @external_resource @spec_path
  @openapi_spec File.read!(@spec_path) |> Jason.decode!()

  alias ChecksumEx.Client

  @doc "Create a new API client."
  def client(opts \\ []), do: Client.new(opts)

  # Compile-time: generate one function per API operation from the OpenAPI spec.
  for {path, methods} <- @openapi_spec["paths"],
      {method, operation} <- methods do
    op_id = operation["operationId"]

    func_name =
      op_id
      |> String.replace(".", "_")
      |> Macro.underscore()
      |> String.to_atom()

    http_method = String.to_atom(method)
    summary = operation["summary"] || ""
    desc = operation["description"] || ""
    has_body = operation["requestBody"] != nil

    path_param_names =
      Regex.scan(~r/\{(\w+)\}/, path)
      |> Enum.map(fn [_, n] -> String.to_atom(n) end)

    path_vars = Enum.map(path_param_names, &Macro.var(&1, nil))

    success_ref =
      Enum.find_value(~w(200 201 202), fn code ->
        get_in(operation, ["responses", code, "content", "application/json", "schema", "$ref"])
      end)

    response_mod =
      if success_ref do
        ref_name = success_ref |> String.split("/") |> List.last()
        Module.concat(ChecksumEx.Schemas, ref_name)
      end

    cond do
      # Path params + request body
      length(path_param_names) > 0 and has_body ->
        @doc "#{summary}\n\n#{desc}"
        def unquote(func_name)(%Client{} = client, unquote_splicing(path_vars), params)
            when is_map(params),
            do: unquote(func_name)(client, unquote_splicing(path_vars), params, [])

        @doc false
        def unquote(func_name)(%Client{} = client, unquote_splicing(path_vars), params, opts)
            when is_map(params) and is_list(opts) do
          built_path =
            build_path(
              unquote(path),
              Enum.zip(unquote(path_param_names), [unquote_splicing(path_vars)])
            )

          client
          |> Client.request(unquote(http_method), built_path, [{:json, params} | opts])
          |> to_result(unquote(response_mod))
        end

      # Path params, no body
      length(path_param_names) > 0 ->
        @doc "#{summary}\n\n#{desc}"
        def unquote(func_name)(%Client{} = client, unquote_splicing(path_vars)),
          do: unquote(func_name)(client, unquote_splicing(path_vars), [])

        @doc false
        def unquote(func_name)(%Client{} = client, unquote_splicing(path_vars), opts)
            when is_list(opts) do
          built_path =
            build_path(
              unquote(path),
              Enum.zip(unquote(path_param_names), [unquote_splicing(path_vars)])
            )

          client
          |> Client.request(unquote(http_method), built_path, opts)
          |> to_result(unquote(response_mod))
        end

      # Request body, no path params
      has_body ->
        @doc "#{summary}\n\n#{desc}"
        def unquote(func_name)(%Client{} = client, params) when is_map(params),
          do: unquote(func_name)(client, params, [])

        @doc false
        def unquote(func_name)(%Client{} = client, params, opts)
            when is_map(params) and is_list(opts) do
          client
          |> Client.request(unquote(http_method), unquote(path), [{:json, params} | opts])
          |> to_result(unquote(response_mod))
        end

      # No path params, no body
      true ->
        @doc "#{summary}\n\n#{desc}"
        def unquote(func_name)(%Client{} = client), do: unquote(func_name)(client, [])

        @doc false
        def unquote(func_name)(%Client{} = client, opts) when is_list(opts) do
          client
          |> Client.request(unquote(http_method), unquote(path), opts)
          |> to_result(unquote(response_mod))
        end
    end
  end

  defp to_result({:ok, body}, nil), do: {:ok, body}
  defp to_result({:ok, body}, mod) when is_map(body), do: {:ok, mod.from_map(body)}
  defp to_result({:ok, body}, _mod), do: {:ok, body}
  defp to_result(error, _mod), do: error

  defp build_path(template, replacements) do
    Enum.reduce(replacements, template, fn {name, value}, acc ->
      String.replace(acc, "{#{name}}", to_string(value))
    end)
  end
end
