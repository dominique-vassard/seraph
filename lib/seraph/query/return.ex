defmodule Seraph.Query.Return do
  alias Seraph.Query.Builder

  @spec build(Macro.t()) :: Keyword.t()
  def build(ast) when not is_list(ast) do
    build([ast])
  end

  def build(ast) do
    Enum.reduce(ast, [], fn
      {{:., _, [{entity_alias, _, _}, field]}, _, _}, returns ->
        [{entity_alias, field} | returns]

      {entity_alias, _, _}, returns ->
        [{entity_alias, nil} | returns]
    end)
  end

  @spec finalize_build(Keyword.t(), Keyword.t()) :: [Seraph.Query.Builder.entity_expr()]
  def finalize_build(aliases, return) do
    Enum.map(return, fn
      {entity_alias, nil} ->
        {_, entity} = Keyword.fetch!(aliases, entity_alias)
        entity

      {entity_alias, field} ->
        %Builder.FieldExpr{
          variable: Atom.to_string(entity_alias),
          name: field
        }
    end)
    |> Enum.reverse()
  end
end
