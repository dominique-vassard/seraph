defmodule Seraph.Repo.Helper do
  @moduledoc false

  @doc """
  Return node schema identifier key if it exists.
  """
  @spec identifier_field(Seraph.Repo.queryable()) :: atom
  def identifier_field(queryable) do
    case queryable.__schema__(:identifier) do
      {field, _, _} ->
        field

      _ ->
        raise ArgumentError, "No identifier for #{inspect(queryable)}."
    end
  end

  @doc """
  Build a node schema from a Bolt.Sips.Node
  """
  @spec build_node(Seraph.Repo.queryable(), map) :: Seraph.Schema.Node.t()
  def build_node(queryable, node_data) do
    props =
      node_data.properties
      |> atom_map()
      |> Map.put(:__id__, node_data.id)
      |> Map.put(:additionalLabels, node_data.labels -- [queryable.__schema__(:primary_label)])

    struct(queryable, props)
  end

  @doc """
  Convert a %{String.t => value} map to an %{atom: value} map
  """
  @spec atom_map(map) :: map
  def atom_map(string_map) do
    string_map
    |> Enum.map(fn {k, v} ->
      {String.to_atom(k), v}
    end)
    |> Enum.into(%{})
  end

  @doc """
  Manage MERGE options:
    * `:on_create`
    * `:on_match`
  """
  @spec create_match_merge_opts(Keyword.t(), Keyword.t()) :: Keyword.t() | {:error, String.t()}
  def create_match_merge_opts(opts, final_opts \\ [])

  def create_match_merge_opts([{:on_create, {data, changeset_fn} = on_create_opts} | rest], opts)
      when is_map(data) and is_function(changeset_fn, 2) do
    create_match_merge_opts(rest, Keyword.put(opts, :on_create, on_create_opts))
  end

  def create_match_merge_opts([{:on_create, on_create_opts} | _], _opts) do
    msg = """
    on_create: Require a tuple {data_for_creation, changeset_fn} with following types:
      - data_for_creation: map
      - changeset_fn: 2-arity function
    Received: #{inspect(on_create_opts)}
    """

    {:error, msg}
  end

  def create_match_merge_opts([{:on_match, {data, changeset_fn} = on_match_opts} | rest], opts)
      when is_map(data) and is_function(changeset_fn, 2) do
    create_match_merge_opts(rest, Keyword.put(opts, :on_match, on_match_opts))
  end

  def create_match_merge_opts([{:no_data, no_data_opt} | rest], opts)
      when is_boolean(no_data_opt) do
    create_match_merge_opts(rest, Keyword.put(opts, :no_data, no_data_opt))
  end

  def create_match_merge_opts([{:on_match, on_match_opts} | _], _opts) do
    msg = """
    on_match: Require a tuple {data_for_creation, changeset_fn} with following types:
      - data_for_creation: map
      - changeset_fn: 2-arity function
    Received: #{inspect(on_match_opts)}
    """

    {:error, msg}
  end

  def create_match_merge_opts([{invalid_opt, _} | _], _opts) do
    {:error, "#{inspect(invalid_opt)} is not a valid option."}
  end

  def create_match_merge_opts(_, opts) do
    opts
  end
end
