defmodule Seraph.Query.Builder.Entity.Function do
  alias Seraph.Query.Builder
  alias Seraph.Query.Builder.Entity.Function

  defstruct [:alias, :name, :args, infix?: false]

  @type t :: %__MODULE__{
          alias: atom,
          name: atom,
          args: [
            Builder.Entity.EntityData.t()
            | Builder.Entity.t()
            | Builder.Entity.Value.t()
            | Function.t()
          ],
          infix?: boolean
        }

  defimpl Seraph.Query.Cypher, for: Function do
    def encode(
          %Function{infix?: true, alias: func_alias, name: name, args: [left_arg, right_arg]},
          opts
        ) do
      name_str =
        name
        |> Atom.to_string()
        |> String.upcase()

      left_arg_str = Seraph.Query.Cypher.encode(left_arg, opts)
      right_arg_str = Seraph.Query.Cypher.encode(right_arg, opts)
      func_str = "#{left_arg_str} #{name_str} #{right_arg_str}"

      case func_alias do
        nil ->
          func_str

        fn_alias ->
          func_str <> " AS #{fn_alias}"
      end
    end

    def encode(%Function{alias: func_alias, name: name, args: args}, opts) do
      name_str =
        if name in [:st_dev, :start_node, :end_node] do
          Inflex.camelize(name, :lower)
        else
          name
          |> Atom.to_string()
          |> String.upcase()
        end

      args_str =
        args
        |> Enum.map(&Seraph.Query.Cypher.encode(&1, opts))
        |> Enum.join(", ")

      func_str = "#{name_str}(#{args_str})"

      case func_alias do
        nil ->
          func_str

        fn_alias ->
          func_str <> " AS #{fn_alias}"
      end
    end
  end
end
