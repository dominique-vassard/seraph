defmodule Neo4jex.Changeset do
  def cast(%{__struct__: entity} = data, params, permitted, opts \\ []) do
    types = changeset_properties_types(entity)

    cs_data = Map.drop(data, [:start_node, :end_node])
    cs_params = Map.drop(params, [:start_node, :end_node])

    cs_permitted =
      permitted
      |> List.delete(:start_node)
      |> List.delete(:end_node)

    changeset = Ecto.Changeset.cast({cs_data, types}, cs_params, cs_permitted, opts)

    case entity.__schema__(:entity_type) do
      :node ->
        changeset

      :relationship ->
        changeset
        |> cast_linked_node(entity, :start_node, Map.get(params, :start_node), permitted)
        |> cast_linked_node(entity, :end_node, Map.get(params, :end_node), permitted)
    end
  end

  # def cast(%{__struct__: entity} = data, params, permitted, opts \\ []) do
  #   types = entity.__schema__(:changeset_properties) |> Keyword.to_list() |> Enum.into(%{})

  #   Ecto.Changeset.cast({data, types}, params, permitted, opts)
  # end

  def change(%{__struct__: entity} = data, changes \\ %{}) do
    types = entity.__schema__(:changeset_properties) |> Keyword.to_list() |> Enum.into(%{})
    Ecto.Changeset.change({data, types}, changes)
  end

  defdelegate add_error(changeset, key, message, keys \\ []), to: Ecto.Changeset
  defdelegate apply_changes(changeset), to: Ecto.Changeset
  defdelegate delete_change(changeset, key), to: Ecto.Changeset
  defdelegate fetch_change(changeset, key), to: Ecto.Changeset
  defdelegate fetch_change!(changeset, key), to: Ecto.Changeset
  defdelegate fetch_field(changeset, key), to: Ecto.Changeset
  defdelegate fetch_field!(changeset, key), to: Ecto.Changeset
  defdelegate force_change(changeset, key, value), to: Ecto.Changeset
  defdelegate get_change(changeset, key, default \\ nil), to: Ecto.Changeset
  defdelegate get_field(changeset, key, default \\ nil), to: Ecto.Changeset
  defdelegate merge(changeset1, changeset2), to: Ecto.Changeset
  defdelegate put_change(changeset, key, value), to: Ecto.Changeset
  defdelegate traverse_errors(changeset, msg_func), to: Ecto.Changeset
  defdelegate unique_constraint(changeset, field, opts \\ []), to: Ecto.Changeset
  defdelegate update_change(changeset, key, function), to: Ecto.Changeset
  defdelegate validate_acceptance(changeset, field, opts \\ []), to: Ecto.Changeset
  defdelegate validate_change(changeset, field, validator), to: Ecto.Changeset
  defdelegate validate_change(changeset, field, metadata, validator), to: Ecto.Changeset
  defdelegate validate_confirmation(changeset, field, opts \\ []), to: Ecto.Changeset
  defdelegate validate_exclusion(changeset, field, data, opts \\ []), to: Ecto.Changeset
  defdelegate validate_format(changeset, field, format, opts \\ []), to: Ecto.Changeset
  defdelegate validate_inclusion(changeset, field, data, opts \\ []), to: Ecto.Changeset
  defdelegate validate_length(changeset, field, opts), to: Ecto.Changeset
  defdelegate validate_number(changeset, field, opts), to: Ecto.Changeset
  defdelegate validate_required(changeset, fields, opts \\ []), to: Ecto.Changeset
  defdelegate validate_subset(changeset, field, data, opts \\ []), to: Ecto.Changeset
  defdelegate validations(changeset), to: Ecto.Changeset

  defp changeset_properties_types(entity) do
    entity.__schema__(:changeset_properties)
    |> Keyword.to_list()
    |> Enum.into(%{})
  end

  defp cast_linked_node(changeset, _, _, nil, _) do
    changeset
  end

  defp cast_linked_node(changeset, relationship, linked_node, node_data, permitted) do
    case linked_node in permitted do
      true ->
        queryable = extract_queryable(node_data)
        # %{__struct__: queryable} = node_data

        case queryable == relationship.__schema__(linked_node) do
          true ->
            changeset
            |> put_change(linked_node, node_data)

          false ->
            changeset
            |> add_error(
              linked_node,
              "#{inspect(linked_node)} must be a #{
                Atom.to_string(relationship.__schema__(linked_node))
              }."
            )
        end

      false ->
        changeset
    end
  end

  defp extract_queryable(%Ecto.Changeset{data: data}) do
    do_extract_queryable(data)
  end

  defp extract_queryable(data) do
    do_extract_queryable(data)
  end

  defp do_extract_queryable(data) do
    %{__struct__: queryable} = data
    queryable
  end
end
