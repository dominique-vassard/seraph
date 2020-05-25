defmodule Seraph.Query.Builder.Where do
  @behaviour Seraph.Query.Operation

  alias Seraph.Query.Builder.Condition
  alias Seraph.Query.Builder.Where
  alias Seraph.Query.Builder.Helper

  @valid_operators [
    # left and right
    # :and,
    # left and right
    # :or,
    # # left <> right
    # :<>,
    # # exists(val)
    # :exists,
    # left == right
    # :==
    # left > right
    # :>,
    # # left >= right
    # :>=,
    # # left < right
    # :<,
    # # left <= right
    # :<=,
    # # is_nil(val)
    # :is_nil,
    # # not(entity)
    # # not is_nil(val)
    # # not exists(val)
    # :not,
    # # left starts_with right
    # :starts_with,
    # # left ends_with right
    # :ends_with,
    # # left ends_with right
    # :contains,
    # # left =~ ~r//
    # :=~,
    # # left in []
    # :in,
    # :min,
    # :max,
    # :count,
    # :sum,
    # :avg
  ]

  @unary_operators [:is_nil, :not]
  @binary_operators [:and, :or, :==]
  @valid_operators @unary_operators ++ @binary_operators

  defstruct [:condition, :data, :params]

  @type t :: %__MODULE__{
          condition: Seraph.Query.Builder.Condition.t(),
          data: map,
          params: Keyword.t()
        }

  def valid_operators(), do: @valid_operators

  @impl true
  def build(ast, _env, params \\ [])

  def build({operator, _, [_, _]}, _env, _) when operator not in @valid_operators do
    raise ArgumentError, "Unknown operator `#{inspect(operator)}`"
  end

  # left - right operation
  # u.uuid == "uuid-5"
  # expr1 and expr2
  def build({operator, _, [lhs, rhs]}, env, params)
      when operator in @binary_operators do
    left_data = build(lhs, env, params)
    right_data = build(rhs, env, left_data.params)

    condition =
      case Map.get(left_data, :condition) do
        %Condition{} ->
          conditions = [left_data.condition, right_data.condition]

          %Condition{
            operator: operator,
            conditions: conditions
          }

        _ ->
          %Condition{operator: operator}
          |> Map.merge(left_data.data)
          |> Map.merge(right_data.data)
      end

    %Where{
      condition: condition,
      params: right_data.params
    }
  end

  # property
  # u.uuid
  def build({{:., _, [{entity_identifier, _, _}, variable]}, _, _}, _env, params) do
    data = %{
      entity_identifier: Atom.to_string(entity_identifier),
      variable: variable
    }

    %Where{
      data: data,
      params: params
    }
  end

  # Pinned value
  def build({:^, _, [{var_name, _, _} = value]}, _env, params) do
    data = %{
      bound_name: Atom.to_string(var_name)
    }

    %Where{
      data: data,
      params: Keyword.put(params, var_name, value)
    }
  end

  def build({operator, _, [operated_data]}, env, params) when operator in @unary_operators do
    data = build(operated_data, env, params)

    draft_condition = %Condition{
      operator: operator
    }

    case Map.get(data, :condition) do
      %Condition{} = inner_cond ->
        %Where{
          condition: Map.put(draft_condition, :conditions, [inner_cond]),
          params: params
        }

      nil ->
        %Where{
          condition: Map.merge(draft_condition, data.data),
          params: params
        }
    end
  end

  # Direct value
  def build(value, _env, params) do
    index =
      Enum.filter(params, fn {key, _} ->
        String.starts_with?(Atom.to_string(key), "where__")
      end)
      |> Enum.count()

    bound_name = "where__" <> Integer.to_string(index)

    data = %{
      bound_name: bound_name
    }

    %Where{
      data: data,
      params: Keyword.put(params, String.to_atom(bound_name), value)
    }
  end

  @impl true
  @spec check(Seraph.Query.Builder.Condition.t(), Seraph.Query.t()) :: :ok | {:error, String.t()}
  def check(%Condition{entity_identifier: nil, conditions: inner_conditions}, query)
      when is_list(inner_conditions) do
    Enum.reduce_while(inner_conditions, :ok, fn inner_condition, _ ->
      case check(inner_condition, query) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  def check(
        %Condition{
          entity_identifier: entity_identifier,
          variable: variable,
          bound_name: bound_name
        },
        query
      ) do
    case Map.fetch(query.identifiers, entity_identifier) do
      {:ok, entity} ->
        Helper.check_queryable_property(entity.queryable, variable)

        {value, check_type} =
          if is_nil(bound_name) do
            {nil, false}
          else
            value = Keyword.fetch!(query.params, String.to_atom(bound_name))
            {value, true}
          end

        Helper.check_property(entity.queryable, variable, value, check_type)

      :error ->
        message = "Unkown identifier `#{entity_identifier}` in `:where`"
        {:error, message}
    end
  end
end