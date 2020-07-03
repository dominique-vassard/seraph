defmodule Seraph.Query.Builder.Match do
  @moduledoc false

  @behaviour Seraph.Query.Operation

  alias Seraph.Query.Builder.{Entity, Helper, Match}

  defstruct [:entities]

  @type t :: %__MODULE__{
          entities: [Entity.t()]
        }

  @doc """
  Build Match data from ast.
  """
  @impl true
  @spec build(Macro.t(), Macro.Env.t()) :: %{
          match: Match.t(),
          identifiers: map,
          params: Keyword.t()
        }
  def build(ast, env) do
    entity_list = Enum.map(ast, &build_entity(&1, env))

    match_data =
      Enum.reduce(
        entity_list,
        %{entities: [], identifiers: %{}, params: []},
        fn entity, query_data ->
          %{entity: new_entity, params: updated_params} =
            Entity.extract_params(entity, query_data.params, "match__")

          Helper.check_identifier_presence(query_data.identifiers, new_entity.identifier)

          %{
            query_data
            | entities: [new_entity | query_data.entities],
              identifiers: build_identifiers(new_entity, query_data.identifiers),
              params: updated_params
          }
        end
      )

    match_data
    |> Map.put(:match, %Match{entities: match_data.entities})
    |> Map.drop([:entities])
  end

  @doc """
    Check:
      - property is owned by queryable
      - property value type is valid
      - property value exists in params
  """
  @impl true
  @spec check(nil | Match.t(), Seraph.Query.t()) :: :ok | {:error, String.t()}
  def check(match_data, query) do
    do_check(match_data.entities, query)
  end

  @spec do_check([Entity.t()], Seraph.Query.t(), :ok | {:error, String.t()}) ::
          :ok | {:error, String.t()}
  defp do_check(entity_to_check, query, result \\ :ok)

  defp do_check([], _, result) do
    result
  end

  defp do_check(_, _, {:error, _} = error) do
    error
  end

  defp do_check([%{properties: properties} | rest], query, :ok) do
    result = do_check_properties(properties, query.params)
    do_check(rest, query, result)
  end

  @spec do_check_properties([Entity.Property.t()], Keyword.t(), :ok | {:error, String.t()}) ::
          :ok | {:error, String.t()}
  defp do_check_properties(properties_to_check, query_params, result \\ :ok)

  defp do_check_properties([], _, result) do
    result
  end

  defp do_check_properties([property | rest], query_params, :ok) do
    case Keyword.fetch!(query_params, String.to_atom(property.bound_name)) do
      nil ->
        do_check_properties(
          rest,
          query_params,
          {:error, "`nil` is not a valid value. Use `is_nil(property)` instead."}
        )

      value ->
        result = Helper.check_property(property.entity_queryable, property.name, value)
        do_check_properties(rest, query_params, result)
    end
  end

  defp do_check_properties(_, _, {:error, _} = error) do
    error
  end

  @spec build_entity(Macro.t(), Macro.Env.t()) :: Entity.t()
  defp build_entity({:{}, _, [{:__aliases__, _, [_]}]}, _env) do
    raise ArgumentError, "Nodes with only a queryable are not allowed except in relationships."
  end

  # Empty node: not allowed in any other case
  # {}
  defp build_entity({:{}, _, []}, _env) do
    raise ArgumentError, "Empty nodes are not supported except in relationships."
  end

  defp build_entity([_start_ast, _relationship_ast, _end_ast] = ast, env) do
    Entity.Relationship.from_ast(ast, env)
  end

  defp build_entity(ast, env) do
    Entity.Node.from_ast(ast, env)
  end

  @spec build_identifiers(Entity.t(), %{String.t() => Entity.t()}) :: %{String.t() => Entity.t()}
  defp build_identifiers(%Entity.Node{identifier: nil}, current_identifiers) do
    current_identifiers
  end

  defp build_identifiers(%Entity.Node{} = entity, current_identifiers) do
    Helper.check_identifier_presence(current_identifiers, entity.identifier)
    Map.put(current_identifiers, entity.identifier, entity)
  end

  defp build_identifiers(%Entity.Relationship{} = relationship, current_identifiers) do
    new_identifiers =
      current_identifiers
      |> build_relationship_nodes_identifiers(relationship.start)
      |> build_relationship_nodes_identifiers(relationship.end)

    if is_nil(relationship.identifier) do
      new_identifiers
    else
      Helper.check_identifier_presence(current_identifiers, relationship.identifier)
      Map.put(new_identifiers, relationship.identifier, relationship)
    end
  end

  @spec build_relationship_nodes_identifiers(%{String.t() => Entity.t()}, Entity.t()) :: %{
          String.t() => Entity.t()
        }
  defp build_relationship_nodes_identifiers(current_identifiers, %Entity.Node{identifier: nil}) do
    current_identifiers
  end

  defp build_relationship_nodes_identifiers(
         current_identifiers,
         %Entity.Node{identifier: identifier} = node_data
       ) do
    case Map.fetch(current_identifiers, identifier) do
      :error ->
        Map.put(current_identifiers, identifier, node_data)

      {:ok, %Entity.Node{queryable: Seraph.Node}} ->
        current_identifiers
        |> Map.drop([identifier])
        |> Map.put(identifier, node_data)

      {:ok, %Entity.Node{queryable: queryable}} ->
        if queryable != node_data.queryable do
          message =
            "identifier `#{identifier}` for schema `#{inspect(node_data.queryable)}` is already used for schema `#{
              inspect(queryable)
            }`"

          raise ArgumentError, message
        end

      {:ok, %Entity.Relationship{}} ->
        raise ArgumentError, "identifier `#{identifier}` is already taken."
    end
  end

  defimpl Seraph.Query.Cypher, for: Match do
    @spec encode(Match.t(), Keyword.t()) :: String.t()
    def encode(%Match{entities: entities}, _) do
      match_str =
        entities
        |> Enum.map(&Seraph.Query.Cypher.encode(&1, operation: :match))
        |> Enum.join(",\n\t")

      if String.length(match_str) > 0 do
        """
        MATCH
          #{match_str}
        """
      end
    end
  end
end
