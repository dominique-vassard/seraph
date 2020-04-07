defmodule Neo4jex.Query.Helper do
  alias Neo4jex.Query.Condition

  @type merge_keys_data :: %{
          where: nil | Condition.t(),
          params: map
        }

  @spec build_where_from_merge_keys(
          Neo4jex.Query.Builder.NodeExpr.t(),
          Neo4jex.Repo.Queryable.t(),
          Neo4jex.Schema.Node.t()
        ) ::
          Neo4jex.Repo.Queryable.merge_keys_data()
  def build_where_from_merge_keys(entity, queryable, data) do
    merge_keys = queryable.__schema__(:merge_keys)

    Enum.reduce(merge_keys, %{where: nil, params: %{}}, fn property, clauses ->
      value = Map.fetch!(data, property)

      bound_name = entity.variable <> "_" <> Atom.to_string(property)

      condition = %Condition{
        source: entity.variable,
        field: property,
        operator: :==,
        value: bound_name
      }

      %{
        clauses
        | where: Condition.join_conditions(clauses.where, condition),
          params: Map.put(clauses.params, String.to_atom(bound_name), value)
      }
    end)
  end
end
