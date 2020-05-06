defmodule Seraph.Query.Where do
  alias Seraph.Query.Condition

  @valid_operators [:and, :==]
  @spec build(Macro.t(), Keyword.t(), Keyword.t()) ::
          {Seraph.Query.Condition.t() | map, Keyword.t(), Keyword.t()}
  def build(ast, params \\ [], condition_fields \\ [])

  def build({operator, _, [lhs, rhs]}, params, condition_fields)
      when operator in @valid_operators do
    {treated_lhs, l_params, lhs_cond_fields} = build(lhs, params, condition_fields)
    {treated_rhs, params, rhs_cond_fields} = build(rhs, l_params, lhs_cond_fields)

    {condition, new_cond_fields} =
      case treated_lhs do
        %Condition{} ->
          conditions = [treated_lhs, treated_rhs]

          {%Condition{
             operator: operator,
             conditions: conditions
           }, rhs_cond_fields}

        _ ->
          new_cond =
            %Condition{operator: operator}
            |> Map.merge(treated_lhs)
            |> Map.merge(treated_rhs)

          {new_cond,
           [
             {String.to_atom(new_cond.source), new_cond.field, new_cond.value}
             | rhs_cond_fields
           ]}
      end

    {condition, params, new_cond_fields}
  end

  def build({{:., _, [{entity_alias, _, _}, field]}, _, _}, params, condition_fields) do
    data = %{
      source: Atom.to_string(entity_alias),
      field: field
    }

    {data, params, condition_fields}
  end

  def build({:^, _, [{field, _, _} = v]}, params, condition_fields) do
    data = %{
      value: Atom.to_string(field)
    }

    {data, Keyword.put(params, field, v), condition_fields}
  end

  def build(value, params, condition_fields) do
    bound_name = "param_" <> Integer.to_string(length(params))

    data = %{
      value: bound_name
    }

    new_params = Keyword.put(params, String.to_atom(bound_name), value)

    {data, new_params, condition_fields}
  end
end
