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
end
