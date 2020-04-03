defmodule Neo4jex.Repo.Queryable do
  @type t :: module

  @spec get(Neo4jex.Repo.t(), Queryable.t(), any) :: nil | Neo4jex.Schema.Node.t()
  def get(repo, queryable, id_value) do
    Neo4jex.Repo.Node.Queryable.get(repo, queryable, id_value)
  end

  @spec get(
          Neo4jex.Repo.t(),
          Queryable.t(),
          Neo4jex.Schema.Node.t() | map,
          Neo4jex.Schema.Node.t() | map
        ) :: nil | Neo4jex.Schema.Relationship.t()
  def get(repo, queryable, start_struct_or_data, end_struct_or_data) do
    Neo4jex.Repo.Relationship.Queryable.get(
      repo,
      queryable,
      start_struct_or_data,
      end_struct_or_data
    )
  end

  @spec get!(Neo4jex.Repo.t(), Queryable.t(), any) :: Neo4jex.Schema.Node.t()
  def get!(repo, queryable, id_value) do
    case get(repo, queryable, id_value) do
      nil -> raise Neo4jex.NoResultsError, queryable: queryable, function: :get!, params: id_value
      result -> result
    end
  end

  @spec get!(
          Neo4jex.Repo.t(),
          Queryable.t(),
          Neo4jex.Schema.Node.t() | map,
          Neo4jex.Schema.Node.t() | map
        ) :: Neo4jex.Schema.Relationship.t()
  def get!(repo, queryable, start_struct_or_data, end_struct_or_data) do
    case get(repo, queryable, start_struct_or_data, end_struct_or_data) do
      nil ->
        params = %{
          start: start_struct_or_data,
          end: end_struct_or_data
        }

        raise Neo4jex.NoResultsError, queryable: queryable, function: :get!, params: params

      result ->
        result
    end
  end
end
