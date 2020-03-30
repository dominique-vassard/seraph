defmodule Neo4jex.Repo.Node.Schema do
  alias Neo4jex.Query.{Builder, Planner}

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
end
