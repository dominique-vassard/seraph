defprotocol Seraph.Query.Cypher do
  @spec encode(any, Keyword.t()) :: String.t()
  def encode(data, opts \\ [])
end
