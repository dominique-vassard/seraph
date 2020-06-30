defmodule Seraph.Schema.Node do
  @moduledoc ~S"""
  Defines a Node schema.

  a Node Schema is used to map a Neo4j node into an Elixir struct.

  `node/2` is used to map a Neo4j node into an Elixir struct and vice versa.
  It allows you to have your application data decoipled from your persisted data and
  to manipulate them easily.

  ## Example
      defmodule User do
        use Seraph.Schema.Node

        node "User" do
          property :name, :string
          property :age, :integer, default: 0

          incoming_relationship "FOLLOWED", MyApp.Blog.User, :followers, through: MyApp.Blog.Relationships.Followed

          outgoing_relationship "WROTE", MyApp.Blog.Post, :posts, through: MyApp.Blog.Relationships.Wrote
        end
      end

  By default, a node schema will generate a identifier which is named `uuid` and of type `Ecto.UUID`.
  This is to avoid to rely on Neo4j's internal ids for identifier purpose.
  The `property` macro defines a property in the node schema.
  The `incoming_relationship` macro defines relationship going from another node schema to the current one.
  The `outgoing_relationship` macro defines relationship going from the current node schema to another one.
  Schemas are regular structs and can be created and manipulated directly
  using Elixir's struct API:

      iex> user = %User{name: "jane"}
      iex> %{user | age: 30}

  However, most commonly, structs are cast, validated and manipulated with the
  `Seraph.Changeset` module.

  ## Schema attributes
  Supported attributes for configuring the defined node schema. They must
  be set after the `use Seraph.Schema.Node` call and before the `node/2`
  definition.

  These attributes are:
    * `@identifier` configures the node schema identifier. It will be used at node's creation only.
    It expects a tuple {name, type, options}. No options are available for the moment.
    * `@merge_keys` configure the node schema merge keys. These keys will be used when updating the node data.
    It expects a list of atoms. Note that the merge keys must be properties of the node schema.
    If they are not defined, the `identifier` will be used as merge key.

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
    * `__schema__(:primary_label)` - Returns the primary label as defined in `node/2`
    * `__schema__(:identifier)` - Returns the identifier data
    * `__schema__(:merge_keys)` - Returns the list of merge keys
    * `__schema__(:properties)` - Returns the list of properties names
    * `__schema__(:relationships)` - Returns the list of all relationships data
    * `__schema__(:relationship, relationship_type)` - Returns data about the specified relationship type
    * `__schema__(:incoming_relationships)` - Returns a list of all incoming relationship names
    * `__schema__(:outgoing_relationships)` - Returns a list of all outgoing relationship names
  """

  defmodule Metadata do
    @moduledoc """
    Stores metada about node schema.

    # Primary label
    The primary label of the given node schema.

    # Schema
     Refers the module name for the schema this metadata belongs to.
    """
    defstruct [:primary_label, :schema]

    @type t :: %__MODULE__{
            primary_label: String.t(),
            schema: module
          }
  end

  defmodule NotLoaded do
    @moduledoc """
    Struct returned by related nodes when they are not loaded.

    Fields are:
      * `__primary_label__`: The primary label of the related node
      * `__type__`: The relationship type considered
    """
    defstruct [:__label__, :__type__]

    @type t :: %__MODULE__{
            __label__: String.t(),
            __type__: String.t()
          }

    defimpl Inspect do
      @spec inspect(Seraph.Schema.Node.NotLoaded.t(), Inspect.Opts.t()) :: String.t()
      def inspect(not_loaded, _opts) do
        msg =
          "nodes (#{not_loaded.__label__}) through relationship :#{not_loaded.__type__} are not loaded"

        ~s(#Seraph.Schema.Node.NotLoaded<#{msg}>)
      end
    end
  end

  alias Seraph.Schema.Relationship
  defstruct [:__meta__, :__id__, :labels, :properties, :outgoing, :incoming]

  @type t :: %{
          optional(atom) => any,
          __struct__: atom,
          __meta__: Metadata.t(),
          __id__: integer,
          properties: map
        }

  @doc false
  defmacro __using__(_) do
    quote do
      import Seraph.Schema.Node
      @identifier {:uuid, :string, []}
      @merge_keys nil

      Module.register_attribute(__MODULE__, :struct_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :properties, accumulate: true)
      Module.register_attribute(__MODULE__, :changeset_properties, accumulate: true)
      Module.register_attribute(__MODULE__, :persisted_properties, accumulate: true)
      Module.register_attribute(__MODULE__, :relationships_list, accumulate: true)
      Module.register_attribute(__MODULE__, :relationships, accumulate: false)
      Module.register_attribute(__MODULE__, :outgoing_relationships, accumulate: true)
      Module.register_attribute(__MODULE__, :incoming_relationships, accumulate: true)
    end
  end

  @doc """
  Defines a node schema with a primary label, properties and relationships definitions.
  An additional field called `__meta__` is added to the struct.

  Note that primary label must be PascalCased.
  """
  defmacro node(primary_label, do: block) do
    prelude =
      quote do
        @after_compile Seraph.Schema.Node

        unless @identifier == false do
          {name, type, opts} = @identifier
          Seraph.Schema.Node.__property__(__MODULE__, name, type, opts ++ [identifier: true])
          Module.put_attribute(__MODULE__, :changeset_properties, {name, type})
        end

        primary_label = unquote(primary_label)

        if not Regex.match?(~r/^([A-Z]{1}[a-z]*)+$/, primary_label) or
             String.upcase(primary_label) == primary_label do
          raise ArgumentError,
                "[#{Atom.to_string(__MODULE__)}] node label must be CamelCased. Received: #{
                  primary_label
                }."
        end

        metadata = %Metadata{
          primary_label: primary_label,
          schema: __MODULE__
        }

        Module.put_attribute(__MODULE__, :struct_fields, {:__id__, nil})
        Module.put_attribute(__MODULE__, :struct_fields, {:__meta__, metadata})
        Module.put_attribute(__MODULE__, :struct_fields, {:additionalLabels, []})

        Module.put_attribute(
          __MODULE__,
          :changeset_properties,
          {:additionalLabels, {:array, :string}}
        )

        try do
          import Seraph.Schema.Node
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

        manage_merge_keys(__MODULE__, @merge_keys, @identifier, @properties)

        defstruct @struct_fields

        def __changeset__ do
          %{unquote_splicing(Macro.escape(cs_prop_list))}
        end

        # Review relationships
        # If more than one relationship has the same type, add a list to attribute
        new_relationships =
          Enum.reduce(@relationships_list, [], fn {rel_type, rel_info} = r, new_rels ->
            case Keyword.get(new_rels, rel_type) do
              nil ->
                Keyword.put(new_rels, rel_type, rel_info)

              old_data when is_list(old_data) ->
                Keyword.put(new_rels, rel_type, [rel_info | old_data])

              old_data ->
                Keyword.put(new_rels, rel_type, [rel_info, old_data])
            end
          end)

        Module.put_attribute(__MODULE__, :relationships, new_relationships)
        Module.delete_attribute(__MODULE__, :relationships_list)

        def __schema__(:schema), do: __MODULE__
        def __schema__(:entity_type), do: :node
        def __schema__(:primary_label), do: unquote(primary_label)
        def __schema__(:properties), do: unquote(prop_list)
        def __schema__(:changeset_properties), do: unquote(cs_prop_list)
        def __schema__(:persisted_properties), do: unquote(persisted_prop_list)
        def __schema__(:relationships), do: @relationships
        def __schema__(:outgoing_relationships), do: @outgoing_relationships
        def __schema__(:incoming_relationships), do: @incoming_relationships
        def __schema__(:identifier), do: @identifier
        def __schema__(:merge_keys), do: @merge_keys
        def __schema__(:struct_fields), do: @struct_fields

        def __schema__(:relationship, searched_type) when is_atom(searched_type) do
          Enum.reduce(@relationships, [], fn {rel_type, info}, acc ->
            if rel_type == searched_type do
              [info | acc]
            else
              acc
            end
          end)
          |> case do
            [] -> nil
            [unique_res] -> unique_res
            results -> results |> Enum.reverse()
          end
        end

        def __schema__(:relationship, searched_type) when is_binary(searched_type) do
          searched_type = searched_type |> String.downcase() |> String.to_atom()
          __schema__(:relationship, searched_type)
        end

        def __schema__(:type, :additionalLabels) do
          {:array, :string}
        end

        def __schema__(:type, prop) do
          Keyword.fetch!(unquote(properties), prop)
        end
      end

    quote do
      unquote(prelude)
      unquote(postlude)
    end
  end

  def __after_compile__(%{module: module} = _env, _) do
    Module.get_attribute(module, :relationships)
    |> Enum.each(&check_relationship_schema(module, &1))
  end

  defp check_relationship_schema(module, {_, schemas}) when is_list(schemas) do
    Enum.each(schemas, &do_check_relationship_schema(module, &1))
  end

  defp check_relationship_schema(module, {_, info}) do
    do_check_relationship_schema(module, info)
  end

  defp do_check_relationship_schema(module, data) do
    unless data.schema.__schema__(:type) == data.type do
      raise ArgumentError,
            "[#{inspect(module)}] Defined type #{data.type} doesn't match the one defined in #{
              inspect(data.schema.__schema__(:type))
            }"
    end

    if not is_nil(data.cardinality) and
         data.cardinality != data.schema.__schema__(:cardinality)[data.direction] do
      raise ArgumentError,
            "[#{inspect(module)}] Defined cardinality #{data.cardinality} doesn't match the one defined in #{
              inspect(data.schema.__schema__(:type))
            }"
    end
  end

  @doc """
  Defines a property on the node schema with the given name and type.

  Options:
    * `:default` - Sets the default value on the node schema and the struct.
      The default value is calculated at compilation time, so don't use
      expressions like `DateTime.utc_now` or `Ecto.UUID.generate` as
      they would then be the same for all records.

    * `:virtual` - When true, the field is not persisted to the database.
  """
  defmacro property(name, type, opts \\ []) do
    quote do
      Seraph.Schema.Node.__property__(__MODULE__, unquote(name), unquote(type), unquote(opts))
    end
  end

  @doc """
  Defines an outgoing relationship on the node schema with the given data:
  * `type` - the relationship type (must be uppercased)
  * `related_node` - the node schema the relationship is linked to
  * `name` - the name used for storing related nodes (when loaded)
  * `relationship_module` - Defines the Relationship module

  Loaded relationship(s) will be stored in the struct with their type as key.

  Options:
  - `cardinality` - Defines the cardinality of the relationship. Can take two values: `:one` or `:many`
  """
  defmacro outgoing_relationship(type, related_node, name, relationship_module, opts \\ []) do
    related_node = Seraph.Schema.Helper.expand_alias(related_node, __CALLER__)

    quote do
      add_relationship(
        __MODULE__,
        :outgoing,
        unquote(type),
        unquote(related_node),
        unquote(name),
        unquote(relationship_module),
        unquote(opts)
      )
    end
  end

  @doc """
  Defines an incoming relationship on the node schema with the given data:
  * `type` - the relationship type (must be uppercased)
  * `related_node` - the node schema the relationship is linked from
  * `name` - the name used for storing related nodes (when loaded)
  * `relationship_module` - Defines the Relationship module

  Loaded relationship(s) will be stored in the struct with their type as key.

  Options:
    - `cardinality` - Defines the cardinality of the relationship. Can take two values: `:one` or `:many`
  """
  defmacro incoming_relationship(type, related_node, name, relationship_module, opts \\ []) do
    related_node = Seraph.Schema.Helper.expand_alias(related_node, __CALLER__)

    quote do
      add_relationship(
        __MODULE__,
        :incoming,
        unquote(type),
        unquote(related_node),
        unquote(name),
        unquote(relationship_module),
        unquote(opts)
      )
    end
  end

  @doc false
  @spec manage_merge_keys(module, nil | [:atom], false | {atom, atom, list}, Keyword.t()) :: :ok
  def manage_merge_keys(module, merge_keys, identifier, properties) do
    if is_nil(merge_keys) and identifier == false do
      raise ArgumentError,
            "[#{inspect(module)}] At least one these attributes [@identifier, @merge_keys] must have a value."
    end

    merge_keys =
      if is_nil(merge_keys) do
        {identifier_prop, _, _} = identifier
        [identifier_prop]
      else
        merge_keys
      end

    unless Enum.all?(merge_keys, &List.keyfind(properties, &1, 0, false)) do
      raise ArgumentError, "[#{inspect(module)}] :merge_keys must be exisitng properties."
    end

    Module.put_attribute(module, :merge_keys, merge_keys)
  end

  @spec __property__(module, atom, atom, Keyword.t()) :: nil | :ok
  def __property__(module, name, type, opts) do
    Seraph.Schema.Helper.check_property_type!(name, type)

    name_str = Atom.to_string(name)

    if not Regex.match?(~r/^(?:[a-z]{1}[a-z0-9]{1,}[A-Z]{1}[a-z0-9]*)+$|^([a-z]*)$/, name_str) do
      raise ArgumentError,
            "[#{Atom.to_string(module)}] property must be camelCased. Received: #{name_str}."
    end

    if List.keyfind(Module.get_attribute(module, :properties), name, 0) do
      raise ArgumentError, "[#{inspect(module)}] Field #{inspect(name)} already exists."
    end

    unless name == :uuid and type == :string and Keyword.get(opts, :identifier, true) do
      Module.put_attribute(module, :changeset_properties, {name, type})
    end

    Module.put_attribute(module, :properties, {name, type})
    Module.put_attribute(module, :struct_fields, {name, Keyword.get(opts, :default)})

    unless Keyword.get(opts, :virtual, false) do
      Module.put_attribute(module, :persisted_properties, name)
    end
  end

  @doc false
  @spec add_relationship(
          module,
          :incoming | :outgoing,
          String.t(),
          module,
          atom,
          module,
          Keyword.t()
        ) ::
          :ok
  def add_relationship(module, direction, type, related_node, name, relationship_module, opts) do
    if not Regex.match?(~r/^[A-Z_]*$/, type) do
      raise ArgumentError,
            "[#{inspect(module)}] Relationship type must conform the format [A-Z_]* [Received: #{
              type
            }]"
    end

    type_field = type |> String.downcase() |> String.to_atom()

    rel_not_loaded = %Relationship.NotLoaded{
      __type__: type
    }

    info =
      relationship_info(direction, module, related_node, name, type, relationship_module, opts)

    exists? =
      Enum.any?(Module.get_attribute(module, :relationships_list), fn {_, rel_info} ->
        rel_info.type == info.type && rel_info.start_node == info.start_node &&
          rel_info.end_node == info.end_node && rel_info.direction == info.direction
      end)

    if exists? do
      raise ArgumentError,
            "Relationship from [#{inspect(info.start_node)}] to [#{inspect(info.end_node)}] with type [#{
              inspect(info.type)
            }] already exists."
    end

    Module.put_attribute(module, :relationships_list, {type_field, info})
    struct_fields = Module.get_attribute(module, :struct_fields)

    if List.keyfind(Module.get_attribute(module, :properties), type_field, 0) do
      raise ArgumentError,
            "[#{inspect(module)}] relationship type name #{inspect(type_field)} is already taken by a property."
    end

    if List.keyfind(struct_fields, name, 0) do
      raise ArgumentError,
            "[#{inspect(module)}] relationship field name #{inspect(name)} is already taken."
    end

    unless List.keyfind(struct_fields, name, 0) do
      Module.put_attribute(module, :struct_fields, {type_field, rel_not_loaded})
    end

    attr_name = String.to_atom(Atom.to_string(direction) <> "_relationships")

    if not (type_field in Module.get_attribute(module, attr_name)) do
      Module.put_attribute(module, attr_name, type_field)
    end

    node_name =
      related_node
      |> Module.split()
      |> List.last()

    Module.put_attribute(
      module,
      :struct_fields,
      {name, %NotLoaded{__label__: node_name, __type__: type}}
    )
  end

  defp relationship_info(direction, module, related_node, field, type, relationship_module, opts) do
    {struct_type, start_node, end_node} =
      if direction == :outgoing do
        {Relationship.Outgoing, module, related_node}
      else
        {Relationship.Incoming, related_node, module}
      end

    cardinality = Keyword.get(opts, :cardinality, :many)

    data = %{
      direction: direction,
      start_node: start_node,
      end_node: end_node,
      field: field,
      type: type,
      cardinality: cardinality,
      schema: relationship_module
    }

    struct!(struct_type, data)
  end
end
