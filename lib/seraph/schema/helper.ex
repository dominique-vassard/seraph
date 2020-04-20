defmodule Seraph.Schema.Helper do
  @moduledoc false

  @valid_ecto_types [
    :binary_id,
    :integer,
    :float,
    :boolean,
    :string,
    :decimal,
    :date,
    :time,
    :time_usec,
    :naive_datetime,
    :naive_datetime_usec,
    :utc_datetime,
    :utc_datetime_usec
  ]

  @valid_seraph_types [
    :point2d,
    :point3d
  ]

  @doc """
  Check if the given property has a valid type.
  """
  @spec check_property_type!(atom, atom) :: nil
  def check_property_type!(:id, _) do
    raise ArgumentError, ":id is not an authorized name for property.
    It conflicts with Neo4j internal id."
  end

  def check_property_type!(name, type) do
    unless type in valid_types() do
      raise ArgumentError,
            "invalid or unknown type #{inspect(type)} for field #{inspect(name)}"
    end
  end

  @doc """
  Return valid type that can be used within Seraph.
  """
  @spec valid_types :: [atom]
  def valid_types do
    @valid_ecto_types ++ @valid_seraph_types
  end

  @doc """
  Return complete module name from its alias.
  """
  @spec expand_alias(tuple, map) :: tuple
  def expand_alias({:__aliases__, _, _} = ast, env),
    do: Macro.expand(ast, %{env | function: {:__schema__, 2}})

  def expand_alias(ast, _env),
    do: ast
end
