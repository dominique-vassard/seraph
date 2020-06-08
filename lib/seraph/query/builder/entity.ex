defmodule Seraph.Query.Builder.Entity do
  alias Seraph.Query.Builder.Entity
  @type t :: Entity.Node.t() | Entity.Relationship.t()
  @type all ::
          Entity.EntityData.t()
          | Entity.Function.t()
          | Entity.Label.t()
          | Entity.Node.t()
          | Entity.Property.t()
          | Entity.Relationship.t()
          | Entity.Value.t()

  @spec build_properties(Seraph.Repo.queryable(), nil | String.t(), Keyword.t()) :: [
          Entity.Property
        ]
  def build_properties(queryable, identifier, properties) do
    Enum.reduce(properties, [], fn {prop_key, prop_value}, prop_list ->
      property = %Entity.Property{
        entity_identifier: identifier,
        entity_queryable: queryable,
        name: prop_key,
        value: interpolate(prop_value)
      }

      [property | prop_list]
    end)
  end

  @spec interpolate(Macro.t()) :: Macro.t()
  defp interpolate({:^, _, [{name, _ctx, _env} = value]}) when is_atom(name) do
    value
  end

  defp interpolate(value) do
    value
  end

  @spec extract_params(Entity.t(), Keyword.t(), String.t()) :: %{
          entity: Entity.t(),
          params: Keyword.t()
        }
  def extract_params(%Entity.Node{} = entity, current_params, prefix) do
    do_extract_params(entity, current_params, prefix)
  end

  def extract_params(%Entity.Relationship{} = relationship, current_params, prefix) do
    %{entity: start_node, params: updated_cur_params} =
      extract_params(relationship.start, current_params, prefix)

    %{entity: end_node, params: updated_nodes_params} =
      extract_params(relationship.end, updated_cur_params, prefix)

    relationship
    |> Map.put(:start, start_node)
    |> Map.put(:end, end_node)
    |> do_extract_params(updated_nodes_params, prefix)
  end

  def extract_params(%Entity.Property{value: %{__struct__: _}} = property, params, _prefix) do
    %{entity: property, params: params}
  end

  def extract_params(%Entity.Property{} = property, current_params, prefix) do
    {property, params} = Entity.Property.extract_params(property, current_params, prefix)
    %{entity: property, params: params}
  end

  def extract_params(%Entity.Function{args: inner_entities} = entity, current_params, prefix) do
    %{entities: new_args, params: params} =
      Enum.reduce(inner_entities, %{entities: [], params: current_params}, fn inner_entity,
                                                                              data ->
        %{entity: new_inner_entity, params: new_params} =
          extract_params(inner_entity, data.params, prefix)

        %{data | entities: [new_inner_entity | data.entities], params: new_params}
      end)

    %{entity: Map.put(entity, :args, new_args), params: params}
  end

  def extract_params(%Entity.Value{} = data, current_params, prefix) do
    bound_name =
      case data.value do
        {value_name, _, _} ->
          Atom.to_string(value_name)

        _ ->
          index =
            Enum.filter(current_params, fn {key, _} ->
              String.starts_with?(Atom.to_string(key), prefix)
            end)
            |> Enum.count()

          prefix <> Integer.to_string(index)
      end

    new_data =
      data
      |> Map.put(:bound_name, bound_name)
      |> Map.put(:value, nil)

    %{
      entity: new_data,
      params: Keyword.put(current_params, String.to_atom(bound_name), data.value)
    }
  end

  def extract_params(entity, params, _prefix) do
    %{entity: entity, params: params}
  end

  @spec do_extract_params(Entity.t(), Keyword.t(), String.t()) :: %{
          entity: Entity.t(),
          params: Keyword.t()
        }
  defp do_extract_params(%{properties: properties} = entity, current_params, prefix) do
    %{props: new_props, params: params} =
      properties
      |> Enum.reduce(%{props: [], params: current_params}, fn entity, prop_data ->
        {new_prop, params} = Entity.Property.extract_params(entity, prop_data.params, prefix)

        %{prop_data | props: [new_prop | prop_data.props], params: params}
      end)

    %{entity: Map.put(entity, :properties, new_props), params: params}
  end
end
