defmodule Neo4jex.Repo.Schema do
  alias Neo4jex.Repo.{Node, Relationship}

  @type create_options :: Keyword.t()
  @type merge_options :: Keyword.t()
  @type create_match_merge_opts :: Keyword.t()

  @spec create(
          Neo4jex.Repo.t(),
          Neo4jex.Schema.Node.t() | Neo4jex.Schema.Relationship.t() | Ecto.Changeset.t(),
          create_options
        ) ::
          {:ok, Neo4jex.Schema.Node.t() | Neo4jex.Schema.Relationship.t()}
          | {:error, Ecto.Changeset.t()}
  def create(repo, %{__meta__: %Neo4jex.Schema.Node.Metadata{}} = data, opts) do
    Node.Schema.create(repo, data, opts)
  end

  def create(repo, %{__meta__: %Neo4jex.Schema.Relationship.Metadata{}} = data, opts) do
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

  @spec create!(Neo4jex.Repo.t(), Ecto.Changeset.t(), create_options()) ::
          Neo4jex.Schema.Node.t() | Neo4jex.Schema.Relationship.t()
  def create!(repo, changeset, opts) do
    case create(repo, changeset, opts) do
      {:ok, result} ->
        result

      {:error, changeset} ->
        raise Neo4jex.InvalidChangesetError, action: :insert, changeset: changeset
    end
  end

  @spec merge(
          Neo4jex.Repo.t(),
          Neo4jex.Schema.Relationship.t() | Ecto.Changeset.t(),
          merge_options
        ) :: {:ok, Neo4jex.Schema.Relationship.t()} | {:error, Ecto.Changeset.t()}
  def merge(repo, %{__meta__: %Neo4jex.Schema.Relationship.Metadata{}} = data, opts) do
    Relationship.Schema.merge(repo, data, opts)
  end

  def merge(repo, %{__meta__: %Neo4jex.Schema.Node.Metadata{}} = data, opts) do
    Node.Schema.merge(repo, data, opts)
  end

  def merge(
        repo,
        %Ecto.Changeset{valid?: true, data: %{__meta__: %Neo4jex.Schema.Node.Metadata{}}} =
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

  @spec merge(Neo4jex.Repo.t(), Neo4jex.Repo.Queryable.t(), map, Keyword.t()) ::
          {:ok, Neo4jex.Schema.Node.t() | Neo4jex.Schema.Relationship.t()} | {:error, any}
  def merge(repo, queryable, merge_keys_data, opts) do
    case queryable.__schema__(:entity_type) do
      :node -> Node.Schema.merge(repo, queryable, merge_keys_data, opts)
      :relationship -> Relationship.Schema.merge(repo, queryable, merge_keys_data, opts)
    end
  end

  @spec merge!(
          Neo4jex.Repo.t(),
          Neo4jex.Schema.Relationship.t() | Ecto.Changeset.t(),
          merge_options
        ) :: Neo4jex.Schema.Relationship.t()
  def merge!(repo, changeset, opts) do
    case merge(repo, changeset, opts) do
      {:ok, result} ->
        result

      {:error, changeset} ->
        raise Neo4jex.InvalidChangesetError, action: :update, changeset: changeset
    end
  end

  @spec merge!(Neo4jex.Repo.t(), Neo4jex.Repo.Queryable.t(), map, Keyword.t()) ::
          Neo4jex.Schema.Node.t() | Neo4jex.Schema.Relationship.t()
  def merge!(repo, queryable, merge_keys_data, opts) do
    case merge(repo, queryable, merge_keys_data, opts) do
      {:ok, result} ->
        result

      {:error, [on_create: %Ecto.Changeset{} = changeset]} ->
        raise Neo4jex.InvalidChangesetError, action: :on_create, changeset: changeset

      {:error, [on_match: %Ecto.Changeset{} = changeset]} ->
        raise Neo4jex.InvalidChangesetError, action: :on_match, changeset: changeset
    end
  end

  @spec set(Neo4jex.Repo.t(), Ecto.Changeset.t(), Keyword.t()) ::
          {:ok, Neo4jex.Schema.Node.t()}
          | {:ok, Neo4jex.Schema.Relationship.t()}
          | {:error, Ecto.Changeset.t()}
  def set(
        repo,
        %Ecto.Changeset{valid?: true, data: %{__meta__: %Neo4jex.Schema.Node.Metadata{}}} =
          changeset,
        opts
      ) do
    Neo4jex.Repo.Node.Schema.set(repo, changeset, opts)
  end

  def set(
        repo,
        %Ecto.Changeset{valid?: true, data: %{__meta__: %Neo4jex.Schema.Relationship.Metadata{}}} =
          changeset,
        opts
      ) do
    Neo4jex.Repo.Relationship.Schema.set(repo, changeset, opts)
  end

  def set(_, %Ecto.Changeset{valid?: false} = changeset, _opts) do
    {:error, changeset}
  end

  @spec set!(Neo4jex.Repo.t(), Ecto.Changeset.t(), Keyword.t()) :: Neo4jex.Schema.Node.t()
  def set!(repo, changeset, opts) do
    case set(repo, changeset, opts) do
      {:ok, result} ->
        result

      {:error, changeset} ->
        raise Neo4jex.InvalidChangesetError, action: :set, changeset: changeset
    end
  end

  @spec delete(Neo4jex.Repo.t(), Ecto.Changeset.t() | Neo4jex.Schema.Node.t()) ::
          {:ok, Neo4jex.Schema.Node.t()} | {:error, Ecto.Changeset.t()}
  def delete(
        repo,
        %Ecto.Changeset{valid?: true, data: %{__meta__: %Neo4jex.Schema.Node.Metadata{}}} =
          changeset
      ) do
    Node.Schema.delete(repo, changeset)
  end

  def delete(
        repo,
        %Ecto.Changeset{valid?: true, data: %{__meta__: %Neo4jex.Schema.Relationship.Metadata{}}} =
          changeset
      ) do
    Relationship.Schema.delete(repo, changeset)
  end

  def delete(_repo, %Ecto.Changeset{valid?: false} = changeset) do
    {:error, changeset}
  end

  def delete(repo, struct) do
    changeset = Neo4jex.Changeset.change(struct)

    delete(repo, changeset)
  end

  @spec delete!(Neo4jex.Repo.t(), Neo4jex.Schema.Node.t() | Ecto.Changeset.t()) ::
          Neo4jex.Schema.Node.t()
  def delete!(repo, struct_or_changeset) do
    case delete(repo, struct_or_changeset) do
      {:ok, data} ->
        data

      {:error, changeset} ->
        raise Neo4jex.InvalidChangesetError, action: :delete, changeset: changeset
    end
  end

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
