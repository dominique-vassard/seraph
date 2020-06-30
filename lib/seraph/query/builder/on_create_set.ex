defmodule Seraph.Query.Builder.OnCreateSet do
  @behaviour Seraph.Query.Operation

  alias Seraph.Query.Builder.{Entity, OnCreateSet, Set}

  defstruct [:expressions]

  @type t :: %__MODULE__{
          expressions: [Entity.Property.t() | Entity.Label.t()]
        }

  @impl true
  @spec build(Macro.t(), Macro.Env.t()) :: %{on_create_set: OnCreateSet.t(), params: Keyword.t()}
  def build(ast, env) do
    data = Set.build(ast, env)

    %{
      params: data.params,
      on_create_set: struct!(OnCreateSet, Map.from_struct(data.set))
    }
  end

  @impl true
  @spec check(OnCreateSet.t(), Seraph.Query.t()) :: :ok | {:error, String.t()}
  def check(on_create_set_data, query) do
    set = %Set{
      expressions: on_create_set_data.expressions
    }

    case Set.check(set, query) do
      :ok ->
        :ok

      {:error, error} ->
        {:error, String.replace(error, "[Set]", "[OnCreateSet]")}
    end
  end

  defimpl Seraph.Query.Cypher, for: OnCreateSet do
    @spec encode(OnCreateSet.t(), Keyword.t()) :: String.t()
    def encode(data, opts) do
      str =
        Set
        |> struct!(Map.from_struct(data))
        |> Seraph.Query.Cypher.encode(opts)

      if String.length(str) > 0 do
        "ON CREATE #{str}"
      end
    end
  end
end
