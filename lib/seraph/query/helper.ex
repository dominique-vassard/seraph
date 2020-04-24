defmodule Seraph.Query.Helper do
  @moduledoc false

  alias Seraph.Query.Condition

  @type merge_keys_data :: %{
          where: nil | Condition.t(),
          params: map
        }

  @doc """
  Build a map with data for a merge operation for the given node data
  """
  @spec build_where_from_merge_keys(
          Seraph.Query.Builder.NodeExpr.t(),
          Seraph.Repo.queryable(),
          Seraph.Schema.Node.t()
        ) :: merge_keys_data()
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
