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

  def merge(repo, %Ecto.Changeset{valid?: true} = changeset, opts) do
    cs =
      changeset
      |> Ecto.Changeset.apply_changes()

    merge(repo, cs, opts)
  end

  def merge(_, %Ecto.Changeset{valid?: false} = changeset, _) do
    {:error, changeset}
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

  @spec delete(Neo4jex.Repo.t(), Ecto.Changeset.t() | Neo4jex.Schema.Node.t()) ::
          {:ok, Neo4jex.Schema.Node.t()} | {:error, Ecto.Changeset.t()}
  def delete(
        repo,
        %Ecto.Changeset{valid?: true, data: %{__meta__: %Neo4jex.Schema.Node.Metadata{}}} =
          changeset
      ) do
    Node.Schema.delete(repo, changeset)
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
