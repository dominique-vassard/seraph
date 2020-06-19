defmodule Seraph.Repo.Relationship.Queryable do
  @moduledoc false

  alias Seraph.Query.Builder

  @spec to_query(
          Seraph.Repo.queryable(),
          Seraph.Schema.Node.t() | map,
          Seraph.Schema.Node.t() | map,
          Keyword.t() | map,
          atom()
        ) :: Seraph.Query.t()
  def to_query(queryable, start_struct_or_data, end_struct_or_data, rel_properties, :match) do
    rel_properties = Enum.into(rel_properties, %{})

    %{entity: relationship, params: query_params} =
      Builder.Entity.Relationship.from_queryable(
        queryable,
        start_struct_or_data,
        end_struct_or_data,
        rel_properties,
        "match__"
      )

    {_, func_atom, _, _} =
      Process.info(self(), :current_stacktrace)
      |> elem(1)
      |> Enum.at(2)

    literal =
      case func_atom do
        :get ->
          "get(#{inspect(start_struct_or_data)}, #{inspect(end_struct_or_data)})"

        :get_by ->
          "get_by(#{inspect(start_struct_or_data)}, #{inspect(end_struct_or_data)}, #{
            inspect(rel_properties)
          })"
      end

    %Seraph.Query{
      identifiers: Map.put(%{}, "rel", relationship),
      operations: [
        match: %Builder.Match{
          entities: [relationship]
        },
        return: %Builder.Return{
          raw_variables: [
            %Builder.Entity.EntityData{
              entity_identifier: :rel
            }
          ]
        }
      ],
      literal: [literal],
      params: query_params
    }
  end

  def to_query(queryable, start_struct_or_data, end_struct_or_data, rel_properties, :match_create) do
    rel_properties = Enum.into(rel_properties, %{})

    %{entity: relationship, params: query_params} =
      Builder.Entity.Relationship.from_queryable(
        queryable,
        start_struct_or_data,
        end_struct_or_data,
        rel_properties,
        "match_create__"
      )

    literal =
      "create(%#{queryable}{start: #{inspect(start_struct_or_data)}, end:#{
        inspect(end_struct_or_data)
      }, properties: #{inspect(rel_properties)}})"

    identifiers = %{
      "rel" => relationship,
      "start" => relationship.start,
      "end" => relationship.end
    }

    rel_to_create =
      relationship
      |> Map.put(:start, %Builder.Entity.Node{
        identifier: relationship.start.identifier,
        queryable: Seraph.Node
      })
      |> Map.put(:end, %Builder.Entity.Node{
        identifier: relationship.end.identifier,
        queryable: Seraph.Node
      })

    %Seraph.Query{
      identifiers: identifiers,
      operations: [
        match: %Builder.Match{
          entities: [relationship.start, relationship.end]
        },
        create: %Builder.Create{
          raw_entities: [rel_to_create]
        },
        return: %Builder.Return{
          raw_variables: [
            %Builder.Entity.EntityData{
              entity_identifier: :rel
            },
            %Builder.Entity.EntityData{
              entity_identifier: :start
            },
            %Builder.Entity.EntityData{
              entity_identifier: :end
            }
          ]
        }
      ],
      literal: [literal],
      params: query_params
    }
  end

  def to_query(queryable, start_struct_or_data, end_struct_or_data, rel_properties, :create) do
    rel_properties = Enum.into(rel_properties, %{})

    %{entity: relationship, params: query_params} =
      Builder.Entity.Relationship.from_queryable(
        queryable,
        start_struct_or_data,
        end_struct_or_data,
        rel_properties,
        "match_create__"
      )

    literal =
      "create(%#{queryable}{start: #{inspect(start_struct_or_data)}, end:#{
        inspect(end_struct_or_data)
      }, properties: #{inspect(rel_properties)}})"

    identifiers = %{
      "rel" => relationship,
      "start" => relationship.start,
      "end" => relationship.end
    }

    %Seraph.Query{
      identifiers: identifiers,
      operations: [
        create: %Builder.Create{
          raw_entities: [relationship]
        },
        return: %Builder.Return{
          raw_variables: [
            %Builder.Entity.EntityData{
              entity_identifier: :rel
            },
            %Builder.Entity.EntityData{
              entity_identifier: :start
            },
            %Builder.Entity.EntityData{
              entity_identifier: :end
            }
          ]
        }
      ],
      literal: [literal],
      params: query_params
    }
  end

  @doc """
  Fetch a single struct from the Neo4j datababase with the given start and end node data/struct.

  Returns `nil` if no result was found
  """
  @spec get(
          Seraph.Repo.t(),
          Seraph.Repo.queryable(),
          Seraph.Schema.Node.t() | map,
          Seraph.Schema.Node.t() | map
        ) :: nil | Seraph.Schema.Relationship.t()
  def get(repo, queryable, start_struct_or_data, end_struct_or_data) do
    results =
      to_query(queryable, start_struct_or_data, end_struct_or_data, %{}, :match)
      |> repo.all(relationship_result: :full)

    case length(results) do
      0 ->
        nil

      1 ->
        List.first(results)["rel"]

      count ->
        raise Seraph.MultipleRelationshipsError,
          queryable: queryable,
          count: count,
          start_node: queryable.__schema__(:start_node),
          end_node: queryable.__schema__(:end_node),
          params: %{
            start: start_struct_or_data,
            end: end_struct_or_data
          }
    end
  end

  @doc """
  Same as `get/4` but raises when no result is found.
  """
  @spec get!(
          Seraph.Repo.t(),
          Seraph.Repo.queryable(),
          Seraph.Schema.Node.t() | map,
          Seraph.Schema.Node.t() | map
        ) :: Seraph.Schema.Relationship.t()
  def get!(repo, queryable, start_struct_or_data, end_struct_or_data) do
    case get(repo, queryable, start_struct_or_data, end_struct_or_data) do
      nil ->
        params = %{
          start: start_struct_or_data,
          end: end_struct_or_data
        }

        raise Seraph.NoResultsError, queryable: queryable, function: :get!, params: params

      result ->
        result
    end
  end

  @doc """
  Fetch a single struct from the Neo4j datababase with the given data.

  Returns `nil` if no result was found
  """
  @spec get_by(
          Seraph.Repo.t(),
          Seraph.Repo.queryable(),
          Keyword.t() | map,
          Keyword.t() | map,
          Keyword.t() | map
        ) :: nil | Seraph.Schema.Relationship.t()
  def get_by(repo, queryable, start_node_clauses, end_node_clauses, relationship_clauses) do
    results =
      to_query(queryable, start_node_clauses, end_node_clauses, relationship_clauses, :match)
      |> repo.all(relationship_result: :full)

    case length(results) do
      0 ->
        nil

      1 ->
        List.first(results)["rel"]

      count ->
        raise Seraph.MultipleRelationshipsError,
          queryable: queryable,
          count: count,
          start_node: queryable.__schema__(:start_node),
          end_node: queryable.__schema__(:end_node),
          params: %{
            start: start_node_clauses,
            end: end_node_clauses
          }
    end
  end

  @doc """
  Same as `get/5` but raise when no result is found.
  """
  @spec get_by!(
          Seraph.Repo.t(),
          Seraph.Repo.queryable(),
          Keyword.t() | map,
          Keyword.t() | map,
          Keyword.t() | map
        ) ::
          Seraph.Schema.Relationship.t()
  def get_by!(repo, queryable, start_node_clauses, end_node_clauses, relationship_clauses) do
    case get_by(repo, queryable, start_node_clauses, end_node_clauses, relationship_clauses) do
      nil ->
        raise Seraph.NoResultsError,
          queryable: queryable,
          function: :get!,
          params: %{
            start_node: start_node_clauses,
            end_node: end_node_clauses,
            relationship: relationship_clauses
          }

      result ->
        result
    end
  end
end
