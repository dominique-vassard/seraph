defmodule Seraph.Query.Builder.Create do
  @moduledoc false

  @behaviour Seraph.Query.Operation

  alias Seraph.Query.Builder.{Create, Entity, Helper, Match}

  defstruct [:entities, :raw_entities]

  @type t :: %__MODULE__{
          raw_entities: [Entity.t()],
          entities: [Entity.t()]
        }

  @doc """
  Build a Create from ast.
  """
  @impl true
  @spec build(Macro.t(), Macro.Env.t()) :: %{
          create: Create.t(),
          identifiers: map,
          params: Keyword.t()
        }
  def build(ast, env) do
    create_data =
      ast
      |> Enum.map(&build_entity(&1, env))
      |> Enum.reduce(
        %{entities: [], identifiers: %{}, params: []},
        fn entity, query_data ->
          %{entity: new_entity, params: updated_params} =
            Entity.extract_params(entity, query_data.params, "create__")

          Helper.check_identifier_presence(query_data.identifiers, new_entity.identifier)

          %{
            query_data
            | entities: [new_entity | query_data.entities],
              identifiers: Helper.build_identifiers(new_entity, query_data.identifiers, :create),
              params: updated_params
          }
        end
      )

    create_data
    |> Map.put(:create, %Create{raw_entities: create_data.entities})
    |> Map.drop([:entities])
  end

  @doc """
    Check:
      - [From Match] property is owned by queryable
      - [From Match] property value type is valid
      - [From Match] property value exists in params
      - relationship nodes has queryable
  """
  @impl true
  @spec check(Create.t(), Seraph.Query.t()) :: :ok | {:error, String.t()}
  def check(create_data, query) do
    result = Match.check(%Match{entities: create_data.raw_entities}, query)

    {nodes, relationships} =
      create_data.raw_entities
      |> Enum.split_with(fn
        %Entity.Node{} -> true
        _ -> false
      end)

    # relationships =
    #   create_data.raw_entities
    #   |> Enum.filter(fn
    #     %Entity.Relationship{} -> true
    #     _ -> false
    #   end)
    with :ok <- do_check_relationship_nodes(relationships, query, result),
         :ok <- do_check_node_labels(nodes) do
      :ok
    else
      {:error, _} = error ->
        error
    end
  end

  @impl true
  @spec prepare(Create.t(), Seraph.Query.t(), Keyword.t()) :: %{
          create: Create.t(),
          new_identifiers: map
        }
  def prepare(%Create{raw_entities: raw_entities} = create, %Seraph.Query{} = query, _opts) do
    %{entities: new_entities, new_identifiers: new_identifiers} =
      Enum.reduce(
        raw_entities,
        %{entities: [], new_identifiers: %{}},
        fn
          %Entity.Relationship{} = relationship, data ->
            new_relationship =
              relationship
              |> Map.put(:start, Map.fetch!(query.identifiers, relationship.start.identifier))
              |> Map.put(:end, Map.fetch!(query.identifiers, relationship.end.identifier))

            %{
              data
              | entities: [new_relationship | data.entities],
                new_identifiers:
                  Map.put(data.new_identifiers, relationship.identifier, new_relationship)
            }

          entity, data ->
            %{data | entities: [entity | data.entities]}
        end
      )

    %{create: Map.put(create, :entities, new_entities), new_identifiers: new_identifiers}
  end

  @spec build_entity(Macro.t(), Macro.Env.t()) :: Entity.t()
  # Node with identifier, no queryable, properties
  # {u, %{uuid: ^user_uuid}
  defp build_entity({{identifier, _, _}, {:%{}, _, _properties}}, _env)
       when identifier != :__aliases__ do
    raise ArgumentError, "[CREATE] Nodes without a queryable are not allowed."
  end

  # Node with identifier, no queryable, no properties
  # {u}
  defp build_entity({:{}, _, [{_node_identifier, _, _}]}, _env) do
    raise ArgumentError, "[CREATE] Nodes without a queryable are not allowed."
  end

  # Empty node
  # {}
  defp build_entity({:{}, _, []}, _env) do
    raise ArgumentError, "Empty nodes are not allowed in :create."
  end

  defp build_entity([start_ast, relationship_ast, end_ast], env) do
    start_node = Entity.Node.from_ast(start_ast, env)
    end_node = Entity.Node.from_ast(end_ast, env)

    relationship =
      Entity.Relationship.from_ast(relationship_ast, env)
      |> Map.put(:start, start_node)
      |> Map.put(:end, end_node)

    if relationship.queryable == Seraph.Relationship do
      raise ArgumentError, "[CREATE] Relationships without a queryable are not allowed."
    end

    check_related_node(relationship.start)
    check_related_node(relationship.end)
    relationship
  end

  defp build_entity(ast, env) do
    Entity.Node.from_ast(ast, env)
  end

  @spec check_related_node(Entity.Node.t()) :: :ok
  defp check_related_node(%Entity.Node{
         identifier: identifier,
         queryable: Seraph.Node,
         properties: properties
       })
       when length(properties) > 0 do
    raise ArgumentError, "[CREATE] Already matched node `#{identifier}` can't be re-matched."
  end

  defp check_related_node(_) do
    :ok
  end

  @spec do_check_relationship_nodes(
          [Entity.Relationship],
          Seraph.Query.t(),
          :ok | {:error, String.t()}
        ) :: :ok | {:error, String.t()}
  defp do_check_relationship_nodes([], _, result) do
    result
  end

  defp do_check_relationship_nodes(_, _, {:error, _} = error) do
    error
  end

  defp do_check_relationship_nodes([relationship | rest], query, :ok) do
    %Entity.Relationship{start: start_node, end: end_node} = relationship

    result_start = do_check_relationship_node(start_node, query)
    result = do_check_relationship_node(end_node, query, result_start)

    do_check_relationship_nodes(rest, query, result)
  end

  @spec do_check_relationship_node(Entity.Node.t(), Seraph.Query.t(), :ok | {:error, String.t()}) ::
          :ok | {:error, String.t()}
  defp do_check_relationship_node(related_node, query, result \\ :ok)

  defp do_check_relationship_node(_, _, {:error, _} = error) do
    error
  end

  defp do_check_relationship_node(%Entity.Node{identifier: identifier}, query, :ok) do
    case Map.fetch!(query.identifiers, identifier) do
      %Entity.Node{queryable: Seraph.Node} ->
        {:error, "[CREATE] Node `#{identifier}` must have been matched before usage"}

      %Entity.Node{} ->
        :ok
    end
  end

  defp do_check_node_labels(nodes) do
    nodes
    |> Enum.flat_map(fn %Entity.Node{labels: labels} -> labels end)
    |> do_check_labels(:ok)
  end

  defp do_check_labels([], result) do
    result
  end

  defp do_check_labels(_, {:error, _} = error) do
    error
  end

  defp do_check_labels([label_str | rest], :ok) do
    result = do_check_label(label_str)
    do_check_labels(rest, result)
  end

  defp do_check_label(label_str) do
    if Regex.match?(~r/^([A-Z]{1}[a-z]*)+$/, label_str) or
         String.upcase(label_str) == label_str do
      :ok
    else
      {:error, "[CREATE] Node label should be CamelCased"}
    end
  end

  defimpl Seraph.Query.Cypher, for: Create do
    def encode(%Create{raw_entities: raw_entities}, _) do
      create_str =
        raw_entities
        |> Enum.map(&Seraph.Query.Cypher.encode(&1, operation: :create))
        |> Enum.join("\n\t")

      if String.length(create_str) > 0 do
        """
        CREATE
          #{create_str}
        """
      end
    end
  end
end
