defmodule Seraph.Repo.Schema do
  @moduledoc false

  alias Seraph.Repo.{Node, Relationship}

  @type create_options :: Keyword.t()
  @type merge_options :: Keyword.t()
  @type create_match_merge_opts :: Keyword.t()

  @doc """
  Create a Node or a Relationship with the given data.
  """
  @spec create(
          Seraph.Repo.t(),
          Seraph.Schema.Node.t() | Seraph.Schema.Relationship.t() | Ecto.Changeset.t(),
          create_options
        ) ::
          {:ok, Seraph.Schema.Node.t() | Seraph.Schema.Relationship.t()}
          | {:error, Ecto.Changeset.t()}
  def create(repo, %{__meta__: %Seraph.Schema.Node.Metadata{}} = data, opts) do
    Node.Schema.create(repo, data, opts)
  end

  def create(repo, %{__meta__: %Seraph.Schema.Relationship.Metadata{}} = data, opts) do
    Relationship.Schema.create(repo, data, opts)
  end

  def create(repo, %Ecto.Changeset{valid?: true} = changeset, opts) do
    cs =
      changeset
      |> Ecto.Changeset.apply_changes()

    create(repo, cs, opts)
  end

  def create(_, %Ecto.Changeset{valid?: false} = changeset, _) do
    {:error, changeset}
  end

  @doc """
  Same as `create/3` but raise in case of error.
  """
  @spec create!(Seraph.Repo.t(), Ecto.Changeset.t(), create_options()) ::
          Seraph.Schema.Node.t() | Seraph.Schema.Relationship.t()
  def create!(repo, changeset, opts) do
    case create(repo, changeset, opts) do
      {:ok, result} ->
        result

      {:error, changeset} ->
        raise Seraph.InvalidChangesetError, action: :insert, changeset: changeset
    end
  end

  @doc """
  Create or update a Node or a Relationship.
  """
  @spec merge(
          Seraph.Repo.t(),
          Seraph.Schema.Relationship.t() | Ecto.Changeset.t(),
          merge_options
        ) :: {:ok, Seraph.Schema.Relationship.t()} | {:error, Ecto.Changeset.t()}
  def merge(repo, %{__meta__: %Seraph.Schema.Relationship.Metadata{}} = data, opts) do
    Relationship.Schema.merge(repo, data, opts)
  end

  def merge(repo, %{__meta__: %Seraph.Schema.Node.Metadata{}} = data, opts) do
    Node.Schema.merge(repo, data, opts)
  end

  def merge(
        repo,
        %Ecto.Changeset{valid?: true, data: %{__meta__: %Seraph.Schema.Node.Metadata{}}} =
          changeset,
        opts
      ) do
    Node.Schema.merge(repo, changeset, opts)
  end

  def merge(repo, %Ecto.Changeset{valid?: true} = changeset, opts) do
    cs =
      changeset
      |> Ecto.Changeset.apply_changes()

    merge(repo, cs, opts)
  end

  def merge(_, %Ecto.Changeset{valid?: false} = changeset, _) do
    {:error, changeset}
  end

  def merge(_, _, _) do
    raise ArgumentError, "merge/3 requires a Ecto.Changeset or a Queryable struct."
  end

  @doc """
  Same as `merge/3` but raise in case of error.
  """
  @spec merge!(
          Seraph.Repo.t(),
          Seraph.Schema.Relationship.t() | Ecto.Changeset.t(),
          merge_options
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
  Performs a MERGE operation on a Node or Relationship.

  Options:
    * `:on_create`: a tuple `{data, changeset_fn}` with the data to set on entity if it's created.
    Provided data will be validated through given `changeset_fn`
    * `:on_match`: a tuple `{data, changeset_fn}` with the data to set on entity if it already exists
    and is matched.
    Provided data will be validated through given `changeset_fn`
  """
  @spec merge(Seraph.Repo.t(), Seraph.Repo.Queryable.t(), map, Keyword.t()) ::
          {:ok, Seraph.Schema.Node.t() | Seraph.Schema.Relationship.t()} | {:error, any}
  def merge(repo, queryable, merge_keys_data, opts) do
    case queryable.__schema__(:entity_type) do
      :node -> Node.Schema.merge(repo, queryable, merge_keys_data, opts)
      :relationship -> Relationship.Schema.merge(repo, queryable, merge_keys_data, opts)
    end
  end

  @doc """
  Same as `merge/4` but raise in case of error
  """
  @spec merge!(Seraph.Repo.t(), Seraph.Repo.Queryable.t(), map, Keyword.t()) ::
          Seraph.Schema.Node.t() | Seraph.Schema.Relationship.t()
  def merge!(repo, queryable, merge_keys_data, opts) do
    case merge(repo, queryable, merge_keys_data, opts) do
      {:ok, result} ->
        result

      {:error, [on_create: %Ecto.Changeset{} = changeset]} ->
        raise Seraph.InvalidChangesetError, action: :on_create, changeset: changeset

      {:error, [on_match: %Ecto.Changeset{} = changeset]} ->
        raise Seraph.InvalidChangesetError, action: :on_match, changeset: changeset
    end
  end

  @doc """
  Set new data on a Node or a Relationship.
  """
  @spec set(Seraph.Repo.t(), Ecto.Changeset.t(), Keyword.t()) ::
          {:ok, Seraph.Schema.Node.t()}
          | {:ok, Seraph.Schema.Relationship.t()}
          | {:error, Ecto.Changeset.t()}
  def set(
        repo,
        %Ecto.Changeset{valid?: true, data: %{__meta__: %Seraph.Schema.Node.Metadata{}}} =
          changeset,
        opts
      ) do
    Seraph.Repo.Node.Schema.set(repo, changeset, opts)
  end

  def set(
        repo,
        %Ecto.Changeset{valid?: true, data: %{__meta__: %Seraph.Schema.Relationship.Metadata{}}} =
          changeset,
        opts
      ) do
    Seraph.Repo.Relationship.Schema.set(repo, changeset, opts)
  end

  def set(_, %Ecto.Changeset{valid?: false} = changeset, _opts) do
    {:error, changeset}
  end

  @doc """
  Same as `set/3` but raise in case of error.
  """
  @spec set!(Seraph.Repo.t(), Ecto.Changeset.t(), Keyword.t()) :: Seraph.Schema.Node.t()
  def set!(repo, changeset, opts) do
    case set(repo, changeset, opts) do
      {:ok, result} ->
        result

      {:error, changeset} ->
        raise Seraph.InvalidChangesetError, action: :set, changeset: changeset
    end
  end

  @doc """
  Dleete a Node or a Relationship.
  """
  @spec delete(Seraph.Repo.t(), Ecto.Changeset.t() | Seraph.Schema.Node.t()) ::
          {:ok, Seraph.Schema.Node.t()} | {:error, Ecto.Changeset.t()}
  def delete(
        repo,
        %Ecto.Changeset{valid?: true, data: %{__meta__: %Seraph.Schema.Node.Metadata{}}} =
          changeset
      ) do
    Node.Schema.delete(repo, changeset)
  end

  def delete(
        repo,
        %Ecto.Changeset{valid?: true, data: %{__meta__: %Seraph.Schema.Relationship.Metadata{}}} =
          changeset
      ) do
    Relationship.Schema.delete(repo, changeset)
  end

  def delete(_repo, %Ecto.Changeset{valid?: false} = changeset) do
    {:error, changeset}
  end

  def delete(repo, struct) do
    changeset = Seraph.Changeset.change(struct)

    delete(repo, changeset)
  end

  @doc """
  Same as `delete/2` but raise in case of error.
  """
  @spec delete!(Seraph.Repo.t(), Seraph.Schema.Node.t() | Ecto.Changeset.t()) ::
          Seraph.Schema.Node.t()
  def delete!(repo, struct_or_changeset) do
    case delete(repo, struct_or_changeset) do
      {:ok, data} ->
        data

      {:error, changeset} ->
        raise Seraph.InvalidChangesetError, action: :delete, changeset: changeset
    end
  end

  @doc """
  Manage MERGE options:
    * `:on_create`
    * `:on_match`
  """
  @spec create_match_merge_opts(create_match_merge_opts(), create_match_merge_opts) ::
          create_match_merge_opts | {:error, String.t()}
  def create_match_merge_opts(opts, final_opts \\ [])

  def create_match_merge_opts([{:on_create, {data, changeset_fn} = on_create_opts} | rest], opts)
      when is_map(data) and is_function(changeset_fn, 2) do
    create_match_merge_opts(rest, Keyword.put(opts, :on_create, on_create_opts))
  end

  def create_match_merge_opts([{:on_create, on_create_opts} | _], _opts) do
    msg = """
    on_create: Require a tuple {data_for_creation, changeset_fn} with following types:
      - data_for_creation: map
      - changeset_fn: 2-arity function
    Received: #{inspect(on_create_opts)}
    """

    {:error, msg}
  end

  def create_match_merge_opts([{:on_match, {data, changeset_fn} = on_match_opts} | rest], opts)
      when is_map(data) and is_function(changeset_fn, 2) do
    create_match_merge_opts(rest, Keyword.put(opts, :on_match, on_match_opts))
  end

  def create_match_merge_opts([{:on_match, on_match_opts} | _], _opts) do
    msg = """
    on_match: Require a tuple {data_for_creation, changeset_fn} with following types:
      - data_for_creation: map
      - changeset_fn: 2-arity function
    Received: #{inspect(on_match_opts)}
    """

    {:error, msg}
  end

  def create_match_merge_opts(_, opts) do
    opts
  end
end
