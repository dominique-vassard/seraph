defmodule Neo4jex.Repo.Queryable do
  alias Neo4jex.Query.{Builder, Condition, Planner}

  @type t :: module
  @type sets_data :: %{
          sets: [Builder.SetExpr.t()],
          params: map
        }

  @type merge_keys_data :: %{
          where: nil | Condition.t(),
          params: map
        }

  @spec get(Neo4jex.Repo.t(), Queryable.t(), any) :: nil | Neo4jex.Schema.Node.t()
  def get(repo, queryable, id_value) do
    id_field = identifier_field(queryable)

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

  @spec set(Neo4jex.Repo.t(), Ecto.Changeset.t()) ::
          {:ok, Neo4jex.Schema.Node.t()}
          | {:ok, Neo4jex.Schema.Relationship.t()}
          | {:error, Ecto.Changeset.t()}
  def set(
        repo,
        %Ecto.Changeset{valid?: true, data: %{__meta__: %Neo4jex.Schema.Node.Metadata{}}} =
          changeset
      ) do
    Neo4jex.Repo.Node.Queryable.set(repo, changeset)
  end

  def set(_, %Ecto.Changeset{valid?: false} = changeset) do
    {:error, changeset}
  end

  @spec get!(Neo4jex.Repo.t(), Queryable.t(), any) :: Neo4jex.Schema.Node.t()
  def get!(repo, queryable, id_value) do
    case get(repo, queryable, id_value) do
      nil -> raise Neo4jex.NoResultsError, queryable: queryable, function: :get!, params: id_value
      result -> result
    end
  end

  @spec set!(Neo4jex.Repo.t(), Ecto.Changeset.t()) :: Neo4jex.Schema.Node.t()
  def set!(repo, changeset) do
    case set(repo, changeset) do
      {:ok, result} ->
        result

      {:error, changeset} ->
        raise Neo4jex.InvalidChangesetError, action: :set, changeset: changeset
    end
  end

  @spec identifier_field(Queryable.t()) :: atom
  defp identifier_field(queryable) do
    case queryable.__schema__(:identifier) do
      {field, _, _} ->
        field

      _ ->
        raise ArgumentError, "Impossible to use get/2 on a schema without identifier."
    end
  end
end
