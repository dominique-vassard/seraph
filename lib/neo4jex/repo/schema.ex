defmodule Neo4jex.Repo.Schema do
  alias Neo4jex.Repo.{Node, Relationship}

  @type create_options :: Keyword.t()
  @type merge_options :: Keyword.t()

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
      _ -> {:error, "not supported"}
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

  @spec merge(Neo4jex.Repo.t(), Neo4jex.Repo.Queryable.t(), map, Keyword.t()) ::
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
end
