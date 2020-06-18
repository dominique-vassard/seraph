defmodule Seraph.Query.Builder.Entity.Node do
  alias Seraph.Query.Builder.Entity
  alias Seraph.Query.Builder.Entity.Node
  alias Seraph.Query.Builder.Entity.Property

  @moduledoc false
  defstruct [:identifier, :alias, labels: [], queryable: Seraph.Node, properties: []]

  @type t :: %__MODULE__{
          queryable: Seraph.Repo.queryable() | Seraph.Node.t(),
          identifier: nil | String.t(),
          labels: [String.t()],
          alias: nil | String.t(),
          properties: [Property.t()]
        }

  @spec from_ast(Macro.t(), Macro.Env.t()) :: Node.t()
  # Node with identifier, queryable and properties
  # {u, User, %{uuid: "uuid-2"}}
  # {u, User, %{uuid: ^uuid}}
  def from_ast(
        {:{}, _,
         [
           {node_identifier, _, _},
           {:__aliases__, _, _} = queryable_ast,
           {:%{}, _, properties}
         ]},
        env
      ) do
    queryable = Macro.expand(queryable_ast, env)
    identifier = Atom.to_string(node_identifier)
    {additional_labels, properties} = Keyword.pop(properties, :additionalLabels, [])

    %Node{
      queryable: queryable,
      identifier: identifier,
      labels: [queryable.__schema__(:primary_label) | additional_labels],
      properties: Entity.build_properties(queryable, identifier, properties)
    }
  end

  # Node with node identifier, queryable, properties
  # {User, %{uuid: ^user_uuid}
  def from_ast({{:__aliases__, _, _} = queryable_ast, {:%{}, _, properties}}, env) do
    queryable = Macro.expand(queryable_ast, env)
    {additional_labels, properties} = Keyword.pop(properties, :additionalLabels, [])

    %Node{
      queryable: queryable,
      identifier: nil,
      labels: [queryable.__schema__(:primary_label) | additional_labels],
      properties: Entity.build_properties(queryable, nil, properties)
    }
  end

  # Node with identifier, no queryable, properties
  # {u, %{uuid: ^user_uuid}
  def from_ast({{node_identifier, _, _}, {:%{}, _, properties}}, _env) do
    queryable = Seraph.Node
    identifier = Atom.to_string(node_identifier)
    {additional_labels, properties} = Keyword.pop(properties, :additionalLabels, [])

    %Node{
      queryable: queryable,
      identifier: identifier,
      labels: additional_labels,
      properties: Entity.build_properties(queryable, identifier, properties)
    }
  end

  # Node with only a queryable
  # {User}
  def from_ast({:{}, _, [{:__aliases__, _, _} = queryable_ast]}, env) do
    queryable = Macro.expand(queryable_ast, env)

    %Node{
      queryable: queryable,
      labels: [queryable.__schema__(:primary_label)]
    }
  end

  # Node with no identifier, no queryable, properties
  # {%{uuid: ^uuid}}
  def from_ast({:{}, _, [{:%{}, [], properties}]}, _env) do
    queryable = Seraph.Node
    {additional_labels, properties} = Keyword.pop(properties, :additionalLabels, [])

    %Node{
      queryable: queryable,
      labels: additional_labels,
      properties: Entity.build_properties(queryable, nil, properties)
    }
  end

  # Node with identifier, no queryable, no properties
  # {u}
  def from_ast({:{}, _, [{node_identifier, _, _}]}, _env) do
    identifier = Atom.to_string(node_identifier)

    %Node{
      queryable: Seraph.Node,
      identifier: identifier
    }
  end

  # Node with identifier, queryable, no properties
  # {u, User}
  def from_ast({{node_identifier, _, _}, {:__aliases__, _, _} = queryable_ast}, env) do
    queryable = Macro.expand(queryable_ast, env)
    identifier = Atom.to_string(node_identifier)

    %Node{
      queryable: queryable,
      identifier: identifier,
      labels: [queryable.__schema__(:primary_label)]
    }
  end

  # Empty node
  # {}
  def from_ast({:{}, _, []}, _env) do
    %Node{
      queryable: Seraph.Node,
      identifier: nil
    }
  end

  @spec from_queryable(Seraph.Repo.queryable(), map | Keyword.t(), String.t()) :: %{
          entity: Node.t(),
          params: Keyword.t()
        }
  def from_queryable(queryable, properties, prefix, identifier \\ "n")

  def from_queryable(queryable, properties, prefix, identifier) when is_list(properties) do
    props = Enum.into(properties, %{})

    from_queryable(queryable, props, prefix, identifier)
  end

  def from_queryable(queryable, properties, prefix, identifier) do
    additional_labels = Map.get(properties, :additionalLabels, [])
    new_props = Map.drop(properties, [:additionalLabels])

    node = %Node{
      queryable: queryable,
      identifier: identifier,
      labels: [queryable.__schema__(:primary_label) | additional_labels]
    }

    props = Property.from_map(new_props, node)

    node
    |> Map.put(:properties, props)
    |> Entity.extract_params([], prefix)
  end

  defimpl Seraph.Query.Cypher, for: Node do
    @spec encode(Seraph.Query.Builder.Entity.Node.t(), Keyword.t()) :: String.t()
    def encode(%Node{alias: node_alias, identifier: identifier}, operation: :return)
        when not is_nil(node_alias) do
      "#{identifier} AS #{node_alias}"
    end

    def encode(%Node{identifier: identifier}, operation: :return) do
      "#{identifier}"
    end

    def encode(%Node{identifier: identifier, labels: [], properties: []}, _) do
      "(#{identifier})"
    end

    def encode(%Node{identifier: nil, labels: labels, properties: properties}, _) do
      labels_str =
        Enum.map(labels, fn label ->
          ":#{label}"
        end)
        |> Enum.join()

      props =
        Enum.map(properties, &Seraph.Query.Cypher.encode/1)
        |> Enum.join(",")

      "(#{labels_str} {#{props}})"
    end

    def encode(%Node{identifier: identifier, labels: labels, properties: []}, _) do
      labels_str =
        Enum.map(labels, fn label ->
          ":#{label}"
        end)
        |> Enum.join()

      "(#{identifier}#{labels_str})"
    end

    def encode(%Node{identifier: identifier, labels: labels, properties: properties}, _) do
      labels_str =
        Enum.map(labels, fn label ->
          ":#{label}"
        end)
        |> Enum.join()

      props =
        Enum.map(properties, &Seraph.Query.Cypher.encode/1)
        |> Enum.join(",")

      "(#{identifier}#{labels_str} {#{props}})"
    end
  end
end
