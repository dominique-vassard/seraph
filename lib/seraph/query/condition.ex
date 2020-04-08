defmodule Seraph.Query.Condition do
  @moduledoc """
  Reprensents an atomix WHERE clause
  """
  @fields [:source, :field, :operator, :value, :conditions, join_operator: :and]
  defstruct @fields

  alias Seraph.Query.Condition

  @type t :: %__MODULE__{
          source: String.t(),
          field: atom() | Seraph.Query.Builder.RelationshipExpr.t(),
          operator: atom(),
          value: any(),
          conditions: nil | [Condition.t()],
          join_operator: :and | :or
        }

  @valid_operators [:and, :or, :not, :==, :in, :>, :>=, :<, :<, :min, :max, :count, :sum, :avg]

  @doc """
  Join 2 conditions in one with the given operator
  """
  @spec join_conditions(nil | Condition.t(), nil | Condition.t(), atom) :: nil | Condition.t()
  def join_conditions(condition1, condition2, operator \\ nil)

  def join_conditions(nil, nil, _operator) do
    nil
  end

  def join_conditions(condition1, nil, _operator) do
    condition1
  end

  def join_conditions(nil, condition2, _operator) do
    condition2
  end

  def join_conditions(condition1, condition2, operator) do
    %Condition{
      operator: operator || condition1.join_operator || condition2.join_operator,
      conditions: [condition1, condition2]
    }
  end

  @doc """
  Converts Condition into a string in order to be used in query.
  """
  @spec stringify_condition(nil | Condition.t()) :: String.t()
  def stringify_condition(nil) do
    ""
  end

  def stringify_condition(%Condition{operator: operator, conditions: [c1, c2]}) do
    condition1 = stringify_condition(c1)
    condition2 = stringify_condition(c2)

    "#{condition1} #{stringify_operator(operator)} #{condition2}"
  end

  def stringify_condition(%Condition{operator: operator, conditions: condition})
      when not is_nil(condition) do
    str_cond = stringify_condition(condition)

    "#{stringify_operator(operator)} #{str_cond}"
  end

  def stringify_condition(%Condition{
        operator: operator,
        field: %Seraph.Query.Builder.RelationshipExpr{} = relationship
      }) do
    %{start: %{variable: start_variable}, end: %{variable: end_variable}, type: rel_type} =
      relationship

    "#{stringify_operator(operator)} (#{start_variable})-[:#{rel_type}]->(#{end_variable})"
  end

  def stringify_condition(%Condition{
        source: source,
        field: field,
        operator: operator
      })
      when operator == :is_nil do
    "#{source}.#{stringify_field(field)} #{stringify_operator(operator)}"
  end

  def stringify_condition(%Condition{
        source: source,
        field: field,
        operator: operator,
        value: value
      }) do
    "#{source}.#{stringify_field(field)} #{stringify_operator(operator)} {#{value}}"
  end

  @spec stringify_operator(atom) :: String.t()
  defp stringify_operator(:==) do
    "="
  end

  defp stringify_operator(:!=) do
    "<>"
  end

  defp stringify_operator(:in) do
    "IN"
  end

  defp stringify_operator(:is_nil) do
    "IS NULL"
  end

  defp stringify_operator(operator) when operator in @valid_operators do
    Atom.to_string(operator)
  end

  @spec stringify_field(atom) :: String.t()
  defp stringify_field(:id), do: stringify_field(:nodeId)
  defp stringify_field(field), do: field |> Atom.to_string()
end
