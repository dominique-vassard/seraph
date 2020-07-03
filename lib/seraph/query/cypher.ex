defprotocol Seraph.Query.Cypher do
  @moduledoc false
  @spec encode(any, Keyword.t()) :: String.t()
  def encode(data, opts \\ [])
end

defimpl Seraph.Query.Cypher, for: [Integer, String, Float] do
  @spec encode(number | String.t(), Keyword.t()) :: String.t()
  def encode(value, _) do
    value
  end
end
