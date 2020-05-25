defmodule Seraph.Query.Builder.Entity.Node do
  alias Seraph.Query.Builder.Entity
  alias Seraph.Query.Builder.Entity.Node
  alias Seraph.Query.Builder.Entity.Property

  @moduledoc false
  defstruct [:identifier, :alias, labels: [], queryable: Seraph.Node, properties: []]

  @type t :: %__MODULE__{
          queryable: Seraph.Repo.queryable() | Seraph.Node.t(),
          identifier: nil | String.t(),
          labels: [String.t()],
          alias: nil | String.t(),
          properties: [Property.t()]
        }

  @spec from_queryable(Seraph.Repo.queryable(), map | Keyword.t()) :: %{
          entity: Node.t(),
          params: Keyword.t()
        }
  def from_queryable(queryable, properties) when is_list(properties) do
    props = Enum.into(properties, %{})

    from_queryable(queryable, props)
  end

  def from_queryable(queryable, properties, identifier \\ "n") do
    additional_labels = Map.get(properties, :additionalLabels, [])
    new_props = Map.drop(properties, [:additionalLabels])

    node = %Node{
      queryable: queryable,
      identifier: identifier,
      labels: [queryable.__schema__(:primary_label) | additional_labels]
    }

    props = Property.from_map(new_props, node)

    node
    |> Map.put(:properties, props)
    |> Entity.manage_params([])
  end

  defimpl Seraph.Query.Cypher, for: Node do
    @spec encode(Seraph.Query.Builder.Entity.Node.t(), Keyword.t()) :: String.t()
    def encode(%Node{alias: node_alias, identifier: identifier}, operation: :return)
        when not is_nil(node_alias) do
      "#{identifier} AS #{node_alias}"
    end

    def encode(%Node{identifier: identifier}, operation: :return) do
      "#{identifier}"
    end

    def encode(%Node{identifier: identifier, labels: [], properties: []}, _) do
      "(#{identifier})"
    end

    def encode(%Node{identifier: nil, labels: labels, properties: properties}, _) do
      labels_str =
        Enum.map(labels, fn label ->
          ":#{label}"
        end)
        |> Enum.join()

      props =
        Enum.map(properties, &Seraph.Query.Cypher.encode/1)
        |> Enum.join(",")

      "(#{labels_str} {#{props}})"
    end

    def encode(%Node{identifier: identifier, labels: labels, properties: []}, _) do
      labels_str =
        Enum.map(labels, fn label ->
          ":#{label}"
        end)
        |> Enum.join()

      "(#{identifier}#{labels_str})"
    end

    def encode(%Node{identifier: identifier, labels: labels, properties: properties}, _) do
      labels_str =
        Enum.map(labels, fn label ->
          ":#{label}"
        end)
        |> Enum.join()

      props =
        Enum.map(properties, &Seraph.Query.Cypher.encode/1)
        |> Enum.join(",")

      "(#{identifier}#{labels_str} {#{props}})"
    end
  end
end
