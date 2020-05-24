defmodule Seraph.Query.Builder.Helper do
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
          "value `#{inspect(value)}` for `#{property_name}` does not match type #{inspect(type)}"

        {:error, message}
    end
  end
end
