defmodule Seraph.Repo.Node.Schema do
  @moduledoc false

  alias Seraph.Query.{Builder, Helper, Planner}
  require Seraph.Query

  @type sets_data :: %{
          sets: [Builder.SetExpr.t()],
          params: map
        }

  @doc """
  Creates a node in database with the given data.
  """
  @spec create(
          Seraph.Repo.t(),
          Seraph.Schema.Node.t() | Seraph.Changeset.t(),
          Keyword.t()
        ) ::
          {:ok, Seraph.Schema.Node.t()} | {:error, Seraph.Changeset.t()}
  def create(repo, %Seraph.Changeset{valid?: true} = changeset, opts) do
    do_create(repo, Seraph.Changeset.apply_changes(changeset), opts)
  end

  def create(_, %Seraph.Changeset{valid?: false} = changeset, _) do
    {:error, changeset}
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
  @spec create!(Seraph.Repo.t(), Seraph.Schema.Node.t() | Seraph.Changeset.t(), Keyword.t()) ::
          Seraph.Schema.Node.t()
  def create!(repo, struct_or_changeset, opts) do
    case create(repo, struct_or_changeset, opts) do
      {:ok, result} ->
        result

      {:error, changeset} ->
        raise Seraph.InvalidChangesetError, action: :insert, changeset: changeset
    end
  end

  @doc """
  Create or update node in database.

  If `merge_keys` are present in changeset / struct, then set new data, otherwise create a new node.
  """
  @spec create_or_set(Seraph.Repo.t(), Seraph.Schema.Node.t() | Seraph.Changeset.t(), Keyword.t()) ::
          {:ok, Seraph.Schema.Node.t()} | {:error, Seraph.Changeset.t()}

  def create_or_set(_, %Seraph.Changeset{valid?: false} = changeset, _) do
    {:error, changeset}
  end

  def create_or_set(repo, %Seraph.Changeset{data: %{__struct__: queryable}} = changeset, opts) do
    queryable.__schema__(:merge_keys)
    |> Enum.map(&Seraph.Changeset.fetch_field(changeset, &1))
    |> Enum.reject(fn {_, value} -> is_nil(value) end)
    |> case do
      [] -> create(repo, Seraph.Changeset.apply_changes(changeset), opts)
      _ -> set(repo, changeset, opts)
    end
  end

  def create_or_set(repo, %{__struct__: queryable} = data, opts) do
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
          |> Enum.reduce(Seraph.Changeset.change(data), fn {prop_key, prop_value}, changeset ->
            Seraph.Changeset.force_change(changeset, prop_key, prop_value)
          end)

        set(repo, changeset, opts)
    end
  end

  @doc """
  Same as `merge/3` but raise in case of error.
  """
  @spec create_or_set!(
          Seraph.Repo.t(),
          Seraph.Schema.Node.t() | Seraph.Changeset.t(),
          Keyword.t()
        ) ::
          Seraph.Schema.Node.t()
  def create_or_set!(repo, changeset, opts) do
    case create_or_set(repo, changeset, opts) do
      {:ok, result} ->
        result

      {:error, changeset} ->
        raise Seraph.InvalidChangesetError, action: :update, changeset: changeset
    end
  end

  @doc """
  Perform a MERGE on the node in database.

  Options:
    * `:on_create`: a tuple `{data, changeset_fn}` with the data to set on node if it's created.
    Provided data will be validated through given `changeset_fn`
    * `:on_match`: a tuple `{data, changeset_fn}` with the data to set on node if it already exists
    and is matched.
    Provided data will be validated through given `changeset_fn`
  """
  @spec merge(Seraph.Repo.t(), Seraph.Repo.queryable(), map, Keyword.t()) ::
          {:ok, Seraph.Schema.Node.t()} | {:error, any}
  def merge(repo, queryable, merge_keys_data, opts) do
    merge_opts = Seraph.Repo.Helper.create_match_merge_opts(opts)

    do_create_match_merge(repo, queryable, merge_keys_data, merge_opts)
  end

  @doc """
  Same as `merge/4` but raise in case of error
  """
  @spec merge!(Seraph.Repo.t(), Seraph.Repo.queryable(), map, Keyword.t()) ::
          Seraph.Schema.Node.t()
  def merge!(repo, queryable, merge_keys_data, opts) do
    case merge(repo, queryable, merge_keys_data, opts) do
      {:ok, result} ->
        result

      {:error, [on_create: %Seraph.Changeset{} = changeset]} ->
        raise Seraph.InvalidChangesetError, action: :on_create, changeset: changeset

      {:error, [on_match: %Seraph.Changeset{} = changeset]} ->
        raise Seraph.InvalidChangesetError, action: :on_match, changeset: changeset
    end
  end

  @doc """
  Sets new data on node in database.
  """
  @spec set(Seraph.Repo.t(), Seraph.Changeset.t(), Keyword.t()) ::
          {:ok, Seraph.Schema.Node.t()} | {:error, Seraph.Changeset.t()}
  def set(_, %Seraph.Changeset{valid?: false} = changeset, _opts) do
    {:error, changeset}
  end

  def set(repo, changeset, _opts) do
    %{__struct__: queryable} = changeset.data

    {:ok, results} =
      Seraph.Repo.Node.Queryable.to_query(queryable, changeset, :match_set)
      |> repo.query()

    case results do
      [] ->
        raise Seraph.StaleEntryError, action: :set, struct: changeset.data

      [%{"n" => result}] ->
        {:ok, result}
    end
  end

  @doc """
  Same as `set/3` but raise in case of error.
  """
  @spec set!(Seraph.Repo.t(), Seraph.Changeset.t(), Keyword.t()) :: Seraph.Schema.Node.t()
  def set!(repo, changeset, opts) do
    case set(repo, changeset, opts) do
      {:ok, result} ->
        result

      {:error, changeset} ->
        raise Seraph.InvalidChangesetError, action: :set, changeset: changeset
    end
  end

  @doc """
  Deletes node from database.
  """
  @spec delete(Seraph.Repo.t(), Seraph.Changeset.t()) ::
          {:ok, Seraph.Schema.Node.t()} | {:error, Seraph.Changeset.t()}
  def delete(_repo, %Seraph.Changeset{valid?: false} = changeset) do
    {:error, changeset}
  end

  def delete(repo, %Seraph.Changeset{valid?: true} = changeset) do
    data =
      changeset
      |> Map.put(:changes, %{})
      |> Seraph.Changeset.apply_changes()

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
        raise Seraph.DeletionError, queryable: queryable, data: data
    end
  end

  def delete(repo, struct) do
    changeset = Seraph.Changeset.change(struct)

    delete(repo, changeset)
  end

  @doc """
  Same as `delete/2` but raise in case of error.
  """
  @spec delete!(Seraph.Repo.t(), Seraph.Schema.Node.t() | Seraph.Changeset.t()) ::
          Seraph.Schema.Node.t()
  def delete!(repo, struct_or_changeset) do
    case delete(repo, struct_or_changeset) do
      {:ok, data} ->
        data

      {:error, changeset} ->
        raise Seraph.InvalidChangesetError, action: :delete, changeset: changeset
    end
  end

  defp do_create(repo, %{__struct__: queryable} = data, _opts) do
    persisted_properties = queryable.__schema__(:persisted_properties)

    properties =
      case queryable.__schema__(:identifier) do
        {:uuid, :string, _} ->
          Map.put(data, :uuid, UUID.uuid4())

        _ ->
          data
      end
      |> Map.from_struct()
      |> Enum.filter(fn {k, _} ->
        k in persisted_properties
      end)
      |> Enum.into(%{})
      |> Map.put(:additionalLabels, data.additionalLabels)

    {:ok, [%{"n" => created_node}]} =
      Seraph.Repo.Node.Queryable.to_query(queryable, properties, :create)
      |> repo.query()

    {:ok, created_node}
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

    with {:ok, create_changeset} <- build_merge_data(queryable, :on_create, merge_opts),
         {:ok, match_changeset} <- build_merge_data(queryable, :on_match, merge_opts) do
      data = [merge: merge_keys_data, on_create: create_changeset, on_match: match_changeset]

      {:ok, [%{"n" => merged_node}]} =
        Seraph.Repo.Node.Queryable.to_query(queryable, data, :merge)
        |> repo.query()

      {:ok, merged_node}
    else
      {:error, _} = error -> error
    end
  end

  @spec build_merge_data(Seraph.Repo.queryable(), :on_create | :on_match, Keyword.t()) ::
          {:ok, %{} | Seraph.Changeset.t()}
          | {:error, [{:on_create | :on_match, Seraph.Changeset.t()}]}
  defp build_merge_data(queryable, operation, opts) do
    do_build_merge_data(
      queryable,
      operation,
      Keyword.get(opts, operation),
      Keyword.get(opts, :no_data)
    )
  end

  defp do_build_merge_data(_, _, nil, _) do
    {:ok, %{}}
  end

  defp do_build_merge_data(_, _, _, true) do
    {:ok, %{}}
  end

  defp do_build_merge_data(queryable, operation, {data, changeset_fn}, false) do
    case changeset_fn.(struct(queryable, %{}), data) do
      %Seraph.Changeset{valid?: false} = changeset ->
        {:error, [{operation, changeset}]}

      %Seraph.Changeset{valid?: true} = changeset ->
        {:ok, changeset}
    end
  end
end
