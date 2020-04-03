defmodule Neo4jex.Repo.Queryable do
  @type t :: module

  @spec get(Neo4jex.Repo.t(), Queryable.t(), any) :: nil | Neo4jex.Schema.Node.t()
  def get(repo, queryable, id_value) do
    Neo4jex.Repo.Node.Queryable.get(repo, queryable, id_value)
  end

  @spec get!(Neo4jex.Repo.t(), Queryable.t(), any) :: Neo4jex.Schema.Node.t()
  def get!(repo, queryable, id_value) do
    case get(repo, queryable, id_value) do
      nil -> raise Neo4jex.NoResultsError, queryable: queryable, function: :get!, params: id_value
      result -> result
    end
  end
end
