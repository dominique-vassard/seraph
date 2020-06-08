defmodule Seraph.Repo.Node.Queryable do
  @moduledoc false
  alias Seraph.Query.Builder

  @spec to_query(Seraph.Repo.queryable(), map | Keyword.t()) :: Seraph.Query.t()
  def to_query(queryable, properties \\ %{}) do
    properties = Enum.into(properties, %{})

    %{entity: node, params: query_params} =
      Builder.Entity.Node.from_queryable(queryable, properties, "match__")

    {_, func_atom, _, _} =
      Process.info(self(), :current_stacktrace)
      |> elem(1)
      |> Enum.at(2)

    literal = "#{func_atom}(#{inspect(properties)})"

    %Seraph.Query{
      identifiers: Map.put(%{}, "n", node),
      operations: [
        match: %Builder.Match{
          entities: [node]
        },
        return: %Builder.Return{
          raw_variables: [
            %Builder.Entity.EntityData{
              entity_identifier: :n
            }
          ]
        }
      ],
      literal: [literal],
      params: query_params
    }
  end

  @doc """
  Fetch a single struct from the Neo4j datababase with the given identifier value.

  Returns `nil` if no result was found
  """
  @spec get(Seraph.Repo.t(), Seraph.Repo.queryable(), any) :: nil | Seraph.Schema.Node.t()
  def get(repo, queryable, id_value) do
    id_field = Seraph.Repo.Helper.identifier_field(queryable)

    results =
      queryable
      |> to_query(Map.put(%{}, id_field, id_value))
      |> repo.all()

    case List.first(results) do
      nil ->
        nil

      res ->
        res["n"]
    end
  end

  @doc """
  Same as `get/3` but raises when no result is found.
  """
  @spec get!(Seraph.Repo.t(), Seraph.Repo.queryable(), any) :: Seraph.Schema.Node.t()
  def get!(repo, queryable, id_value) do
    case get(repo, queryable, id_value) do
      nil -> raise Seraph.NoResultsError, queryable: queryable, function: :get!, params: id_value
      result -> result
    end
  end

  @doc """
  Fetch a single struct from the Neo4j datababase with the given data.

  Returns `nil` if no result was found
  """
  @spec get_by(Seraph.Repo.t(), Seraph.Repo.queryable(), Keyword.t() | map) ::
          nil | Seraph.Schema.Node.t()
  def get_by(repo, queryable, clauses) do
    results =
      queryable
      |> to_query(clauses)
      |> repo.all()

    case length(results) do
      0 ->
        nil

      1 ->
        List.first(results)["n"]

      count ->
        raise Seraph.MultipleNodesError, queryable: queryable, count: count, params: clauses
    end
  end

  @doc """
  Same as `get/3` but raises when no result is found.
  """
  @spec get_by!(Seraph.Repo.t(), Seraph.Repo.queryable(), Keyword.t() | map) ::
          Seraph.Schema.Node.t()
  def get_by!(repo, queryable, clauses) do
    case get_by(repo, queryable, clauses) do
      nil -> raise Seraph.NoResultsError, queryable: queryable, function: :get!, params: clauses
      result -> result
    end
  end
end
