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

  @spec merge(Neo4jex.Repo.t(), Ecto.Changeset.t() | Neo4jex.Schema.Node.t(), Keyword.t()) ::
          {:ok, Neo4jex.Schema.Node.t()}
  def merge(repo, %Ecto.Changeset{data: %{__struct__: queryable}} = changeset, opts) do
    queryable.__schema__(:merge_keys)
    |> Enum.map(&Ecto.Changeset.fetch_field(changeset, &1))
    |> Enum.reject(fn {_, value} -> is_nil(value) end)
    |> case do
      [] -> create(repo, Ecto.Changeset.apply_changes(changeset), opts)
      _ -> set(repo, changeset, opts)
    end
  end

  def merge(repo, %{__struct__: queryable} = data, opts) do
    queryable.__schema__(:merge_keys)
    |> Enum.map(&Map.get(data, &1))
    |> Enum.reject(&is_nil/1)
    |> case do
      [] ->
        create(repo, data, opts)

      _ ->
        persisted_properties = queryable.__schema__(:persisted_properties)

        changeset =
          data
          |> Map.from_struct()
          |> Enum.filter(fn {k, _} -> k in persisted_properties end)
          |> Enum.into(%{})
          |> Enum.reduce(Ecto.Changeset.change(data), fn {prop_key, prop_value}, changeset ->
            Ecto.Changeset.force_change(changeset, prop_key, prop_value)
          end)

        set(repo, changeset, opts)
    end
  end

  @spec merge(Neo4jex.Repo.t(), Neo4jex.Repo.Queryable.t(), map, Keyword.t()) ::
          {:ok, Neo4jex.Schema.Node.t()}
  def merge(repo, queryable, merge_keys_data, opts) do
    merge_opts = Neo4jex.Repo.Schema.create_match_merge_opts(opts)
    do_create_match_merge(repo, queryable, merge_keys_data, merge_opts)
  end

  @spec set(Neo4jex.Repo.t(), Ecto.Changeset.t(), Keyword.t()) :: {:ok, Neo4jex.Schema.Node.t()}
  def set(repo, changeset, _opts) do
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

  defp do_create_match_merge(_, _, _, {:error, error}) do
    raise ArgumentError, error
  end

  defp do_create_match_merge(repo, queryable, merge_keys_data, merge_opts) do
    merge_keys = queryable.__schema__(:merge_keys)

    if MapSet.new(merge_keys) != MapSet.new(Map.keys(merge_keys_data)) do
      msg = """
      merge_keys: All merge keys must be provided (#{inspect(merge_keys)}).
      Received:
      #{inspect(merge_keys_data)}
      """

      raise ArgumentError, msg
    end

    merge_keys_query_data =
      Enum.reduce(merge_keys_data, %{properties: %{}, params: %{}}, fn {prop_key, prop_value},
                                                                       data ->
        bound_name = "n_" <> Atom.to_string(prop_key)

        %{
          data
          | properties: Map.put(data.properties, prop_key, bound_name),
            params: Map.put(data.params, String.to_atom(bound_name), prop_value)
        }
      end)

    node_to_merge = %Builder.NodeExpr{
      variable: "n",
      labels: [queryable.__schema__(:primary_label)],
      properties: merge_keys_query_data.properties
    }

    with {:ok, %{sets: on_create_set, params: on_create_params}} <-
           build_merge_sets(
             queryable,
             node_to_merge,
             :on_create,
             Keyword.get(merge_opts, :on_create)
           ),
         {:ok, %{sets: on_match_set, params: on_match_params}} <-
           build_merge_sets(
             queryable,
             node_to_merge,
             :on_match,
             Keyword.get(merge_opts, :on_match)
           ) do
      merge = %Builder.MergeExpr{
        expr: node_to_merge,
        on_create: on_create_set,
        on_match: on_match_set
      }

      pre_params =
        merge_keys_query_data.params
        |> Map.merge(on_create_params)
        |> Map.merge(on_match_params)

      {statement, params} =
        Builder.new(:merge)
        |> Builder.merge([merge])
        |> Builder.return(%Builder.ReturnExpr{
          fields: [node_to_merge]
        })
        |> Builder.params(pre_params)
        |> Builder.to_string()

      {:ok, [%{"n" => merged_node}]} = Planner.query(repo, statement, params)

      {:ok, Neo4jex.Repo.Node.Helper.build_node(queryable, merged_node)}
    else
      {:error, _} = error ->
        error
    end
  end

  defp build_merge_sets(queryable, node_to_merge, operation, {data, changeset_fn}) do
    case changeset_fn.(struct(queryable, %{}), data) do
      %Ecto.Changeset{valid?: false} = changeset ->
        {:error, [{operation, changeset}]}

      %Ecto.Changeset{valid?: true} = changeset ->
        sets = build_set(node_to_merge, changeset.changes, Atom.to_string(operation))
        {:ok, sets}
    end
  end

  defp build_merge_sets(_, _, _, _) do
    {:ok, %{sets: [], params: %{}}}
  end

  @spec build_set(Builder.NodeExpr.t(), Neo4jex.Schema.Node.t()) ::
          Neo4jex.Repo.Queryable.sets_data()
  defp build_set(entity, data, prop_prefix \\ "") do
    Enum.reduce(data, %{sets: [], params: %{}}, fn {prop_name, prop_value}, sets_data ->
      bound_name = entity.variable <> "_" <> prop_prefix <> "_" <> Atom.to_string(prop_name)

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
end
