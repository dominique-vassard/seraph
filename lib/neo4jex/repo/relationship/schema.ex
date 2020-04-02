defmodule Neo4jex.Repo.Relationship.Schema do
  alias Neo4jex.Query.{Builder, Planner}

  @spec create(
          Neo4jex.Repo.t(),
          Neo4jex.Schema.Relationship.t(),
          Neo4jex.Repo.Schema.create_options()
        ) ::
          {:ok, Neo4jex.Schema.Relationship.t()}
  def create(repo, rel_data, [node_creation: true] = opts) do
    start_node = repo.create!(rel_data.start_node, opts)
    end_node = repo.create!(rel_data.end_node, opts)

    new_rel_data =
      rel_data
      |> Map.put(:start_node, start_node)
      |> Map.put(:end_node, end_node)

    create(repo, new_rel_data, Keyword.drop(opts, [:node_creation]))
  end

  def create(repo, %{__struct__: queryable} = rel_data, _opts) do
    persisted_properties = queryable.__schema__(:persisted_properties)

    {start_node, start_params} = build_node_match("start", rel_data.start_node)
    {end_node, end_params} = build_node_match("end", rel_data.end_node)

    relationship = %Builder.RelationshipExpr{
      start: %Builder.NodeExpr{
        variable: start_node.variable
      },
      end: %Builder.NodeExpr{
        variable: end_node.variable
      },
      type: rel_data.type,
      variable: "rel"
    }

    sets = build_sets(relationship.variable, rel_data, persisted_properties)

    relationship_params =
      start_params
      |> Map.merge(end_params)
      |> Map.merge(sets.params)

    {statement, params} =
      Builder.new()
      |> Builder.match([start_node, end_node])
      |> Builder.create([relationship])
      |> Builder.set(sets.sets)
      |> Builder.return(%Builder.ReturnExpr{
        fields: [relationship]
      })
      |> Builder.params(relationship_params)
      |> Builder.to_string()

    {:ok, [%{"rel" => created_relationship}]} = Planner.query(repo, statement, params)

    {:ok, Map.put(rel_data, :__id__, created_relationship.id)}
  end

  @spec merge(
          Neo4jex.Repo.t(),
          Neo4jex.Schema.Relationship.t(),
          Neo4jex.Repo.Schema.merge_options()
        ) :: {:ok, Neo4jex.Schema.Relationship.t()}
  def merge(repo, rel_data, [node_creation: true] = opts) do
    start_node = repo.create!(rel_data.start_node, opts)
    end_node = repo.create!(rel_data.end_node, opts)

    new_rel_data =
      rel_data
      |> Map.put(:start_node, start_node)
      |> Map.put(:end_node, end_node)

    merge(repo, new_rel_data, Keyword.drop(opts, [:node_creation]))
  end

  def merge(repo, %{__struct__: queryable} = rel_data, _opts) do
    persisted_properties = queryable.__schema__(:persisted_properties)

    {start_node, start_params} = build_node_match("start", rel_data.start_node)
    {end_node, end_params} = build_node_match("end", rel_data.end_node)

    relationship = %Builder.RelationshipExpr{
      start: %Builder.NodeExpr{
        variable: start_node.variable
      },
      end: %Builder.NodeExpr{
        variable: end_node.variable
      },
      type: rel_data.type,
      variable: "rel"
    }

    sets = build_sets(relationship.variable, rel_data, persisted_properties)

    relationship_params =
      start_params
      |> Map.merge(end_params)
      |> Map.merge(sets.params)

    {statement, params} =
      Builder.new()
      |> Builder.match([start_node, end_node])
      |> Builder.merge([
        %Builder.MergeExpr{
          expr: relationship
        }
      ])
      |> Builder.set(sets.sets)
      |> Builder.return(%Builder.ReturnExpr{
        fields: [relationship]
      })
      |> Builder.params(relationship_params)
      |> Builder.to_string()

    {:ok, [%{"rel" => created_relationship}]} = Planner.query(repo, statement, params)

    {:ok, Map.put(rel_data, :__id__, created_relationship.id)}
  end

  @spec delete(Neo4jex.Repo.t(), Ecto.Changeset.t()) :: {:ok, Neo4jex.Schema.Relationship.t()}
  def delete(repo, changeset) do
    data =
      changeset
      |> Map.put(:changes, %{})
      |> Neo4jex.Changeset.apply_changes()

    queryable = data.__struct__

    {start_node, start_params} = build_node_match("start", data.start_node)
    {end_node, end_params} = build_node_match("end", data.end_node)

    relationship = %Builder.RelationshipExpr{
      start: start_node,
      end: end_node,
      variable: "rel",
      type: data.type
    }

    {statement, params} =
      Builder.new(:delete)
      |> Builder.match([relationship])
      |> Builder.delete([relationship])
      |> Builder.params(Map.merge(start_params, end_params))
      |> Builder.to_string()

    {:ok, %{stats: stats}} = Planner.query(repo, statement, params, with_stats: true)

    case stats do
      %{"relationships-deleted" => 1} ->
        {:ok, data}

      [] ->
        raise Neo4jex.DeletionError, queryable: queryable, data: data
    end
  end

  @spec build_node_match(String.t(), Neo4jex.Schema.Node.t()) :: {Builder.NodeExpr.t(), map()}
  defp build_node_match(_, %Ecto.Changeset{}) do
    raise ArgumentError, "start node and end node should be Queryable, not Changeset"
  end

  defp build_node_match(variable, node_data) do
    %{__struct__: queryable} = node_data
    identifier = Neo4jex.Repo.Node.Helper.identifier_field(queryable)
    id_value = Map.fetch!(node_data, identifier)

    bound_name = variable <> "_" <> Atom.to_string(identifier)

    match = %Builder.NodeExpr{
      variable: variable,
      labels: [
        queryable.__schema__(:primary_label)
        | Map.get(node_data, :additional_labels, [])
      ],
      properties: Map.put(%{}, identifier, bound_name)
    }

    params = Map.put(%{}, String.to_atom(bound_name), id_value)

    {match, params}
  end

  defp build_sets(variable, rel_data, persisted_properties) do
    rel_data
    |> Map.from_struct()
    |> Enum.filter(fn {k, _} ->
      k in persisted_properties
    end)
    |> Enum.reduce(%{sets: [], params: %{}}, fn {prop_name, prop_value}, sets_data ->
      bound_name = variable <> "_" <> Atom.to_string(prop_name)

      set = %Builder.SetExpr{
        field: %Builder.FieldExpr{
          variable: variable,
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
end
