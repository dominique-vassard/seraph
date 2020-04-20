defmodule Seraph.Support.Storage do
  def clear(repo) do
    repo.query!("MATCH (n) DETACH DELETE n", %{}, with_stats: true)

    [
      Seraph.Cypher.Node.list_all_constraints(""),
      Seraph.Cypher.Node.list_all_indexes("")
    ]
    |> Enum.map(fn cql ->
      repo.raw_query!(cql)
      |> Map.get(:records, [])
    end)
    |> List.flatten()
    |> Enum.map(&Seraph.Cypher.Node.drop_constraint_index_from_cql/1)
    |> Enum.map(&repo.query/1)
  end
end
