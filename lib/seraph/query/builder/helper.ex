defmodule Seraph.Query.Builder.Helper do
  @moduledoc false

  alias Seraph.Query.Builder.Entity

  @doc """
  Check that the given property is defined for the given queryable.
  Check also property if a value is given.
  """
  @spec check_property(Seraph.Repo.queryable(), atom, any, boolean) :: :ok | {:error, String.t()}
  def check_property(queryable, property_name, value, check_type \\ true) do
    case check_queryable_property(queryable, property_name) do
      :ok ->
        if check_type do
          check_property_type(queryable, property_name, value)
        else
          :ok
        end

      error ->
        error
    end
  end

  @doc """
  Check that the given property is defined for the given queryable.
  """
  @spec check_queryable_property(Seraph.Repo.queryable(), atom) :: :ok | {:error, String.t()}
  def check_queryable_property(dummy_queryable, _)
      when dummy_queryable in [Seraph.Node, Seraph.Relationship] do
    :ok
  end

  def check_queryable_property(queryable, property_name) do
    if property_name in queryable.__schema__(:properties) do
      :ok
    else
      {:error,
       "Property #{inspect(property_name)} does not exist in schema #{inspect(queryable)}"}
    end
  end

  @spec check_property_type(Seraph.Repo.queryable(), atom, any) :: :ok | {:error, String.t()}
  defp check_property_type(dummy_queryable, _, _)
       when dummy_queryable in [Seraph.Node, Seraph.Relationship] do
    :ok
  end

  defp check_property_type(queryable, property_name, value) do
    type = queryable.__schema__(:type, property_name)

    case Ecto.Type.dump(type, value) do
      {:ok, _} ->
        :ok

      :error ->
        message =
          "Value `#{inspect(value)}` for `#{property_name}` does not match type #{inspect(type)}"

        {:error, message}
    end
  end

  @doc """
  Build the identifiers list (to be used in Seraph.Query) from the given Entity
  """
  @spec build_identifiers(Entity.t(), %{String.t() => Entity.t()}, atom) :: %{
          String.t() => Entity.t()
        }
  def build_identifiers(entity, current_identifiers, operation \\ :match)

  def build_identifiers(%Entity.Node{identifier: nil}, current_identifiers, _) do
    current_identifiers
  end

  def build_identifiers(%Entity.Node{} = entity, current_identifiers, _) do
    check_identifier_presence(current_identifiers, entity.identifier)
    Map.put(current_identifiers, entity.identifier, entity)
  end

  def build_identifiers(%Entity.Relationship{} = relationship, current_identifiers, operation) do
    new_identifiers =
      current_identifiers
      |> build_relationship_nodes_identifiers(relationship.start, operation)
      |> build_relationship_nodes_identifiers(relationship.end, operation)

    if is_nil(relationship.identifier) do
      new_identifiers
    else
      check_identifier_presence(current_identifiers, relationship.identifier)
      Map.put(new_identifiers, relationship.identifier, relationship)
    end
  end

  @spec build_relationship_nodes_identifiers(%{String.t() => Entity.t()}, Entity.t(), atom) :: %{
          String.t() => Entity.t()
        }
  defp build_relationship_nodes_identifiers(current_identifiers, %Entity.Node{identifier: nil}, _) do
    current_identifiers
  end

  defp build_relationship_nodes_identifiers(
         current_identifiers,
         %Entity.Node{identifier: identifier} = node_data,
         _
       ) do
    case Map.fetch(current_identifiers, identifier) do
      :error ->
        Map.put(current_identifiers, identifier, node_data)

      {:ok, %Entity.Node{queryable: Seraph.Node}} ->
        current_identifiers
        |> Map.drop([identifier])
        |> Map.put(identifier, node_data)

      {:ok, %Entity.Node{queryable: queryable}} ->
        if queryable != node_data.queryable do
          message =
            "Identifier `#{identifier}` for schema `#{inspect(node_data.queryable)}` is already used for schema `#{
              inspect(queryable)
            }`"

          raise ArgumentError, message
        end

      {:ok, %Entity.Relationship{}} ->
        raise ArgumentError, "Identifier `#{identifier}` is already taken."
    end
  end

  @doc """
  Check that the candidate identifiers exists in current identifiers list.
  """
  @spec check_identifier_presence(map, String.t()) :: :ok
  def check_identifier_presence(identifiers, candidate) do
    case Map.fetch(identifiers, candidate) do
      {:ok, _} -> raise ArgumentError, "Identifier `#{candidate}` is already taken."
      :error -> :ok
    end
  end
end
