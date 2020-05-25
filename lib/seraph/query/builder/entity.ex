defmodule Seraph.Query.Builder.Entity do
  alias Seraph.Query.Builder.Entity
  @type t :: Entity.Node.t() | Entity.Relationship.t()

  @spec manage_params(Entity.t(), Keyword.t()) :: %{entity: Entity.t(), params: Keyword.t()}
  def manage_params(%Entity.Node{} = entity, current_params) do
    do_manage_params(entity, current_params)
  end

  def manage_params(%Entity.Relationship{} = relationship, current_params) do
    %{entity: start_node, params: updated_cur_params} =
      manage_params(relationship.start, current_params)

    %{entity: end_node, params: updated_nodes_params} =
      manage_params(relationship.end, updated_cur_params)

    relationship
    |> Map.put(:start, start_node)
    |> Map.put(:end, end_node)
    |> do_manage_params(updated_nodes_params)
  end

  @spec do_manage_params(Entity.t(), Keyword.t()) :: %{entity: Entity.t(), params: Keyword.t()}
  defp do_manage_params(%{properties: properties} = entity, current_params) do
    %{props: new_props, params: params} =
      properties
      |> Enum.reduce(%{props: [], params: current_params}, fn property, prop_data ->
        value = property.value

        bound_name =
          case value do
            {pinned_name, _, _} when is_atom(pinned_name) ->
              Atom.to_string(pinned_name)

            _ ->
              bound_prefix =
                if is_nil(property.entity_identifier) do
                  "prop__" <> Atom.to_string(property.name)
                else
                  property.entity_identifier <> "_" <> Atom.to_string(property.name)
                end

              suffix =
                Enum.filter(prop_data.params, fn {param_name, _} ->
                  String.starts_with?(Atom.to_string(param_name), bound_prefix)
                end)
                |> Enum.count()

              bound_prefix <> "_" <> Integer.to_string(suffix)
          end

        new_prop =
          property
          |> Map.put(:bound_name, bound_name)
          |> Map.put(:value, nil)

        %{
          prop_data
          | props: [new_prop | prop_data.props],
            params: Keyword.put(prop_data.params, String.to_atom(bound_name), value)
        }
      end)

    %{entity: Map.put(entity, :properties, new_props), params: params}
  end
end
