defmodule Seraph.Query.Builder.Entity.Property do
  @moduledoc false

  alias Seraph.Query.Builder.Entity.Property

  defstruct [:alias, :bound_name, :entity_identifier, :entity_queryable, :name, :value, :type]

  @type t :: %__MODULE__{
          alias: nil | String.t(),
          bound_name: nil | String.t(),
          entity_identifier: String.t(),
          entity_queryable: Seraph.Repo.queryable() | Seraph.Node.t(),
          name: atom(),
          type: atom,
          value: any()
        }

  @doc """
  Build a Property list from a map.
  """
  @spec from_map(map, Seraph.Query.Builder.Entity.t()) :: [Property.t()]
  def from_map(properties, entity) do
    properties
    |> Enum.map(fn {prop_key, prop_value} ->
      %Property{
        entity_identifier: entity.identifier,
        entity_queryable: entity.queryable,
        name: prop_key,
        value: prop_value
      }
    end)
  end

  @doc """
  Take a property, extract value from it and convert into bindings.
  Return the new Property ith bindings.
  """
  @spec extract_params(Property.t(), Keyword.t(), String.t()) :: {Property.t(), Keyword.t()}
  def extract_params(%Property{} = property, current_params, prefix) do
    value = property.value

    bound_name =
      case value do
        {pinned_name, _, _} when is_atom(pinned_name) ->
          Atom.to_string(pinned_name)

        _ ->
          bound_prefix =
            if is_nil(property.entity_identifier) do
              prefix <> "prop__" <> Atom.to_string(property.name)
            else
              # ON_CREATE and ON_MATCH can work on same property
              # We need to differentiate them
              used_prefix =
                if prefix in ["on_create__set__", "on_match__set__"] do
                  prefix
                else
                  ""
                end

              used_prefix <> property.entity_identifier <> "_" <> Atom.to_string(property.name)
            end

          suffix =
            Enum.filter(current_params, fn {param_name, _} ->
              String.starts_with?(Atom.to_string(param_name), bound_prefix)
            end)
            |> Enum.count()

          bound_prefix <> "_" <> Integer.to_string(suffix)
      end

    new_prop =
      property
      |> Map.put(:bound_name, bound_name)
      |> Map.put(:value, nil)

    {
      new_prop,
      Keyword.put(current_params, String.to_atom(bound_name), value)
    }
  end

  defimpl Seraph.Query.Cypher, for: Property do
    @spec encode(Property.t(), Keyword.t()) :: String.t()
    def encode(%Property{alias: prop_alias}, operation: :order_by) when not is_nil(prop_alias) do
      "#{prop_alias}"
    end

    def encode(%Property{alias: prop_alias, entity_identifier: entity_identifier, name: name},
          operation: :return
        )
        when not is_nil(prop_alias) do
      "#{entity_identifier}.#{name} AS #{prop_alias}"
    end

    def encode(%Property{entity_identifier: entity_identifier, name: name}, operation: operation)
        when operation in [:return, :remove, :order_by] do
      "#{entity_identifier}.#{name}"
    end

    def encode(
          %Property{entity_identifier: entity_identifier, name: name, value: value},
          operation: :set
        )
        when not is_nil(value) do
      "#{entity_identifier}.#{Atom.to_string(name)} = " <>
        Seraph.Query.Cypher.encode(value, operation: :set)
    end

    def encode(
          %Property{entity_identifier: entity_identifier, bound_name: bound_name, name: name},
          operation: :set
        ) do
      "#{entity_identifier}.#{Atom.to_string(name)} = $#{bound_name}"
    end

    def encode(%Property{bound_name: bound_name, name: name}, _) do
      "#{Atom.to_string(name)}: $#{bound_name}"
    end
  end
end
