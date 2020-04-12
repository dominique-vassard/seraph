defmodule Seraph.Repo.Queryable do
  @moduledoc false

  @type t :: module

  @doc """
  Fetch a single struct from the Neo4j datababase with the given identifier value.

  Returns `nil` if no result was found
  """
  @spec get(Seraph.Repo.t(), Queryable.t(), any) :: nil | Seraph.Schema.Node.t()
  def get(repo, queryable, id_value) do
    Seraph.Repo.Node.Queryable.get(repo, queryable, id_value)
  end

  @doc """
  Same as `get/3` but raises when no result is found.
  """
  @spec get!(Seraph.Repo.t(), Queryable.t(), any) :: Seraph.Schema.Node.t()
  def get!(repo, queryable, id_value) do
    case get(repo, queryable, id_value) do
      nil -> raise Seraph.NoResultsError, queryable: queryable, function: :get!, params: id_value
      result -> result
    end
  end

  @doc """
  Fetch a single struct from the Neo4j datababase with the given start and end node data/struct.

  Returns `nil` if no result was found
  """
  @spec get(
          Seraph.Repo.t(),
          Queryable.t(),
          Seraph.Schema.Node.t() | map,
          Seraph.Schema.Node.t() | map
        ) :: nil | Seraph.Schema.Relationship.t()
  def get(repo, queryable, start_struct_or_data, end_struct_or_data) do
    Seraph.Repo.Relationship.Queryable.get(
      repo,
      queryable,
      start_struct_or_data,
      end_struct_or_data
    )
  end

  @doc """
  Same as `get/4` but raises when no result is found.
  """
  @spec get!(
          Seraph.Repo.t(),
          Queryable.t(),
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
end
