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

    sets = build_sets(relationship.variable, Map.from_struct(rel_data), persisted_properties)

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

    sets = build_sets(relationship.variable, Map.from_struct(rel_data), persisted_properties)

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

  @spec set(Neo4jex.Repo.t(), Ecto.Changeset.t(), Keyword.t()) ::
          {:ok, Neo4jex.Schema.Relationship.t()}

  def set(repo, changeset, [node_creation: true] = opts) do
    new_changeset =
      changeset
      |> pre_create_nodes(repo, :start_node, opts)
      |> pre_create_nodes(repo, :end_node, opts)

    set(repo, new_changeset, Keyword.drop(opts, [:node_creation]))
  end

  def set(repo, changeset, _opts) do
    %{__struct__: queryable} = changeset.data
    persisted_properties = queryable.__schema__(:persisted_properties)
    {start_node, start_params} = build_node_match("start", changeset.data.start_node)
    {end_node, end_params} = build_node_match("end", changeset.data.end_node)

    relationship = %Builder.RelationshipExpr{
      variable: "rel",
      start: Map.drop(start_node, [:properties]),
      end: Map.drop(end_node, [:properties]),
      type: changeset.data.type,
      alias: "updated_rel"
    }

    sets = build_sets(relationship.variable, changeset.changes, persisted_properties)

    {new_start, new_start_params} =
      case Map.get(changeset.changes, :start_node) do
        nil ->
          {nil, %{}}

        new_start_node ->
          build_node_match("new_start", new_start_node)
      end

    {new_end, new_end_params} =
      case Map.get(changeset.changes, :end_node) do
        nil ->
          {nil, %{}}

        new_end_node ->
          build_node_match("new_end", new_end_node)
      end

    new_relationship = build_new_relationship(relationship, new_start, new_end)

    matches =
      [start_node, end_node, relationship, new_start, new_end]
      |> Enum.reject(&is_nil/1)

    rel_params =
      sets.params
      |> Map.merge(start_params)
      |> Map.merge(end_params)
      |> Map.merge(new_start_params)
      |> Map.merge(new_end_params)

    pre_query =
      Builder.new(:set)
      |> Builder.match(matches)
      |> Builder.set(sets.sets)
      |> Builder.return(%Builder.ReturnExpr{
        fields: [new_relationship || relationship]
      })
      |> Builder.params(rel_params)

    query =
      if new_relationship do
        pre_query
        |> Builder.delete([relationship])
        |> Builder.merge([
          %Builder.MergeExpr{
            expr: new_relationship
          }
        ])
      else
        pre_query
      end

    {statement, params} = Builder.to_string(query)

    {:ok, [%{"updated_rel" => updated_rel}]} = Planner.query(repo, statement, params)

    result =
      Ecto.Changeset.apply_changes(changeset)
      |> Map.put(:__id__, updated_rel.id)

    {:ok, result}
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

  defp build_new_relationship(_, nil, nil) do
    nil
  end

  defp build_new_relationship(relationship, new_start, nil) do
    %Builder.RelationshipExpr{
      variable: "new_rel",
      start: new_start |> Map.drop([:properties, :labels]),
      end: relationship.end |> Map.drop([:properties, :labels]),
      type: relationship.type,
      alias: "updated_rel"
    }
  end

  defp build_new_relationship(relationship, nil, new_end) do
    %Builder.RelationshipExpr{
      variable: "new_rel",
      start: relationship.start |> Map.drop([:properties, :labels]),
      end: new_end |> Map.drop([:properties, :labels]),
      type: relationship.type,
      alias: "updated_rel"
    }
  end

  defp build_new_relationship(relationship, new_start, new_end) do
    %Builder.RelationshipExpr{
      variable: "new_rel",
      start: new_start |> Map.drop([:properties, :labels]),
      end: new_end |> Map.drop([:properties, :labels]),
      type: relationship.type,
      alias: "updated_rel"
    }
  end

  @spec pre_create_nodes(
          Ecto.Changeset.t(),
          Neo4jex.Repo.t(),
          :start_node | :end_node,
          Keyword.t()
        ) :: Ecto.Changeset.t()
  defp pre_create_nodes(changeset, repo, changeset_key, opts) do
    case Ecto.Changeset.fetch_change(changeset, changeset_key) do
      {:ok, %Ecto.Changeset{} = start_cs} ->
        new_start = repo.create!(start_cs, opts)
        Ecto.Changeset.put_change(changeset, changeset_key, new_start)

      {:ok, _} ->
        changeset

      :error ->
        changeset
    end
  end
end
