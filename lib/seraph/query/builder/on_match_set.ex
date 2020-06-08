defmodule Seraph.Query.Builder.OnMatchSet do
  @behaviour Seraph.Query.Operation

  alias Seraph.Query.Builder.{OnMatchSet, Set}

  defstruct [:expressions]

  @type t :: %__MODULE__{
          expressions: [Entity.Property.t() | Entity.Label.t()]
        }

  @impl true
  def build(ast, env) do
    data = Set.build(ast, env)

    %{
      params: data.params,
      on_match_set: %OnMatchSet{expressions: data.set.expressions}
    }
  end

  @impl true
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
    def encode(data, opts) do
      str =
        Set
        |> struct!(Map.from_struct(data))
        |> Seraph.Query.Cypher.encode(opts)

      "ON MATCH #{str}"
    end
  end
end
