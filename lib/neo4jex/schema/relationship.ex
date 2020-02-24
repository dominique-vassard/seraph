defmodule Neo4jex.Schema.Relationship do
  defmodule Metadata do
    defstruct [:type, :schema]

    @type t :: %__MODULE__{
            type: String.t(),
            schema: module
          }
  end

  defmodule Info do
    defmacro __using__(_) do
      quote do
        defstruct [:start_node, :end_node, :field, :type, :cardinality, :schema]
      end
    end
  end

  defmodule Outgoing do
    use Info
  end

  defmodule Incoming do
    use Info
  end

  defmodule NotLoaded do
    defstruct [:__start_node__, :__end_node__, :__type__]

    @type t :: %__MODULE__{
            __start_node__: module,
            __end_node__: module,
            __type__: String.t()
          }
    defimpl Inspect do
      def inspect(not_loaded, _opts) do
        msg = "relation :#{not_loaded.__type__} is not loaded"
        ~s(#Neo4jex.Schema.Relationship.NotLoaded<#{msg}>)
      end
    end
  end

  defstruct [
    :__meta__,
    :__id__,
    :type,
    :direction,
    :start_node,
    :end_node,
    :properties,
    :cardinality
  ]

  @type t :: %{
          __struct__: atom,
          __meta__: Metadata.t(),
          __id__: integer,
          type: String.t(),
          direction: :outgoing | :incoming,
          start_node: Neo4jex.Schema.Node.t(),
          end_node: Neo4jex.Schema.Node.t(),
          properties: Ecto.Schema.t(),
          cardinality: :one | :many
        }
  defmacro __using__(_) do
    quote do
      import Neo4jex.Schema.Relationship

      Module.register_attribute(__MODULE__, :properties, accumulate: true)
      Module.register_attribute(__MODULE__, :changeset_properties, accumulate: true)
      Module.register_attribute(__MODULE__, :persisted_properties, accumulate: true)
    end
  end

  defmacro relationship(rel_type, opts \\ [], do: block) do
    prelude =
      quote do
        opts = unquote(opts)
        Module.put_attribute(__MODULE__, :cardinality, Keyword.get(opts, :cardinality, :many))
        Module.register_attribute(__MODULE__, :struct_fields, accumulate: true)
        Module.register_attribute(__MODULE__, :properties, accumulate: true)

        rel_type = unquote(rel_type)

        if not Regex.match?(~r/^[A-Z_]*$/, rel_type) do
          raise ArgumentError,
                "[#{Atom.to_string(__MODULE__)}] Relationship type must conform the format [A-Z_]* [Received: #{
                  rel_type
                }]"
        end

        metadata = %Metadata{
          type: rel_type,
          schema: __MODULE__
        }

        Module.put_attribute(__MODULE__, :struct_fields, {:__meta__, metadata})

        try do
          import Neo4jex.Schema.Relationship
          unquote(block)
        after
          :ok
        end
      end

    postlude =
      quote unquote: false do
        properties = Module.get_attribute(__MODULE__, :properties) |> Enum.reverse()
        Module.put_attribute(__MODULE__, :properties, properties)

        prop_list = Enum.map(properties, &elem(&1, 0))
        cs_prop_list = @changeset_properties |> Enum.reverse()
        persisted_prop_list = @persisted_properties |> Enum.reverse()

        defstruct @struct_fields

        def __schema__(:schema), do: __MODULE__
        def __schema__(:type), do: unquote(rel_type)
        def __schema__(:start_node), do: @start_node
        def __schema__(:end_node), do: @end_node
        def __schema__(:cardinality), do: @cardinality
        def __schema__(:properties), do: unquote(prop_list)
        def __schema__(:changeset_properties), do: unquote(cs_prop_list)
        def __schema__(:persisted_properties), do: unquote(persisted_prop_list)

        def __schema__(:type, prop) do
          Keyword.fetch!(unquote(properties), prop)
        end
      end

    quote do
      unquote(prelude)
      unquote(postlude)
    end
  end

  defmacro property(name, type, opts \\ []) do
    quote do
      opts = unquote(opts)
      name = unquote(name)
      type = unquote(type)

      Neo4jex.Schema.Node.check_property_type!(name, type)

      Module.put_attribute(__MODULE__, :properties, {name, type})
      Module.put_attribute(__MODULE__, :changeset_properties, {name, type})
      Module.put_attribute(__MODULE__, :struct_fields, {name, Keyword.get(opts, :default)})

      unless Keyword.get(opts, :virtual, false) do
        Module.put_attribute(__MODULE__, :persisted_properties, name)
      end
    end
  end

  defmacro start_node(node) do
    node = Neo4jex.Schema.Helper.expand_alias(node, __CALLER__)

    quote do
      Module.put_attribute(__MODULE__, :start_node, unquote(node))

      Module.put_attribute(
        __MODULE__,
        :struct_fields,
        {:end_node,
         %Neo4jex.Schema.Node.NotLoaded{
           #  __primary_label__: unquote(node).__schema__(:primary_label)
         }}
      )
    end
  end

  defmacro end_node(node) do
    node = Neo4jex.Schema.Helper.expand_alias(node, __CALLER__)

    quote do
      Module.put_attribute(__MODULE__, :end_node, unquote(node))

      Module.put_attribute(
        __MODULE__,
        :struct_fields,
        {:start_node,
         %Neo4jex.Schema.Node.NotLoaded{
           #  __primary_label__: unquote(node).__schema__(:primary_label)
         }}
      )
    end
  end
end
