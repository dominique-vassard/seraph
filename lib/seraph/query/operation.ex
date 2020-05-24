defmodule Seraph.Query.Operation do
  @callback build(Macro.t(), Macro.Env.t()) :: map()
  @callback check(struct(), Seraph.Query.t()) :: :ok | {:error, String.t()}
  @callback prepare(struct(), Seraph.Query.t(), Keyword.t()) :: struct()

  @optional_callbacks prepare: 3
end
