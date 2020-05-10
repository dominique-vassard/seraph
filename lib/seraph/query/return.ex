defmodule Seraph.Query.Return do
  alias Seraph.Query.Builder

  @spec build(Macro.t()) :: Keyword.t()
  def build(ast) when not is_list(ast) do
    build([ast])
  end

  def build(ast) do
    Enum.map(ast, &do_build/1)
  end

  @spec do_build(Macro.t()) :: {atom, nil | atom, atom}
  defp do_build({{:., _, [{entity_alias, _, _}, property]}, _, _}) do
    {entity_alias, property, nil}
  end

  defp do_build({result_alias, {{:., _, [{entity_alias, _, _}, property]}, _, _}}) do
    {entity_alias, property, result_alias}
  end

  defp do_build({entity_alias, _, _}) do
    {entity_alias, nil, nil}
  end

  defp do_build({result_alias, {entity_alias, _, _}}) do
    {entity_alias, nil, result_alias}
  end

  @spec finalize_build(Keyword.t(), Keyword.t()) :: [Seraph.Query.Builder.entity_expr()]
  def finalize_build(aliases, return) do
    Enum.map(return, fn
      {entity_alias, nil, result_alias} ->
        {_, entity} = Keyword.fetch!(aliases, entity_alias)
        alias_entity(entity, result_alias)

      {entity_alias, property, result_alias} ->
        %Builder.FieldExpr{
          variable: Atom.to_string(entity_alias),
          name: property
        }
        |> alias_entity(result_alias)
    end)
    |> Enum.reverse()
  end

  defp alias_entity(result, nil) do
    result
  end

  defp alias_entity(result, result_alias) do
    Map.put(result, :alias, Atom.to_string(result_alias))
  end
end
