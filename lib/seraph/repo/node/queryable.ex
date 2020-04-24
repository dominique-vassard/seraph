defmodule Seraph.Repo.Node.Queryable do
  @moduledoc false
  alias Seraph.Query.{Builder, Condition, Planner}

  @doc """
  Fetch a single struct from the Neo4j datababase with the given identifier value.

  Returns `nil` if no result was found
  """
  @spec get(Seraph.Repo.t(), Seraph.Repo.queryable(), any) :: nil | Seraph.Schema.Node.t()
  def get(repo, queryable, id_value) do
    id_field = Seraph.Repo.Helper.identifier_field(queryable)

    node_to_get = %Builder.NodeExpr{
      variable: "n",
      labels: [queryable.__schema__(:primary_label)]
    }

    condition = %Condition{
      source: node_to_get.variable,
      field: id_field,
      operator: :==,
      value: Atom.to_string(id_field)
    }

    params = Map.put(%{}, id_field, id_value)

    fields =
      Enum.map(queryable.__schema__(:properties), fn property ->
        %Builder.FieldExpr{
          variable: node_to_get.variable,
          name: property,
          alias: Atom.to_string(property)
        }
      end)

    id_expr = %Builder.Fragment{
      expr: "id(#{node_to_get.variable})",
      alias: "__id__"
    }

    {statement, params} =
      Builder.new()
      |> Builder.match([node_to_get])
      |> Builder.where(condition)
      |> Builder.params(params)
      |> Builder.return(%Builder.ReturnExpr{fields: [id_expr | fields]})
      |> Builder.to_string()

    {:ok, results} = Planner.query(repo, statement, params)

    case List.first(results) do
      nil ->
        nil

      res ->
        struct(queryable, Enum.map(res, fn {k, v} -> {String.to_atom(k), v} end))
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
end
