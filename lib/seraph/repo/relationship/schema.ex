defmodule Seraph.Repo.Relationship.Schema do
  @moduledoc false

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

    result =
      Seraph.Repo.Relationship.Queryable.to_query(queryable, changeset, :set)
      |> repo.execute()

    case result do
      {:ok, [%{"rel" => updated_rel}]} ->
        {:ok, updated_rel}

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

    {:ok, %{results: [], stats: stats}} =
      Seraph.Repo.Relationship.Queryable.to_query(queryable, data, :delete)
      |> repo.execute(with_stats: true)

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
      |> repo.execute()

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
    :ok = check_node(rel_data.start_node)
    :ok = check_node(rel_data.end_node)

    {:ok, [%{"rel" => created_relationship}]} =
      Seraph.Repo.Relationship.Queryable.to_query(queryable, rel_data, :merge)
      |> repo.execute()

    {:ok, created_relationship}
  end

  defp do_create_match_merge(_, _, _, _, {:error, error}) do
    raise ArgumentError, error
  end

  defp do_create_match_merge(repo, queryable, start_node_data, end_node_data, merge_opts) do
    :ok = check_node(start_node_data)
    :ok = check_node(end_node_data)

    query =
      Seraph.Repo.Relationship.Queryable.to_query(
        queryable,
        start_node_data,
        end_node_data,
        merge_opts,
        :merge
      )

    case query do
      {:error, _} = error ->
        error

      query ->
        {:ok, [%{"rel" => result}]} = repo.execute(query)
        {:ok, result}
    end
  end

  defp check_node(%Seraph.Changeset{}) do
    raise ArgumentError, "Start node and end node should be Queryable, not Changeset"
  end

  defp check_node(_) do
    :ok
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
end
