defmodule Seraph.Query.Builder.Limit do
  @behaviour Seraph.Query.Operation

  alias Seraph.Query.Builder.Limit
  defstruct [:value, :bound_name]

  @type t :: %__MODULE__{
          value: non_neg_integer(),
          bound_name: String.t()
        }

  @impl true
  def build({:^, _, [{bound_name, _, _} = value]}, _env) do
    limit = %Limit{
      bound_name: Atom.to_string(bound_name),
      value: nil
    }

    %{
      limit: limit,
      params: Keyword.put([], bound_name, value)
    }
  end

  def build(value, _env) do
    limit = %Limit{
      bound_name: nil,
      value: value
    }

    %{limit: limit, params: []}
  end

  @impl true
  def check(%Limit{bound_name: bound_name, value: nil}, %Seraph.Query{} = query) do
    value = Keyword.fetch!(query.params, String.to_atom(bound_name))

    do_check_value(value)
  end

  def check(%Limit{bound_name: nil, value: value}, %Seraph.Query{}) do
    do_check_value(value)
  end

  defp do_check_value(value) when is_integer(value) and value > 0 do
    :ok
  end

  defp do_check_value(_) do
    {:error, "[Limit] should be a positive integer, 0 excluded"}
  end

  defimpl Seraph.Query.Cypher, for: Limit do
    def encode(%Limit{bound_name: nil, value: value}, _) do
      "LIMIT #{value}"
    end

    def encode(%Limit{bound_name: bound_name, value: nil}, _) do
      "LIMIT $#{bound_name}"
    end
  end
end
