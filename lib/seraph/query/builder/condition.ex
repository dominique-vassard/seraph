defmodule Seraph.Query.Builder.Condition do
  alias Seraph.Query.Builder.Condition
  @moduledoc false

  @variables [
    :entity_identifier,
    :variable,
    :bound_name,
    :operator,
    :value,
    :conditions,
    join_operator: :and
  ]
  defstruct @variables

  alias Seraph.Query.Builder.Condition

  @type t :: %__MODULE__{
          entity_identifier: nil | String.t(),
          variable: atom(),
          bound_name: nil | String.t(),
          operator: atom(),
          value: any(),
          conditions: nil | [Condition.t()],
          join_operator: :and | :or
        }

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

  defimpl Seraph.Query.Cypher, for: Condition do
    def encode(condition, _) do
      str = do_encode(condition)

      if String.length(str) > 0 do
        """
        WHERE
          #{str}
        """
      end
    end

    defp do_encode(nil) do
      ""
    end

    defp do_encode(%Condition{operator: operator, conditions: [c1, c2]}) do
      condition1 = do_encode(c1)
      condition2 = do_encode(c2)

      "#{condition1} #{encode_operator(operator)} #{condition2}"
    end

    defp do_encode(%Condition{operator: operator, conditions: condition})
         when not is_nil(condition) do
      str_cond = do_encode(condition)

      "#{encode_operator(operator)} #{str_cond}"
    end

    # defp do_encode(%Condition{
    #        operator: operator,
    #        variable: %Seraph.Query.Builder.Entity.Relationship{} = relationship
    #      }) do
    #   %{
    #     start: %{identifier: start_identifier},
    #     end: %{identifier: end_identifier},
    #     type: rel_type
    #   } = relationship

    #   "#{encode_operator(operator)} (#{start_identifier})-[:#{rel_type}]->(#{end_identifier})"
    # end

    defp do_encode(%Condition{
           entity_identifier: entity_identifier,
           bound_name: bound_name,
           variable: variable,
           operator: operator
         })
         when not is_nil(bound_name) do
      "#{entity_identifier}.#{variable} #{encode_operator(operator)} $#{bound_name}"
    end

    defp do_encode(%Condition{
           entity_identifier: entity_identifier,
           variable: variable,
           operator: operator
         })
         when operator == :is_nil do
      "#{entity_identifier}.#{variable} #{encode_operator(operator)}"
    end

    defp do_encode(%Condition{
           entity_identifier: entity_identifier,
           variable: variable,
           value: nil
         }) do
      do_encode(%Condition{
        entity_identifier: entity_identifier,
        variable: variable,
        operator: :is_nil
      })
    end

    defp do_encode(%Condition{
           entity_identifier: entity_identifier,
           variable: variable,
           operator: operator,
           value: value
         }) do
      "#{entity_identifier}.#{variable} #{encode_operator(operator)} $#{value}"
    end

    defp encode_operator(:==) do
      "="
    end

    defp encode_operator(:!=) do
      "<>"
    end

    defp encode_operator(:in) do
      "IN"
    end

    defp encode_operator(:is_nil) do
      "IS NULL"
    end

    defp encode_operator(operator) do
      operator
      |> Atom.to_string()
      |> String.upcase()
    end
  end
end
