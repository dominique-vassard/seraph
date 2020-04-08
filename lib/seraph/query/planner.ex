defmodule Seraph.Query.Planner do
  @spec query(Seraph.Repo.t(), String.t(), map, Keyword.t()) :: {:ok, list | map} | {:error, any}
  def query(repo, statement, params \\ %{}, opts \\ []) do
    case raw_query(repo, statement, params, opts) do
      {:ok, results} ->
        {:ok, format_results(results, opts)}

      error ->
        error
    end
  end

  @spec query!(Seraph.Repo.t(), String.t(), map, Keyword.t()) :: list | map
  def query!(repo, statement, params \\ %{}, opts \\ []) do
    raw_query!(repo, statement, params, opts)
    |> format_results(opts)
  end

  @doc false
  @spec raw_query(Seraph.Repo.t(), String.t(), map, Keyword.t()) ::
          {:ok, Bolt.Sips.Response.t() | [Bolt.Sips.Response.t()]} | {:error, Bolt.Sips.Error.t()}
  def raw_query(repo, statement, params \\ %{}, opts \\ []) do
    Bolt.Sips.query(get_conn(repo, opts), statement, params, opts)
  end

  @doc false
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
