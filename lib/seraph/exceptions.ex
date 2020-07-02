defmodule Seraph.Error do
  defexception [:message]
end

defmodule Seraph.InvalidChangesetError do
  @moduledoc """
  Raised when action cannot be performed due to an invalid changeset
  """
  defexception [:action, :changeset]

  @impl true

  def message(data) do
    data
    |> Map.put(:changeset, struct!(Ecto.Changeset, Map.from_struct(data.changeset)))
    |> Ecto.InvalidChangesetError.message()
  end
end

defmodule Seraph.NoResultsError do
  @moduledoc """
  Raised when there is no results when at least one was expected.
  """
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

defmodule Seraph.MultipleNodesError do
  @doc """
  Raised when there is more than one Node found when only one is expected.
  """

  defexception [:message]

  def exception(opts) do
    queryable = Keyword.fetch!(opts, :queryable)
    count = Keyword.fetch!(opts, :count)
    params = Keyword.get(opts, :params)

    msg = """
    expected at most one node but got #{count} when retrieving: #{inspect(queryable)}
    params:
    #{inspect(params)}
    """

    %__MODULE__{message: msg}
  end
end

defmodule Seraph.MultipleRelationshipsError do
  @moduledoc """
  Raised when there is more than one relstionship found when only one is exoected.
  """
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
  @moduledoc """
  Rased when a delete operation cannot be performed.
  """
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

defmodule Seraph.StaleEntryError do
  @moduledoc """
  Raised when the given entry is not found in database.
  """
  defexception [:message]

  def exception(opts) do
    action = Keyword.fetch!(opts, :action)
    struct = Keyword.fetch!(opts, :struct)

    msg = """
    attempted to #{action} a stale struct:

    #{inspect(struct)}
    """

    %__MODULE__{message: msg}
  end
end

defmodule Seraph.QueryError do
  @moduledoc """
  Raised at runtime when the query is invalid.
  """
  defexception [:message]

  def exception(opts) do
    message = Keyword.fetch!(opts, :message)
    query = Keyword.fetch!(opts, :query)

    query_str = Enum.join(query, "\n")

    message = """
    #{message} in query:

    #{query_str}
    """

    %__MODULE__{message: message}
  end
end

defmodule Seraph.MultipleResultsError do
  @moduledoc """
  Raised when more than one is found when only one is expected.
  """
  defexception [:message]

  def exception(opts) do
    query = Keyword.fetch!(opts, :query)
    count = Keyword.fetch!(opts, :count)

    query_str = Enum.join(query, "\n")

    message = """
    #{count} resutls found when only one was expected in query:

    #{query_str}
    """

    %__MODULE__{message: message}
  end
end
