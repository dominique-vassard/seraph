defmodule Seraph.Schema.Helper do
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

  @spec valid_types :: [atom]
  def valid_types do
    @valid_ecto_types ++ @valid_seraph_types
  end

  def expand_alias({:__aliases__, _, _} = ast, env),
    do: Macro.expand(ast, %{env | function: {:__schema__, 2}})

  def expand_alias(ast, _env),
    do: ast
end
