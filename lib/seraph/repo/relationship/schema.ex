defmodule Seraph.Repo.Relationship.Schema do
  @moduledoc false

  alias Seraph.Query.{Builder, Planner}
  alias Seraph.Query.Builder.Entity

  @doc """
  Creates a relationship in database with the given data.

  Options:
    * `node_creation` - When set to `true`, defined start and end node will be created
  """
  @spec create(
          Seraph.Repo.t(),
          Seraph.Schema.Relationship.t() | Seraph.Changeset.t(),
          Keyword.t()
        ) ::
          {:ok, Seraph.Schema.Relationship.t()} | {:error, Seraph.Changeset.t()}

  def create(_, %Seraph.Changeset{valid?: false} = changeset, _) do
    {:error, changeset}
  end

  def create(repo, %Seraph.Changeset{} = changeset, opts) do
    do_create(repo, Seraph.Changeset.apply_changes(changeset), opts)
  end

  def create(repo, %{__struct__: queryable} = struct, opts) do
    cs_fields =
      queryable.__schema__(:changeset_properties)
      |> Enum.map(fn {key, _} -> key end)

    {data, changes} =
      Enum.reduce(cs_fields, {struct, %{}}, fn cs_field, {data, changes} ->
        case Map.fetch(struct, cs_field) do
          {:ok, value} ->
            {Map.put(data, cs_field, nil), Map.put(changes, cs_field, value)}

          :error ->
            {data, changes}
        end
      end)

    create(repo, Seraph.Changeset.cast(data, changes, cs_fields), opts)
  end

  @doc """
  Same as `create/3` but raise in case of error.
  """
  @spec create!(Seraph.Repo.t(), Seraph.Changeset.t(), Keyword.t()) ::
          Seraph.Schema.Relationship.t()
  def create!(repo, changeset, opts) do
    case create(repo, changeset, opts) do
      {:ok, result} ->
        result

      {:error, changeset} ->
        raise Seraph.InvalidChangesetError, action: :insert, changeset: changeset
    end
  end

  @doc """
  Create or update relationship in database.

  Options:
    * `node_creation` - When set to `true`, defined start and end node will be created
  """
  @spec merge(Seraph.Repo.t(), Seraph.Schema.Relationship.t() | Seraph.Changeset.t(), Keyword.t()) ::
          {:ok, Seraph.Schema.Relationship.t()} | {:error, Seraph.Changeset.t()}

  def merge(repo, %Seraph.Changeset{valid?: true} = changeset, opts) do
    do_merge(repo, Seraph.Changeset.apply_changes(changeset), opts)
  end

  def merge(_, %Seraph.Changeset{valid?: false} = changeset, _) do
    {:error, changeset}
  end

  def merge(repo, %{__struct__: queryable} = struct, opts) do
    cs_fields =
      queryable.__schema__(:changeset_properties)
      |> Enum.map(fn {key, _} -> key end)

    {data, changes} =
      Enum.reduce(cs_fields, {struct, %{}}, fn cs_field, {data, changes} ->
        case Map.fetch(struct, cs_field) do
          {:ok, value} ->
            {Map.put(data, cs_field, nil), Map.put(changes, cs_field, value)}

          :error ->
            {data, changes}
        end
      end)

    merge(repo, Seraph.Changeset.cast(data, changes, cs_fields), opts)
  end

  @doc """
  Same as `merge/3` but raise in case of error.
  """
  @spec merge!(
          Seraph.Repo.t(),
          Seraph.Schema.Relationship.t() | Seraph.Changeset.t(),
          Keyword.t()
        ) :: Seraph.Schema.Relationship.t()
  def merge!(repo, changeset, opts) do
    case merge(repo, changeset, opts) do
      {:ok, result} ->
        result

      {:error, changeset} ->
        raise Seraph.InvalidChangesetError, action: :update, changeset: changeset
    end
  end

  @doc """
  Perform a MERGE on the node in database.

  `nodes_data` must a map like:
  ```
  %{
    start_node: the start node schema data,
    end_node: the end node schema data
  }
  ```
  Options:
    * `:on_create`: a tuple `{data, changeset_fn}` with the data to set on node if it's created.
    Provided data will be validated through given `changeset_fn`
    * `:on_match`: a tuple `{data, changeset_fn}` with the data to set on node if it already exists
    and is matched.
    Provided data will be validated through given `changeset_fn`
  """
  @spec merge(
          Seraph.Repo.t(),
          Seraph.Repo.queryable(),
          Seraph.Schema.Node.t(),
          Seraph.Schema.Node.t(),
          Keyword.t()
        ) ::
          {:ok, Seraph.Schema.Relationship.t()} | {:error, any}
  def merge(repo, queryable, start_node_data, end_node_data, opts) do
    merge_opts = Seraph.Repo.Helper.create_match_merge_opts(opts)
    do_create_match_merge(repo, queryable, start_node_data, end_node_data, merge_opts)
  end

  @doc """
  Same as `merge/4` but raise in case of error
  """
  @spec merge!(
          Seraph.Repo.t(),
          Seraph.Repo.queryable(),
          Seraph.Schema.Node.t(),
          Seraph.Schema.Node.t(),
          Keyword.t()
        ) ::
          Seraph.Schema.Relationship.t()
  def merge!(repo, queryable, start_node_data, end_node_data, opts) do
    case merge(repo, queryable, start_node_data, end_node_data, opts) do
      {:ok, result} ->
        result

      {:error, [on_create: %Seraph.Changeset{} = changeset]} ->
        raise Seraph.InvalidChangesetError, action: :on_create, changeset: changeset

      {:error, [on_match: %Seraph.Changeset{} = changeset]} ->
        raise Seraph.InvalidChangesetError, action: :on_match, changeset: changeset
    end
  end

  @doc """
  Sets new data for relationship.

  Options:
    * `node_creation` - When set to `true`, defined start and end node will be created
  """
  @spec set(Seraph.Repo.t(), Seraph.Changeset.t(), Keyword.t()) ::
          {:ok, Seraph.Schema.Relationship.t()} | {:error, Seraph.Changeset.t()}

  def set(_, %Seraph.Changeset{valid?: false} = changeset, _opts) do
    {:error, changeset}
  end

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

    case Planner.query(repo, statement, params) do
      {:ok, [%{"updated_rel" => updated_rel}]} ->
        result =
          Seraph.Changeset.apply_changes(changeset)
          |> Map.put(:__id__, updated_rel.id)

        {:ok, result}

      {:ok, []} ->
        raise Seraph.StaleEntryError, action: :set, struct: changeset.data
    end
  end

  @doc """
  Same as `set/3` but raise in case of error.
  """
  @spec set!(Seraph.Repo.t(), Seraph.Changeset.t(), Keyword.t()) :: Seraph.Schema.Relationship.t()
  def set!(repo, changeset, opts) do
    case set(repo, changeset, opts) do
      {:ok, result} ->
        result

      {:error, changeset} ->
        raise Seraph.InvalidChangesetError, action: :set, changeset: changeset
    end
  end

  @doc """
  Deletes relationship from database.
  """
  @spec delete(Seraph.Repo.t(), Seraph.Changeset.t()) ::
          {:ok, Seraph.Schema.Relationship.t()} | {:error, Seraph.Changeset.t()}
  def delete(_repo, %Seraph.Changeset{valid?: false} = changeset) do
    {:error, changeset}
  end

  def delete(repo, %Seraph.Changeset{} = changeset) do
    data =
      changeset
      |> Map.put(:changes, %{})
      |> Seraph.Changeset.apply_changes()

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
        raise Seraph.DeletionError, queryable: queryable, data: data
    end
  end

  def delete(repo, struct) do
    delete(repo, Seraph.Changeset.change(struct))
  end

  @doc """
  Same as `delete/2` but raise in case of error.
  """
  @spec delete!(Seraph.Repo.t(), Seraph.Schema.Relationship.t() | Seraph.Changeset.t()) ::
          Seraph.Schema.Relationship.t()
  def delete!(repo, struct_or_changeset) do
    case delete(repo, struct_or_changeset) do
      {:ok, data} ->
        data

      {:error, changeset} ->
        raise Seraph.InvalidChangesetError, action: :delete, changeset: changeset
    end
  end

  defp do_create(repo, rel_data, [node_creation: true] = opts) do
    start_node = Seraph.Repo.Node.Schema.create!(repo, rel_data.start_node, opts)
    end_node = Seraph.Repo.Node.Schema.create!(repo, rel_data.end_node, opts)

    new_rel_data =
      rel_data
      |> Map.put(:start_node, start_node)
      |> Map.put(:end_node, end_node)

    do_create(repo, new_rel_data, Keyword.drop(opts, [:node_creation]))
  end

  defp do_create(repo, %{__struct__: queryable} = rel_data, _opts) do
    persisted_properties = queryable.__schema__(:persisted_properties)

    rel_properties =
      rel_data
      |> Map.from_struct()
      |> Enum.filter(fn {prop_name, prop_value} ->
        prop_name in persisted_properties and not is_nil(prop_value)
      end)

    :ok = check_node(rel_data.start_node)
    :ok = check_node(rel_data.end_node)

    {:ok, [%{"rel" => created_relationship}]} =
      Seraph.Repo.Relationship.Queryable.to_query(
        queryable,
        rel_data.start_node,
        rel_data.end_node,
        rel_properties,
        :match_create
      )
      |> repo.query()

    {:ok, created_relationship}
  end

  defp do_merge(repo, rel_data, [node_creation: true] = opts) do
    start_node = Seraph.Repo.Node.Schema.create!(repo, rel_data.start_node, opts)
    end_node = Seraph.Repo.Node.Schema.create!(repo, rel_data.end_node, opts)

    new_rel_data =
      rel_data
      |> Map.put(:start_node, start_node)
      |> Map.put(:end_node, end_node)

    merge(repo, new_rel_data, Keyword.drop(opts, [:node_creation]))
  end

  defp do_merge(repo, %{__struct__: queryable} = rel_data, _opts) do
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

  defp do_create_match_merge(_, _, _, _, {:error, error}) do
    raise ArgumentError, error
  end

  defp do_create_match_merge(repo, queryable, start_node_data, end_node_data, merge_opts) do
    check_node_data(start_node_data, :start_node)
    check_node_data(end_node_data, :end_node)

    {start_node, start_params} = build_node_merge("start", start_node_data)
    {end_node, end_params} = build_node_merge("end", end_node_data)

    relationship = %Builder.RelationshipExpr{
      start: %Builder.NodeExpr{
        variable: start_node.variable
      },
      end: %Builder.NodeExpr{
        variable: end_node.variable
      },
      type: queryable.__schema__(:type),
      variable: "rel"
    }

    with {:ok, %{sets: on_create_sets, params: on_create_params}} <-
           build_merge_sets(
             queryable,
             relationship,
             :on_create,
             Keyword.get(merge_opts, :on_create)
           ),
         {:ok, %{sets: on_match_sets, params: on_match_params}} <-
           build_merge_sets(
             queryable,
             relationship,
             :on_match,
             Keyword.get(merge_opts, :on_match)
           ) do
      merge = %Builder.MergeExpr{
        expr: relationship,
        on_create: on_create_sets,
        on_match: on_match_sets
      }

      pre_params =
        start_params
        |> Map.merge(end_params)
        |> Map.merge(on_create_params)
        |> Map.merge(on_match_params)

      {statement, params} =
        Builder.new(:merge)
        |> Builder.match([start_node, end_node])
        |> Builder.merge([merge])
        |> Builder.return(%Builder.ReturnExpr{
          fields: [start_node, end_node, relationship]
        })
        |> Builder.params(pre_params)
        |> Builder.to_string()

      {:ok, bare_result} = Planner.query(repo, statement, params)
      result = format_result(queryable, List.first(bare_result))
      {:ok, result}
    else
      {:error, _} = error ->
        error
    end
  end

  defp check_node(%Seraph.Changeset{}) do
    raise ArgumentError, "start node and end node should be Queryable, not Changeset"
  end

  defp check_node(_) do
    :ok
  end

  @spec build_node_match(String.t(), Seraph.Schema.Node.t() | Seraph.Changeset.t()) ::
          {Builder.NodeExpr.t(), map()}
  defp build_node_match(variable, node_data)

  defp build_node_match(_, %Seraph.Changeset{}) do
    raise ArgumentError, "start node and end node should be Queryable, not Changeset"
  end

  defp build_node_match(variable, node_data) do
    %{__struct__: queryable} = node_data
    identifier = Seraph.Repo.Helper.identifier_field!(queryable)
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

  defp build_node_merge(variable, node_data) do
    %{__struct__: queryable} = node_data

    merge_keys_data =
      queryable.__schema__(:merge_keys)
      |> Enum.reduce(%{properties: %{}, params: %{}}, fn merge_key, mk_data ->
        bound_name = variable <> "_" <> Atom.to_string(merge_key)

        %{
          mk_data
          | properties: Map.put(mk_data.properties, merge_key, bound_name),
            params: Map.put(mk_data, String.to_atom(bound_name), Map.fetch!(node_data, merge_key))
        }
      end)

    node_merge = %Builder.NodeExpr{
      variable: variable,
      labels: [
        queryable.__schema__(:primary_label)
        | Map.get(node_data, :additional_labels, [])
      ],
      properties: merge_keys_data.properties
    }

    {node_merge, merge_keys_data.params}
  end

  defp build_merge_sets(queryable, rel_to_merge, operation, {data, changeset_fn}) do
    persisted_properties = queryable.__schema__(:persisted_properties)

    case changeset_fn.(struct(queryable, %{}), data) do
      %Seraph.Changeset{valid?: false} = changeset ->
        {:error, [{operation, changeset}]}

      %Seraph.Changeset{valid?: true} = changeset ->
        sets =
          build_sets(
            rel_to_merge.variable,
            changeset.changes,
            persisted_properties,
            Atom.to_string(operation)
          )

        {:ok, sets}
    end
  end

  defp build_merge_sets(_, _, _, _) do
    {:ok, %{sets: [], params: %{}}}
  end

  defp build_sets(variable, rel_data, persisted_properties, prop_prefix \\ "") do
    rel_data
    |> Enum.filter(fn {k, _} ->
      k in persisted_properties
    end)
    |> Enum.reduce(%{sets: [], params: %{}}, fn {prop_name, prop_value}, sets_data ->
      bound_name = variable <> "_" <> prop_prefix <> "_" <> Atom.to_string(prop_name)

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
          Seraph.Changeset.t(),
          Seraph.Repo.t(),
          :start_node | :end_node,
          Keyword.t()
        ) :: Seraph.Changeset.t()
  defp pre_create_nodes(changeset, repo, changeset_key, opts) do
    case Seraph.Changeset.fetch_change(changeset, changeset_key) do
      {:ok, %Seraph.Changeset{} = start_cs} ->
        new_node = Seraph.Repo.Node.Schema.create!(repo, start_cs, opts)
        Seraph.Changeset.put_change(changeset, changeset_key, new_node)

      {:ok, _} ->
        changeset

      :error ->
        changeset
    end
  end

  @spec check_node_data(any, :start_node | :end_node) :: :ok
  defp check_node_data(%{__struct__: _}, _node_type) do
    :ok
  end

  defp check_node_data(node_data, node_type) do
    msg = """
    #{inspect(node_type)} data must be a map.
    Received:
    #{inspect(node_data)}
    """

    raise ArgumentError, msg
  end

  @spec format_result(Seraph.Repo.queryable(), map) :: Seraph.Schema.Relationship.t()
  defp format_result(queryable, %{"rel" => rel_data, "start" => start_data, "end" => end_data}) do
    props =
      rel_data.properties
      |> Seraph.Repo.Helper.atom_map()
      |> Map.put(:__id__, rel_data.id)
      |> Map.put(
        :start_node,
        Seraph.Repo.Helper.build_node(queryable.__schema__(:start_node), start_data)
      )
      |> Map.put(
        :end_node,
        Seraph.Repo.Helper.build_node(queryable.__schema__(:end_node), end_data)
      )

    struct(queryable, props)
  end
end
