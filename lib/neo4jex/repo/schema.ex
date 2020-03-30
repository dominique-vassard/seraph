defmodule Neo4jex.Repo.Schema do
  alias Neo4jex.Query.{Builder, Helper, Planner}
  alias Neo4jex.Repo.{Node, Relationship}

  @type create_options :: Keyword.t()

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
        raise Neo4jex.InvalidChangesetError, action: :update, changeset: changeset
    end
  end

  @spec delete(Neo4jex.Repo.t(), Ecto.Changeset.t() | Neo4jex.Schema.Node.t()) ::
          {:ok, Neo4jex.Schema.Node.t()} | {:error, Ecto.Changeset.t()}
  def delete(repo, %Ecto.Changeset{} = changeset) do
    do_delete(repo, changeset)
  end

  def delete(repo, struct) do
    changeset = Neo4jex.Changeset.change(struct)

    do_delete(repo, changeset)
  end

  defp do_delete(repo, %Ecto.Changeset{valid?: true} = changeset) do
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

  defp do_delete(_, changeset) do
    {:error, changeset}
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
