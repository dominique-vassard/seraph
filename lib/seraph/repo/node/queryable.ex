defmodule Seraph.Repo.Node.Queryable do
  @moduledoc false
  alias Seraph.Query.{Builder, Condition, Planner}
  alias Seraph.Repo.Helper

  @doc """
  Fetch a single struct from the Neo4j datababase with the given identifier value.

  Returns `nil` if no result was found
  """
  @spec get(Seraph.Repo.t(), Seraph.Repo.queryable(), any) :: nil | Seraph.Schema.Node.t()
  def get(repo, queryable, id_value) do
    id_field = Seraph.Repo.Helper.identifier_field(queryable)

    node_to_get = %Builder.NodeExpr{
      variable: "n",
      labels: [queryable.__schema__(:primary_label)],
      properties: Map.put(%{}, id_field, Atom.to_string(id_field))
    }

    params = Map.put(%{}, id_field, id_value)

    {statement, params} =
      Builder.new()
      |> Builder.match([node_to_get])
      |> Builder.params(params)
      |> Builder.return(%Builder.ReturnExpr{fields: [node_to_get]})
      |> Builder.to_string()

    {:ok, results} = Planner.query(repo, statement, params)

    case List.first(results) do
      nil ->
        nil

      res ->
        Helper.build_node(queryable, res["n"])
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
    {additional_labels, cond_clauses} =
      clauses
      |> Enum.to_list()
      |> Keyword.pop(:additionalLabels, [])

    node_to_get = %Builder.NodeExpr{
      variable: "n",
      labels: [queryable.__schema__(:primary_label) | additional_labels]
    }

    conditions =
      Enum.reduce(cond_clauses, %{condition: nil, params: %{}}, fn {prop_key, prop_value},
                                                                   clauses ->
        condition = %Condition{
          source: node_to_get.variable,
          field: prop_key,
          operator: :==,
          value: Atom.to_string(prop_key)
        }

        %{
          clauses
          | condition: Condition.join_conditions(clauses.condition, condition),
            params: Map.put(clauses.params, prop_key, prop_value)
        }
      end)

    {statement, params} =
      Builder.new()
      |> Builder.match([node_to_get])
      |> Builder.where(conditions.condition)
      |> Builder.return(%Builder.ReturnExpr{
        fields: [node_to_get]
      })
      |> Builder.params(conditions.params)
      |> Builder.to_string()

    {:ok, results} = Planner.query(repo, statement, params)

    case length(results) do
      0 ->
        nil

      1 ->
        Seraph.Repo.Helper.build_node(queryable, List.first(results)["n"])

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
