defmodule Seraph.Query.Builder.Skip do
  @behaviour Seraph.Query.Operation

  alias Seraph.Query.Builder.Skip
  defstruct [:value, :bound_name]

  @type t :: %__MODULE__{
          value: non_neg_integer(),
          bound_name: String.t()
        }

  @impl true
  @spec build(Macro.t(), Macro.Env.t()) :: %{skip: Skip.t(), params: Keyword.t()}
  def build({:^, _, [{bound_name, _, _} = value]}, _env) do
    skip = %Skip{
      bound_name: Atom.to_string(bound_name),
      value: nil
    }

    %{
      skip: skip,
      params: Keyword.put([], bound_name, value)
    }
  end

  def build(value, _env) do
    skip = %Skip{
      bound_name: nil,
      value: value
    }

    %{skip: skip, params: []}
  end

  @impl true
  @spec check(Skip.t(), Seraph.Query.t()) :: :ok | {:error, String.t()}
  def check(%Skip{bound_name: bound_name, value: nil}, %Seraph.Query{} = query) do
    value = Keyword.fetch!(query.params, String.to_atom(bound_name))

    do_check_value(value)
  end

  def check(%Skip{bound_name: nil, value: value}, %Seraph.Query{}) do
    do_check_value(value)
  end

  defp do_check_value(value) when is_integer(value) and value > 0 do
    :ok
  end

  defp do_check_value(_) do
    {:error, "[Skip] should be a positive integer, 0 excluded"}
  end

  defimpl Seraph.Query.Cypher, for: Skip do
    @spec encode(Skip.t(), Keyword.t()) :: String.t()
    def encode(%Skip{bound_name: nil, value: value}, _) do
      "SKIP #{value}"
    end

    def encode(%Skip{bound_name: bound_name, value: nil}, _) do
      "SKIP $#{bound_name}"
    end
  end
end
