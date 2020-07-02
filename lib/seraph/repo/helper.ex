defmodule Seraph.Repo.Helper do
  @moduledoc false

  def identifier_field(queryable) do
    case queryable.__schema__(:identifier) do
      {field, _, _} ->
        field

      false ->
        false
    end
  end

  @doc """
  Return node schema identifier key if it exists.
  """
  @spec identifier_field!(Seraph.Repo.queryable()) :: atom
  def identifier_field!(queryable) do
    case identifier_field(queryable) do
      false ->
        raise ArgumentError, "No identifier for #{inspect(queryable)}."

      field ->
        field
    end
  end

  @doc """
  Build a node schema from a Bolt.Sips.Node
  """
  @spec build_node(Seraph.Repo.queryable(), nil | map) ::
          nil | Seraph.Schema.Node.t() | Seraph.Node.t()
  def build_node(Seraph.Node, %Bolt.Sips.Types.Node{} = node_data) do
    Seraph.Node.map(node_data)
  end

  def build_node(queryable, %Bolt.Sips.Types.Node{} = node_data) do
    props =
      node_data.properties
      |> atom_map()
      |> Map.put(:__id__, node_data.id)
      |> Map.put(:additionalLabels, node_data.labels -- [queryable.__schema__(:primary_label)])

    struct(queryable, props)
  end

  def build_node(_, nil) do
    nil
  end

  def build_relationship(queryable, rel_data, nil, nil) do
    props =
      rel_data.properties
      |> atom_map()
      |> Map.put(:__id__, rel_data.id)
      |> Map.put(:start_node, nil)
      |> Map.put(:end_node, nil)

    case queryable do
      nil ->
        Seraph.Relationship.map(rel_data.type, props)

      queryable ->
        struct(queryable, props)
    end
  end

  # def build_relationship(queryable, rel_data, start_data, end_data) do
  #   props =
  #     rel_data.properties
  #     |> atom_map()
  #     |> Map.put(:__id__, rel_data.id)
  #     |> Map.put(:start_node, build_node(queryable.__schema__(:start_node), start_data))
  #     |> Map.put(:end_node, build_node(queryable.__schema__(:end_node), end_data))

  #   struct(queryable, props)
  # end

  # def build_relationship(queryable, rel_data, start_data, end_data) do
  #   props =
  #     rel_data.properties
  #     |> atom_map()
  #     |> Map.put(:__id__, rel_data.id)
  #     |> Map.put(:start_node, build_node(start_data.queryable, start_data))
  #     |> Map.put(:end_node, build_node(end_data.queryable, end_data))

  #   case queryable do
  #     Seraph.Relationship ->
  #       Seraph.Relationship.map(rel_data.type, props)

  #     queryable ->
  #       struct(queryable, props)
  #   end
  # end

  def build_relationship(
        queryable,
        rel_data,
        start_queryable,
        start_data,
        end_queryable,
        end_data
      ) do
    props =
      rel_data.properties
      |> atom_map()
      |> Map.put(:__id__, rel_data.id)
      |> Map.put(:start_node, build_node(start_queryable, start_data))
      |> Map.put(:end_node, build_node(end_queryable, end_data))

    case queryable do
      Seraph.Relationship ->
        Seraph.Relationship.map(rel_data.type, props)

      queryable ->
        struct(queryable, props)
    end
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
  def create_match_merge_opts(opts, final_opts \\ [no_data: false])

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

  @doc """
  Extract property from node schema
  """
  @spec extract_node_properties(Seraph.Schema.Node.t()) :: map
  def extract_node_properties(%{__struct__: queryable} = node_data) do
    id_field = Seraph.Repo.Helper.identifier_field!(queryable)
    id_value = Map.fetch!(node_data, id_field)

    Map.put(%{}, id_field, id_value)
  end

  def extract_node_properties(node_properties) do
    node_properties
  end
end
