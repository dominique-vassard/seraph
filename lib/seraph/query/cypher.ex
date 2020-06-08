defprotocol Seraph.Query.Cypher do
  @spec encode(any, Keyword.t()) :: String.t()
  def encode(data, opts \\ [])
end

defimpl Seraph.Query.Cypher, for: [Integer, String, Float] do
  def encode(value, _) do
    value
  end
end
