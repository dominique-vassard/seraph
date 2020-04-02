defmodule Neo4jex.Repo.Node.Schema do
  alias Neo4jex.Query.{Builder, Helper, Planner}

  @spec create(Neo4jex.Repo.t(), Neo4jex.Schema.Node.t(), Neo4jex.Repo.Schema.create_options()) ::
          {:ok, Neo4jex.Schema.Node.t()}
  def create(repo, %{__struct__: queryable} = data, _opts) do
    persisted_properties = queryable.__schema__(:persisted_properties)

    data =
      case queryable.__schema__(:identifier) do
        {:uuid, :string, _} ->
          Map.put(data, :uuid, UUID.uuid4())

        _ ->
          data
      end

    node_to_insert = %Builder.NodeExpr{
      labels: [queryable.__schema__(:primary_label)] ++ data.additionalLabels,
      variable: "n"
    }

    sets =
      data
      |> Map.from_struct()
      |> Enum.filter(fn {k, _} ->
        k in persisted_properties
      end)
      |> Enum.reduce(%{sets: [], params: %{}}, fn {prop_name, prop_value}, sets_data ->
        bound_name = node_to_insert.variable <> "_" <> Atom.to_string(prop_name)

        set = %Builder.SetExpr{
          field: %Builder.FieldExpr{
            variable: node_to_insert.variable,
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

    {cql, params} =
      Builder.new()
      |> Builder.create([node_to_insert])
      |> Builder.set(sets.sets)
      |> Builder.return(%Builder.ReturnExpr{
        fields: [node_to_insert]
      })
      |> Builder.to_string()

    {:ok, [%{"n" => created_node}]} = Planner.query(repo, cql, Map.merge(params, sets.params))

    {:ok, Map.put(data, :__id__, created_node.id)}
  end

  @spec delete(Neo4jex.Repo.t(), Ecto.Changeset.t()) :: {:ok, Neo4jex.Schema.Node.t()}
  def delete(repo, %Ecto.Changeset{valid?: true} = changeset) do
    data =
      changeset
      |> Map.put(:changes, %{})
      |> Neo4jex.Changeset.apply_changes()

    queryable = data.__struct__

    node_to_del = %Builder.NodeExpr{
      variable: "n",
      labels: [queryable.__schema__(:primary_label)]
    }

    merge_keys_data = Helper.build_where_from_merge_keys(node_to_del, queryable, data)

    {statement, params} =
      Builder.new(:delete)
      |> Builder.match([node_to_del])
      |> Builder.delete([node_to_del])
      |> Builder.where(merge_keys_data.where)
      |> Builder.params(merge_keys_data.params)
      |> Builder.to_string()

    {:ok, %{stats: stats}} = Planner.query(repo, statement, params, with_stats: true)

    case stats do
      %{"nodes-deleted" => 1} ->
        {:ok, data}

      [] ->
        raise Neo4jex.DeletionError, queryable: queryable, data: data
    end
  end

  def delete(_, changeset) do
    {:error, changeset}
  end
end
