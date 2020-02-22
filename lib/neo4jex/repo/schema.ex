defmodule Neo4jex.Repo.Schema do
  alias Neo4jex.Query.{Builder, Planner}

  @type merge_options :: [on_create: Ecto.Changeset.t(), on_match: Ecto.Changeset.t()]

  @spec create(Neo4jex.Repo.t(), struct | Neo4jex.Schema.Node.t() | Ecto.Changeset.t()) ::
          {:ok, Neo4jex.Schema.Node.t()} | {:error, Ecto.Changeset.t()}
  def create(repo, %{__struct__: schema, __meta__: %Neo4jex.Schema.Node.Metadata{}} = data) do
    persisted_properties = schema.__schema__(:persisted_properties)

    data =
      case schema.__schema__(:identifier) do
        {:uuid, :string, _} ->
          Map.put(data, :uuid, UUID.uuid4())

        _ ->
          data
      end

    node_to_insert = %Builder.NodeExpr{
      labels: [schema.__schema__(:primary_label)] ++ data.additional_labels,
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

  def create(repo, %Ecto.Changeset{valid?: true} = changeset) do
    cs =
      changeset
      |> Ecto.Changeset.apply_changes()

    create(repo, cs)
  end

  def create(_, %Ecto.Changeset{valid?: false} = changeset) do
    {:error, changeset}
  end
end
