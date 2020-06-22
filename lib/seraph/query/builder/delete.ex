defmodule Seraph.Query.Builder.Delete do
  @behaviour Seraph.Query.Operation

  alias Seraph.Query.Builder.{Delete, Entity}

  defstruct [:entities, :raw_entities]

  @type t :: %__MODULE__{
          entities: [Entity.Node.t() | Entity.Relationship.t()],
          raw_entities: [Entity.EntityData]
        }

  @impl true
  def build(asts, env) do
    %Delete{entities: nil, raw_entities: Enum.map(asts, &build_entity(&1, env))}
  end

  @impl true
  def check(%Delete{raw_entities: raw_entities}, %Seraph.Query{} = query) do
    do_check(raw_entities, query)
  end

  @impl true
  def prepare(%Delete{entities: nil} = delete, %Seraph.Query{} = query, _opts) do
    entities =
      delete.raw_entities
      |> Enum.map(fn %Entity.EntityData{entity_identifier: identifier} ->
        Map.fetch!(query.identifiers, identifier)
      end)

    %Delete{entities: entities, raw_entities: nil}
  end

  @spec build_entity(Macro.t(), Macro.Env.t()) :: Entity.EntityData.t()
  defp build_entity({identifier, _, _}, _env) do
    %Entity.EntityData{
      entity_identifier: Atom.to_string(identifier)
    }
  end

  @spec do_check([Entity.EntityData.t()], Seraph.Query.t(), :ok | {:error, String.t()}) ::
          :ok | {:error, String.t()}
  defp do_check(raw_entities, query, result \\ :ok)

  defp do_check([], _, result) do
    result
  end

  defp do_check([%Entity.EntityData{} = entity_data | rest], query, :ok) do
    case Map.fetch(query.identifiers, entity_data.entity_identifier) do
      {:ok, _} ->
        do_check(rest, query, :ok)

      :error ->
        message =
          "[Delete] Entity with identifier `#{inspect(entity_data.entity_identifier)}` has not been matched or created."

        {:error, message}
    end
  end

  defimpl Seraph.Query.Cypher, for: Delete do
    def encode(%Delete{entities: entities}, _) do
      {nodes, relationships} =
        Enum.split_with(entities, fn
          %Entity.Node{} -> true
          %Entity.Relationship{} -> false
        end)

      nodes_str =
        nodes
        |> Enum.map(&Seraph.Query.Cypher.encode(&1, operation: :delete))
        |> Enum.join(", ")

      relationships_str =
        relationships
        |> Enum.map(&Seraph.Query.Cypher.encode(&1, operation: :delete))
        |> Enum.join(", ")

      nodes_statement =
        if String.length(nodes_str) > 0 do
          """
          DETACH DELETE
            #{nodes_str}
          """
        else
          ""
        end

      relationships_statement =
        if String.length(relationships_str) > 0 do
          """
          DELETE
            #{relationships_str}
          """
        else
          ""
        end

      [nodes_statement, relationships_statement]
      |> Enum.reject(fn str -> String.length(str) == 0 end)
      |> Enum.join("\n")
    end
  end
end
