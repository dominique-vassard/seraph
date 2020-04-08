defmodule Seraph.InvalidChangesetError do
  defexception [:action, :changeset]

  @impl true
  defdelegate message(data), to: Ecto.InvalidChangesetError
end

defmodule Seraph.NoResultsError do
  defexception [:message]

  def exception(opts) do
    queryable = Keyword.fetch!(opts, :queryable)
    function = Keyword.fetch!(opts, :function)
    params = Keyword.get(opts, :params)

    msg = """
    Expected at least one result, got none for:
    > #{Atom.to_string(queryable)}.#{Atom.to_string(function)}
    params: #{inspect(params)}

    """

    %__MODULE__{message: msg}
  end
end

defmodule Seraph.MultipleRelationshipsError do
  defexception [:message]

  def exception(opts) do
    queryable = Keyword.fetch!(opts, :queryable)
    count = Keyword.fetch!(opts, :count)
    start_node = Keyword.fetch!(opts, :start_node)
    end_node = Keyword.fetch!(opts, :end_node)
    params = Keyword.get(opts, :params)

    msg = """
    expected at most one relationship but got #{count} when retrieving:
    (#{inspect(start_node)})-[:#{inspect(queryable)}]->(#{inspect(end_node)})
    params:
    #{inspect(params)}
    """

    %__MODULE__{message: msg}
  end
end

defmodule Seraph.DeletionError do
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
