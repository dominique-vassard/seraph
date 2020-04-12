defmodule Seraph.Query.Planner do
  @moduledoc false

  @doc """
  Launch query agains Neo4j database and return the result.

  Options:
    * `:with_stats` - Wether to return the `stats` part of the result. (Possible values: `true`, `false` default: `false`)
  """
  @spec query(Seraph.Repo.t(), String.t(), map, Keyword.t()) :: {:ok, list | map} | {:error, any}
  def query(repo, statement, params \\ %{}, opts \\ []) do
    case raw_query(repo, statement, params, opts) do
      {:ok, results} ->
        {:ok, format_results(results, opts)}

      error ->
        error
    end
  end

  @doc """
  Same as query/4 but raises in case of error.
  """
  @spec query!(Seraph.Repo.t(), String.t(), map, Keyword.t()) :: list | map
  def query!(repo, statement, params \\ %{}, opts \\ []) do
    raw_query!(repo, statement, params, opts)
    |> format_results(opts)
  end

  @doc """
  Launch query agains Neo4j database and return the unformatted result.
  """
  @spec raw_query(Seraph.Repo.t(), String.t(), map, Keyword.t()) ::
          {:ok, Bolt.Sips.Response.t() | [Bolt.Sips.Response.t()]} | {:error, Bolt.Sips.Error.t()}
  def raw_query(repo, statement, params \\ %{}, opts \\ []) do
    Bolt.Sips.query(get_conn(repo, opts), statement, params, opts)
  end

  @doc """
  Same as raw_query/4 but raises in case of error.
  """
  @spec raw_query!(Seraph.Repo.t(), String.t(), map, Keyword.t()) ::
          Bolt.Sips.Response.t() | [Bolt.Sips.Response.t()] | Bolt.Sips.Exception.t()
  def raw_query!(repo, statement, params \\ %{}, opts \\ []) do
    Bolt.Sips.query!(get_conn(repo, opts), statement, params, opts)
  end

  defp format_results(results, with_stats: true) do
    %{
      results: results.results,
      stats: results.stats
    }
  end

  defp format_results(results, _opts) do
    results.results
  end

  defp get_conn(_, conn: conn) do
    conn
  end

  defp get_conn(repo, role: role) do
    Bolt.Sips.conn(role, prefix: repo)
  end

  defp get_conn(repo, _) do
    Bolt.Sips.conn(:direct, prefix: repo)
  end
end
