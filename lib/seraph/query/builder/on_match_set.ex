defmodule Seraph.Query.Builder.OnMatchSet do
  @moduledoc false

  @behaviour Seraph.Query.Operation

  alias Seraph.Query.Builder.{Entity, OnMatchSet, Set}

  defstruct [:expressions]

  @type t :: %__MODULE__{
          expressions: [Entity.Property.t() | Entity.Label.t()]
        }

  @doc """
  Build a OnMatchSet from ast.
  """
  @impl true
  @spec build(Macro.t(), Macro.Env.t()) :: %{on_match_set: OnMatchSet.t(), params: Keyword.t()}
  def build(ast, env) do
    data = Set.build(ast, env)

    %{
      params: data.params,
      on_match_set: %OnMatchSet{expressions: data.set.expressions}
    }
  end

  @doc """
  Check OnMatchSet validity.

  - See `Seraph.Query.Builder.Set.check/2`
  """
  @impl true
  @spec check(OnMatchSet.t(), Seraph.Query.t()) :: :ok | {:error, String.t()}
  def check(on_match_set_data, query) do
    set = %Set{
      expressions: on_match_set_data.expressions
    }

    case Set.check(set, query) do
      :ok ->
        :ok

      {:error, error} ->
        {:error, String.replace(error, "[Set]", "[OnMatchSet]")}
    end
  end

  defimpl Seraph.Query.Cypher, for: OnMatchSet do
    @spec encode(OnMatchSet.t(), Keyword.t()) :: String.t()
    def encode(data, opts) do
      str =
        Set
        |> struct!(Map.from_struct(data))
        |> Seraph.Query.Cypher.encode(opts)

      if String.length(str) > 0 do
        "ON MATCH #{str}"
      end
    end
  end
end
