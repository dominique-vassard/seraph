defmodule Neo4jex.Repo.Queryable do
  alias Neo4jex.Query
  alias Neo4jex.Query.Condition
  alias Neo4jex.Query.Planner

  @type queryable :: module
  @type sets_data :: %{
          sets: [Query.SetExpr.t()],
          params: map
        }

  @type merge_keys_data :: %{
          where: nil | Condition.t(),
          params: map
        }

  @spec get(Neo4jex.Repo.t(), queryable, any) :: nil | Neo4jex.Schema.Node.t()
  def get(repo, queryable, id_value) do
    id_field = identifier_field(queryable)

    node_to_get = %Query.NodeExpr{
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
        %Query.FieldExpr{
          variable: node_to_get.variable,
          name: property,
          alias: Atom.to_string(property)
        }
      end)

    id_expr = %Query.Fragment{
      expr: "id(#{node_to_get.variable})",
      alias: "__id__"
    }

    {statement, params} =
      Query.new()
      |> Query.match([node_to_get])
      |> Query.where(condition)
      |> Query.params(params)
      |> Query.return(%Query.ReturnExpr{fields: [id_expr | fields]})
      |> Query.to_string()

    {:ok, results} = Planner.query(repo, statement, params)

    case List.first(results) do
      nil ->
        nil

      res ->
        struct(queryable, Enum.map(res, fn {k, v} -> {String.to_atom(k), v} end))
    end
  end

  @spec set(Neo4jex.Repo.t(), queryable, Ecto.Changeset.t()) :: Neo4jex.Schema.Node.t()
  def set(repo, queryable, %Ecto.Changeset{valid?: true} = changeset) do
    node_to_set = %Query.NodeExpr{
      variable: "n",
      labels: [queryable.__schema__(:primary_label)]
    }

    changes = Map.drop(changeset.changes, [:additional_labels])
    sets = build_set(node_to_set, changes)
    merge_keys_data = build_where_from_merge_keys(node_to_set, queryable, changeset.data)
    label_ops = build_label_operation(node_to_set, queryable, changeset)

    return_fields =
      Enum.map(changes, fn {property, _} ->
        %Query.FieldExpr{
          variable: node_to_set.variable,
          name: property,
          alias: Atom.to_string(property)
        }
      end)

    label_field = %Query.Fragment{
      expr: "labels(#{node_to_set.variable})",
      alias: "additional_labels"
    }

    {statement, params} =
      Query.new()
      |> Query.match([node_to_set])
      |> Query.set(sets.sets)
      |> Query.label_ops(label_ops)
      |> Query.where(merge_keys_data.where)
      |> Query.return(%Query.ReturnExpr{fields: [label_field | return_fields]})
      |> Query.params(Map.merge(merge_keys_data.params, sets.params))
      |> Query.to_string()

    {:ok, results} = Planner.query(repo, statement, params)

    case List.first(results) do
      nil ->
        changeset.data

      result ->
        Enum.reduce(result, changeset.data, fn {property, value}, data ->
          case property do
            "additional_labels" ->
              Map.put(data, :additional_labels, value -- [queryable.__schema__(:primary_label)])

            prop ->
              Map.put(data, String.to_atom(prop), value)
          end
        end)
    end
  end

  def set(_, _, %Ecto.Changeset{valid?: false} = changeset) do
    {:error, changeset}
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

  @spec build_set(Query.NodeExpr.t(), Neo4jex.Schema.Node.t()) :: sets_data()
  defp build_set(entity, data) do
    Enum.reduce(data, %{sets: [], params: %{}}, fn {prop_name, prop_value}, sets_data ->
      bound_name = entity.variable <> "_" <> Atom.to_string(prop_name)

      set = %Query.SetExpr{
        field: %Query.FieldExpr{
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

  @spec build_where_from_merge_keys(Query.NodeExpr.t(), queryable, Neo4jex.Schema.Node.t()) ::
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

  @spec build_label_operation(Query.NodeExpr.t(), queryable, Ecto.Changeset.t()) :: [
          Query.LabelOperationExpr.t()
        ]
  defp build_label_operation(entity, queryable, %{changes: %{additional_labels: _}} = changeset) do
    additional_labels =
      changeset.changes[:additional_labels] -- [queryable.__schema__(:primary_label)]

    [
      %Query.LabelOperationExpr{
        variable: entity.variable,
        set: additional_labels -- changeset.data.additional_labels,
        remove: changeset.data.additional_labels -- additional_labels
      }
    ]
  end

  defp build_label_operation(_entity, _queryable, _changeset) do
    []
  end
end
