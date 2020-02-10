defmodule Neo4jex.Changeset do
  def cast(%{__struct__: entity} = data, params, permitted, opts \\ []) do
    types = entity.__schema__(:changeset_properties) |> Keyword.to_list() |> Enum.into(%{})

    Ecto.Changeset.cast({data, types}, params, permitted, opts)
  end

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
end
