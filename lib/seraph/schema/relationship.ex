defmodule Seraph.Schema.Relationship do
  @moduledoc """
  Defines a relationship schema.

  a Relationship Schema is used to map a Neo4j relationship into an Elixir struct.

  `relationship/3` is used to map a Neo4j node into an Elixir struct and vice versa.
  It allows you to have your application data decoipled from your persisted data and
  to manipulate them easily.

  ## Example

      # Complete form
      defmodule MyApp.Wrote do
        use Seraph.Schema.Relationship

        @cardinality :one

        relationship "WROTE" do
          start_node MyApp.User
          end_node MyApp.Post

          property :views, :integer, default: 0
        end
      end

      # Short form (useful for relationship without properties)
      defrelationship("FOLLOWS", MyApp.User, MyApp.User, cardinality: :one)

  The `start_node` macro defines the node schema from which starts the relationship.
  The `end_node` macro defines the node schema to which ends the relationship.
  The `property` macro defines a property in the node schema.

  Schemas are regular structs and can be created and manipulated directly
  using Elixir's struct API:

      iex> user = %MyApp.Wrote{views: 1}
      iex> %{user | views: 2}

  However, most commonly, structs are cast, validated and manipulated with the
  `Seraph.Changeset` module.

  ## Types
  The available types are:

  Ecto type               | Elixir type             | Literal syntax in query
  :---------------------- | :---------------------- | :---------------------
  `:id`                   | `integer`               | 1, 2, 3
  `:binary_id`            | `binary`                | `<<int, int, int, ...>>`
  `:integer`              | `integer`               | 1, 2, 3
  `:float`                | `float`                 | 1.0, 2.0, 3.0
  `:boolean`              | `boolean`               | true, false
  `:string`               | UTF-8 encoded `string`  | "hello"
  `:binary`               | `binary`                | `<<int, int, int, ...>>`
  `{:array, inner_type}`  | `list`                  | `[value, value, value, ...]`
  `:map`                  | `map` |
  `{:map, inner_type}`    | `map` |
  `:decimal`              | [`Decimal`](https://github.com/ericmj/decimal) |
  `:date`                 | `Date` |
  `:time`                 | `Time` |
  `:time_usec`            | `Time` |
  `:naive_datetime`       | `NaiveDateTime` |
  `:naive_datetime_usec`  | `NaiveDateTime` |
  `:utc_datetime`         | `DateTime` |
  `:utc_datetime_usec`    | `DateTime` |

  ## Reflection

  Any node schema module will generate the `__schema__` function that can be
  used for runtime introspection of the schema:
    * `__schema__(:type)` - Returns the type defined `relationship/3`
    * `__schema__(:start_node)` - Returns the start_node schema
    * `__schema__(:end_node)` - Returns the end_node schema
    * `__schema__(:cardinality)` - Returns the cardinality
    * `__schema__(:properties)` - Returns the list of properties names
  """

  defmodule Metadata do
    @moduledoc """
    Stores metada about node schema.

    # Type
    The type of the given relationship.

    # Schema
     Refers the module name for the schema this metadata belongs to.
    """
    defstruct [:type, :schema]

    @type t :: %__MODULE__{
            type: String.t(),
            schema: module
          }
  end

  defmodule Info do
    @moduledoc false
    defmacro __using__(_) do
      quote do
        defstruct [:direction, :start_node, :end_node, :field, :type, :cardinality, :schema]

        @type t :: %__MODULE__{
                direction: :outgoing | :incoming,
                start_node: Seraph.Repo.queryable(),
                end_node: Seraph.Repo.queryable(),
                field: atom,
                type: String.t(),
                cardinality: :one | :many,
                schema: Seraph.Repo.queryable()
              }
      end
    end
  end

  defmodule Outgoing do
    @moduledoc """
    Stores data about an outgoing relationship.

    Fields are:
      * `start_node` - The start node schema
      * `end_node` - The end node schema
      * `field` - The node schema field where relationship data will be storerd
      * `cardinality` - The relationship cardinality
      * `schema` - The relationship module
    """
    use Info
  end

  defmodule Incoming do
    @moduledoc """
    Stores data about an outgoing relationship.

    Fields are:
      * `start_node` - The start node schema
      * `end_node` - The end node schema
      * `field` - The node schema field where relationship data will be storerd
      * `cardinality` - The relationship cardinality
      * `schema` - The relationship module
    """
    use Info
  end

  defmodule NotLoaded do
    @moduledoc """
    Struct returned by relationships when they are not loaded.

    Fields are:
      * `__type__`: The relationship type
    """
    defstruct [:__type__]

    @type t :: %__MODULE__{
            __type__: String.t()
          }
    defimpl Inspect do
      def inspect(not_loaded, _opts) do
        msg = "relationships :#{not_loaded.__type__} are not loaded"
        ~s(#Seraph.Schema.Relationship.NotLoaded<#{msg}>)
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

  @type cardinality :: [outgoing: :one | :many, incoming: :one | :many]

  @type t :: %{
          __struct__: atom,
          __meta__: Metadata.t(),
          __id__: integer,
          type: String.t(),
          direction: :outgoing | :incoming,
          start_node: Seraph.Schema.Node.t(),
          end_node: Seraph.Schema.Node.t(),
          properties: Ecto.Schema.t(),
          cardinality: cardinality()
        }

  @doc false
  defmacro __using__(_) do
    quote do
      import Seraph.Schema.Relationship

      @cardinality [outgoing: :many, incoming: :many]

      Module.register_attribute(__MODULE__, :properties, accumulate: true)
      Module.register_attribute(__MODULE__, :changeset_properties, accumulate: true)
      Module.register_attribute(__MODULE__, :persisted_properties, accumulate: true)
    end
  end

  @doc """
  Defines a relationship with a type and properties.
  An additional field called `__meta__` is added to the struct.

  Options:
    - `cardinality` - Defines the cardinality of the relationship. Can take two values: `:one` or `:many`

  Note:
    - type must be uppercased.
    - relationship info must match the info given in the start and end node schemas

  """
  defmacro relationship(rel_type, do: block) do
    prelude =
      quote do
        default_cardinality = [outgoing: :many, incoming: :many]

        cardinality =
          Keyword.merge(default_cardinality, Module.get_attribute(__MODULE__, :cardinality))

        Module.put_attribute(__MODULE__, :cardinality, cardinality)
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

        Module.put_attribute(__MODULE__, :struct_fields, {:__id__, nil})
        Module.put_attribute(__MODULE__, :struct_fields, {:__meta__, metadata})
        Module.put_attribute(__MODULE__, :struct_fields, {:type, rel_type})

        try do
          import Seraph.Schema.Relationship
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

        def __changeset__ do
          %{unquote_splicing(Macro.escape(cs_prop_list))}
        end

        def __schema__(:schema), do: __MODULE__
        def __schema__(:entity_type), do: :relationship
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

  @doc """
  Defines a property on the relationship schema with the given name and type.

  Options:
    * `:default` - Sets the default value on the node schema and the struct.
      The default value is calculated at compilation time, so don't use
      expressions like `DateTime.utc_now` or `Ecto.UUID.generate` as
      they would then be the same for all records.

    * `:virtual` - When true, the field is not persisted to the database.
  """
  defmacro property(name, type, opts \\ []) do
    quote do
      opts = unquote(opts)
      name = unquote(name)
      type = unquote(type)

      Seraph.Schema.Helper.check_property_type!(name, type)

      Module.put_attribute(__MODULE__, :properties, {name, type})
      Module.put_attribute(__MODULE__, :changeset_properties, {name, type})
      Module.put_attribute(__MODULE__, :struct_fields, {name, Keyword.get(opts, :default)})

      unless Keyword.get(opts, :virtual, false) do
        Module.put_attribute(__MODULE__, :persisted_properties, name)
      end
    end
  end

  @doc """
  Defines the start node with its module.
  """
  defmacro start_node(node) do
    node = Seraph.Schema.Helper.expand_alias(node, __CALLER__)

    quote do
      Module.put_attribute(__MODULE__, :start_node, unquote(node))

      # Module.put_attribute(__MODULE__, :changeset_properties, {:start_node, unquote(node)})
      Module.put_attribute(__MODULE__, :changeset_properties, {:start_node, :map})

      Module.put_attribute(
        __MODULE__,
        :struct_fields,
        {:end_node,
         %Seraph.Schema.Node.NotLoaded{
           #  __primary_label__: unquote(node).__schema__(:primary_label)
         }}
      )
    end
  end

  @doc """
  Defines the end node with its module.
  """
  defmacro end_node(node) do
    node = Seraph.Schema.Helper.expand_alias(node, __CALLER__)

    quote do
      Module.put_attribute(__MODULE__, :end_node, unquote(node))
      # Module.put_attribute(__MODULE__, :changeset_properties, {:end_node, unquote(node)})
      Module.put_attribute(__MODULE__, :changeset_properties, {:end_node, :map})

      Module.put_attribute(
        __MODULE__,
        :struct_fields,
        {:start_node,
         %Seraph.Schema.Node.NotLoaded{
           #  __primary_label__: unquote(node).__schema__(:primary_label)
         }}
      )
    end
  end

  @doc """
    Allow to define a relationship schema without properties in a quick way.

    Will expand in a viable relationship schema without properties.
    Module name will be built upon start_node, end_node and relationship type as follows:
    `[caller_module_name].[start_node]To[end_node].[relationship_type]`.

    A free `changeset` will be provided with `:end_node` and `:start_node` as
    allowed changes, allowing to easily set them and to have a similar behaviour
    as fully-defined relationship

  Options:
    * `:cardinality` - Defines the cardinality of the relationship. Can take two values: `:one` or `:many`. Default: `:many`

  ## Example

        defmodule MyApp.NoPropsRelationships do
          import Seraph.Schema.Relationship

          defrelationship("ACTED_IN", MyApp.Person, MyApp.Movie, cardinality: :one)
          defrelationship("DIRECTED", MyApp.Person, MyApp.Movie)
        end

        # Will expand to

        defmodule MyApp.NoPropsRelationships do
          defmodule PersonToMovie.ActedIn do
            use Seraph.Schema.Relationship

            @cardinality :one

            relationship "ACTED_IN" do
              start_node MyApp.Person
              end_node MyApp.Movie
            end

            def changeset(relationship, params \\ %{}) do
              Seraph.Changeset.cast(relationship, params, [:start_node, :end_node])
            end
          end

          defmodule PersonToMovie.Directed do
            use Seraph.Schema.Relationship

            @cardinality :many

            relationship "DIRECTED" do
              start_node MyApp.Person
              end_node MyApp.Movie
            end

            def changeset(relationship, params \\ %{}) do
              Seraph.Changeset.cast(relationship, params, [:start_node, :end_node])
            end
          end
        end
  """
  defmacro defrelationship(rel_type, start_node, end_node, opts \\ []) do
    caller = __CALLER__.module

    quote do
      rel_type = unquote(rel_type)
      start_node = unquote(start_node)
      end_node = unquote(end_node)
      opts = unquote(opts)
      cardinality = Keyword.get(opts, :cardinality, [])

      nodes_module_name =
        [start_node, end_node]
        |> Enum.map(fn mod_name ->
          mod_name
          |> Module.split()
          |> List.last()
        end)
        |> Enum.join("To")

      rel_module_name =
        rel_type
        |> String.split("_")
        |> Enum.map(&String.capitalize/1)
        |> Enum.join()

      module_name = Module.concat([unquote(caller), nodes_module_name, rel_module_name])

      defmodule module_name do
        use Seraph.Schema.Relationship

        @cardinality cardinality

        relationship rel_type do
          start_node start_node
          end_node end_node
        end

        def changeset(relationship, params \\ %{}) do
          Seraph.Changeset.cast(relationship, params, [:start_node, :end_node])
        end
      end
    end
  end
end
