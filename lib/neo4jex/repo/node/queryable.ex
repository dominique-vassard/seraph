defmodule Neo4jex.Repo.Node.Queryable do
  alias Neo4jex.Query.{Builder, Helper, Planner}

  @spec set(Neo4jex.Repo.t(), Ecto.Changeset.t()) :: {:ok, Neo4jex.Schema.Node.t()}
  def set(repo, changeset) do
    %{__struct__: queryable} = changeset.data

    node_to_set = %Builder.NodeExpr{
      variable: "n",
      labels: [queryable.__schema__(:primary_label)]
    }

    changes = Map.drop(changeset.changes, [:additionalLabels])
    sets = build_set(node_to_set, changes)
    merge_keys_data = Helper.build_where_from_merge_keys(node_to_set, queryable, changeset.data)
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

  @spec build_set(Builder.NodeExpr.t(), Neo4jex.Schema.Node.t()) ::
          Neo4jex.Repo.Queryable.sets_data()
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

  @spec build_label_operation(Builder.NodeExpr.t(), Queryable.t(), Ecto.Changeset.t()) :: [
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
