defmodule Neo4jex.InvalidChangesetError do
  defexception [:action, :changeset]

  @impl true
  defdelegate message(data), to: Ecto.InvalidChangesetError
end

defmodule Neo4jex.NoResultsError do
  defexception [:message]

  def exception(opts) do
    queryable = Keyword.fetch!(opts, :queryable)
    function = Keyword.fetch!(opts, :function)
    params = Keyword.get(opts, :params)

    msg = """
    Expected at least one result, got none for:
    > #{Atom.to_string(queryable)}.#{Atom.to_string(function)}
    params: #{params}

    """

    %__MODULE__{message: msg}
  end
end

defmodule Neo4jex.DeletionError do
  defexception [:message]

  def exception(opts) do
    queryable = Keyword.fetch!(opts, :queryable)
    data = Keyword.fetch!(opts, :data)

    msg = """
    Failed attempt to delete #{Atom.to_string(queryable)}
    #{inspect(data)}
    """

    %__MODULE__{message: msg}
  end
end
