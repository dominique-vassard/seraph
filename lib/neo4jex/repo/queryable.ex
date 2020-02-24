defmodule Neo4jex.Repo.Queryable do
  alias Neo4jex.Query.{Builder, Condition, Planner}

  @type queryable :: module
  @type sets_data :: %{
          sets: [Builder.SetExpr.t()],
          params: map
        }

  @type merge_keys_data :: %{
          where: nil | Condition.t(),
          params: map
        }

  @spec get(Neo4jex.Repo.t(), queryable, any) :: nil | Neo4jex.Schema.Node.t()
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
          {:ok, Neo4jex.Schema.Node.t()} | {:error, Ecto.Changeset.t()}
  def set(repo, %Ecto.Changeset{valid?: true} = changeset) do
    %{__struct__: queryable} = changeset.data

    node_to_set = %Builder.NodeExpr{
      variable: "n",
      labels: [queryable.__schema__(:primary_label)]
    }

    changes = Map.drop(changeset.changes, [:additionalLabels])
    sets = build_set(node_to_set, changes)
    merge_keys_data = build_where_from_merge_keys(node_to_set, queryable, changeset.data)
    label_ops = build_label_operation(node_to_set, queryable, changeset)

    return_fields =
      Enum.map(changes, fn {property, _} ->
        %Builder.FieldExpr{
          variable: node_to_set.variable,
          name: property,
          alias: Atom.to_string(property)
        }
      end)

    label_field = %Builder.Fragment{
      expr: "labels(#{node_to_set.variable})",
      alias: "additionalLabels"
    }

    {statement, params} =
      Builder.new()
      |> Builder.match([node_to_set])
      |> Builder.set(sets.sets)
      |> Builder.label_ops(label_ops)
      |> Builder.where(merge_keys_data.where)
      |> Builder.return(%Builder.ReturnExpr{fields: [label_field | return_fields]})
      |> Builder.params(Map.merge(merge_keys_data.params, sets.params))
      |> Builder.to_string()

    {:ok, results} = Planner.query(repo, statement, params)

    formated_res =
      case List.first(results) do
        nil ->
          changeset.data

        result ->
          Enum.reduce(result, changeset.data, fn {property, value}, data ->
            case property do
              "additionalLabels" ->
                Map.put(data, :additionalLabels, value -- [queryable.__schema__(:primary_label)])

              prop ->
                Map.put(data, String.to_atom(prop), value)
            end
          end)
      end

    {:ok, formated_res}
  end

  def set(_, %Ecto.Changeset{valid?: false} = changeset) do
    {:error, changeset}
  end

  @spec get!(Neo4jex.Repo.t(), queryable(), any) :: Neo4jex.Schema.Node.t()
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

  @spec identifier_field(queryable) :: atom
  defp identifier_field(queryable) do
    case queryable.__schema__(:identifier) do
      {field, _, _} ->
        field

      _ ->
        raise ArgumentError, "Impossible to use get/2 on a schema without identifier."
    end
  end

  @spec build_set(Builder.NodeExpr.t(), Neo4jex.Schema.Node.t()) :: sets_data()
  defp build_set(entity, data) do
    Enum.reduce(data, %{sets: [], params: %{}}, fn {prop_name, prop_value}, sets_data ->
      bound_name = entity.variable <> "_" <> Atom.to_string(prop_name)

      set = %Builder.SetExpr{
        field: %Builder.FieldExpr{
          variable: entity.variable,
          name: prop_name
        },
        value: bound_name
      }

      %{
        sets_data
        | sets: [set | sets_data.sets],
          params: Map.put(sets_data.params, String.to_atom(bound_name), prop_value)
      }
    end)
  end

  @spec build_where_from_merge_keys(Builder.NodeExpr.t(), queryable, Neo4jex.Schema.Node.t()) ::
          merge_keys_data()
  defp build_where_from_merge_keys(entity, queryable, data) do
    merge_keys = queryable.__schema__(:merge_keys)

    Enum.reduce(merge_keys, %{where: nil, params: %{}}, fn property, clauses ->
      value = Map.fetch!(data, property)

      bound_name = entity.variable <> "_" <> Atom.to_string(property)

      condition = %Condition{
        source: entity.variable,
        field: property,
        operator: :==,
        value: bound_name
      }

      %{
        clauses
        | where: Condition.join_conditions(clauses.where, condition),
          params: Map.put(clauses.params, String.to_atom(bound_name), value)
      }
    end)
  end

  @spec build_label_operation(Builder.NodeExpr.t(), queryable, Ecto.Changeset.t()) :: [
          Builder.LabelOperationExpr.t()
        ]
  defp build_label_operation(entity, queryable, %{changes: %{additionalLabels: _}} = changeset) do
    additionalLabels =
      changeset.changes[:additionalLabels] -- [queryable.__schema__(:primary_label)]

    [
      %Builder.LabelOperationExpr{
        variable: entity.variable,
        set: additionalLabels -- changeset.data.additionalLabels,
        remove: changeset.data.additionalLabels -- additionalLabels
      }
    ]
  end

  defp build_label_operation(_entity, _queryable, _changeset) do
    []
  end
end
