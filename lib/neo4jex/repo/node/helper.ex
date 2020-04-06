defmodule Neo4jex.Repo.Node.Helper do
  @spec identifier_field(Queryable.t()) :: atom
  def identifier_field(queryable) do
    case queryable.__schema__(:identifier) do
      {field, _, _} ->
        field

      _ ->
        raise ArgumentError, "No identifier for #{inspect(queryable)}."
    end
  end

  @spec build_node(Neo4jex.Repo.Queryable.t(), map) :: Neo4jex.Schema.Node.t()
  def build_node(queryable, node_data) do
    props =
      node_data.properties
      |> atom_map()
      |> Map.put(:__id__, node_data.id)
      |> Map.put(:additionalLabels, node_data.labels -- [queryable.__schema__(:primary_label)])

    struct(queryable, props)
  end

  @spec atom_map(map) :: map
  defp atom_map(string_map) do
    string_map
    |> Enum.map(fn {k, v} ->
      {String.to_atom(k), v}
    end)
    |> Enum.into(%{})
  end
end
