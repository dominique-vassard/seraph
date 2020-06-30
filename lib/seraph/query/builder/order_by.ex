defmodule Seraph.Query.Builder.OrderBy do
  @behaviour Seraph.Query.Operation

  alias Seraph.Query.Builder.{Entity, Helper, OrderBy}

  defstruct [:orders, :raw_orders]

  @type t :: %__MODULE__{
          orders: nil | [Entity.t() | Entity.Value.t()],
          raw_orders: nil | [Entity.Order.t()]
        }

  @impl true
  @spec build(Macro.t(), Macro.Env.t()) :: OrderBy.t()
  def build(ast, _env) do
    %OrderBy{
      orders: nil,
      raw_orders: Enum.map(ast, &Entity.Order.build_from_ast/1)
    }
  end

  @impl true
  @spec check(OrderBy.t(), Seraph.Query.t()) :: :ok | {:error, String.t()}
  def check(%OrderBy{raw_orders: raw_orders}, %Seraph.Query{} = query) do
    do_check(raw_orders, query)
  end

  @impl true
  @spec prepare(OrderBy.t(), Seraph.Query.t(), Keyword.t()) :: OrderBy.t()
  def prepare(%OrderBy{raw_orders: raw_orders}, %Seraph.Query{} = query, _opts) do
    orders =
      Enum.map(raw_orders, fn
        %Entity.Order{entity: %Entity.EntityData{property: nil} = entity} = order ->
          new_entity = fetch_entity(entity.entity_identifier, query)

          %{order | entity: new_entity}

        %Entity.Order{entity: entity_data} = order ->
          entity = fetch_entity(entity_data.entity_identifier, query)

          new_entity = %Entity.Property{
            entity_identifier: entity.identifier,
            entity_queryable: entity.queryable,
            name: entity_data.property
          }

          %{order | entity: new_entity}
      end)

    %OrderBy{orders: orders, raw_orders: nil}
  end

  @spec fetch_entity(String.t(), Seraph.Query.t()) :: Entity.t()
  defp fetch_entity(identifier, query) do
    case Map.fetch(query.identifiers, identifier) do
      {:ok, entity} ->
        entity

      :error ->
        Map.fetch!(query.operations[:return].variables, identifier)
    end
  end

  @spec do_check([Entity.Order.t()], Seraph.Query.t(), :ok | {:error, String.t()}) ::
          :ok | {:error, String.t()}
  defp do_check(raw_orders, query, result \\ :ok)

  defp do_check([], _, result) do
    result
  end

  defp do_check([%Entity.Order{entity: entity_data} | rest], query, :ok) do
    with {:ok, return} <- Keyword.fetch(query.operations, :return),
         {:ok, real_entity} <-
           do_check_identifier_or_alias(entity_data, query.identifiers, return.raw_variables),
         :ok <- do_check_property(real_entity, entity_data.property) do
      do_check(rest, query, :ok)
    else
      :error ->
        {:error, "[OrderBy] A RETURN clause should be defined"}

      {:error, _} = error ->
        error
    end
  end

  @spec do_check(Entity.t(), map, [Entity.EntityData.t() | Entity.Value.t() | Entity.Function.t()]) ::
          :ok | {:error, String.t()}
  defp do_check_identifier_or_alias(entity_data, identifiers, return_data) do
    return_aliases =
      Enum.reduce(return_data, %{}, fn
        %{alias: nil}, aliases ->
          aliases

        %{alias: data_alias} = entity_data, aliases ->
          Map.put(aliases, data_alias, entity_data)
      end)

    case Map.fetch(identifiers, entity_data.entity_identifier) do
      {:ok, entity} ->
        {:ok, entity}

      :error ->
        case Map.fetch(return_aliases, String.to_atom(entity_data.entity_identifier)) do
          {:ok, entity} ->
            {:ok, entity}

          :error ->
            {:error,
             "[OrderBy] `#{entity_data.entity_identifier}` should be defined before usage"}
        end
    end
  end

  @spec do_check_property(Entity.t() | any, atom) :: :ok | {:error, String.t()}
  defp do_check_property(%Entity.Relationship{} = entity_data, property) do
    Helper.check_property(entity_data.queryable, property, nil, false)
  end

  defp do_check_property(%Entity.Node{} = entity_data, property) do
    Helper.check_property(entity_data.queryable, property, nil, false)
  end

  defp do_check_property(_, _) do
    :ok
  end

  defimpl Seraph.Query.Cypher, for: OrderBy do
    @spec encode(OrderBy.t(), Keyword.t()) :: String.t()
    def encode(%OrderBy{orders: orders}, _) do
      order_str =
        orders
        |> Enum.map(&Seraph.Query.Cypher.encode(&1, operation: :order_by))
        |> Enum.join(", ")

      if String.length(order_str) > 0 do
        """
        ORDER BY
          #{order_str}
        """
      end
    end
  end
end
