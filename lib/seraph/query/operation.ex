defmodule Seraph.Query.Operation do
  @moduledoc false
  @callback build(Macro.t(), Macro.Env.t()) :: map()
  @callback check(struct(), Seraph.Query.t()) :: :ok | {:error, String.t()}
  @callback check(struct(), Seraph.Query.t()) :: :ok | {:error, String.t()}
  @callback prepare(struct(), Seraph.Query.t(), Keyword.t()) :: map

  @optional_callbacks prepare: 3
end
