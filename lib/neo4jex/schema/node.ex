defmodule Neo4jex.Schema.Node do
  alias Neo4jex.Schema.Helper

  defmodule Metadata do
    defstruct [:primary_label, :schema]

    @type t :: %__MODULE__{
            primary_label: String.t(),
            schema: module
          }
  end

  defmodule NotLoaded do
    defstruct [:__primary_label__, :__type__]

    @type t :: %__MODULE__{
            __primary_label__: String.t(),
            __type__: String.t()
          }
    defimpl Inspect do
      def inspect(not_loaded, _opts) do
        msg =
          "nodes #{not_loaded.__primary_label__} through relation #{not_loaded.__type__} are not loaded"

        ~s(#Neo4jex.Schema.Node.NotLoaded<#{msg}>)
      end
    end
  end

  alias Neo4jex.Schema.Relationship
  defstruct [:__meta__, :__id__, :labels, :properties, :outgoing, :incoming]

  @type t :: %{
          optional(atom) => any,
          __struct__: atom,
          __meta__: Metadata.t(),
          __id__: integer,
          properties: map
        }

  defmacro __using__(_) do
    quote do
      import Neo4jex.Schema.Node
      @identifier {:uuid, :string, []}
      @merge_keys nil

      Module.register_attribute(__MODULE__, :struct_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :properties, accumulate: true)
      Module.register_attribute(__MODULE__, :changeset_properties, accumulate: true)
      Module.register_attribute(__MODULE__, :persisted_properties, accumulate: true)
      Module.register_attribute(__MODULE__, :relationships, accumulate: true)
      Module.register_attribute(__MODULE__, :outgoing_relationships, accumulate: true)
      Module.register_attribute(__MODULE__, :incoming_relationships, accumulate: true)
    end
  end

  defmacro node(primary_label, do: block) do
    prelude =
      quote do
        @after_compile Neo4jex.Schema.Node

        unless @identifier == false do
          {name, type, opts} = @identifier
          Neo4jex.Schema.Node.__property__(__MODULE__, name, type, opts ++ [identifier: true])
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
          import Neo4jex.Schema.Node
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

        def __schema__(:schema), do: __MODULE__
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
    |> Enum.filter(fn {_, %{schema: schema}} -> not is_nil(schema) end)
    |> Enum.each(fn {_, info} = data ->
      unless info.schema.__schema__(:type) == info.type do
        raise ArgumentError,
              "[#{inspect(module)}] Defined type #{info.type} doesn't match the one defined in #{
                inspect(info.schema.__schema__(:type))
              }"
      end

      data
    end)
  end

  defmacro property(name, type, opts \\ []) do
    quote do
      Neo4jex.Schema.Node.__property__(__MODULE__, unquote(name), unquote(type), unquote(opts))
    end
  end

  defmacro outgoing_relationship(type, related_node, name, opts \\ []) do
    related_node = Neo4jex.Schema.Helper.expand_alias(related_node, __CALLER__)

    quote do
      add_relationship(
        __MODULE__,
        :outgoing,
        unquote(type),
        unquote(related_node),
        unquote(name),
        unquote(opts)
      )
    end
  end

  defmacro incoming_relationship(type, related_node, name, opts \\ []) do
    related_node = Neo4jex.Schema.Helper.expand_alias(related_node, __CALLER__)

    quote do
      add_relationship(
        __MODULE__,
        :incoming,
        unquote(type),
        unquote(related_node),
        unquote(name),
        unquote(opts)
      )
    end
  end

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
    Neo4jex.Schema.Node.check_property_type!(name, type)

    name_str = Atom.to_string(name)

    if not Regex.match?(~r/^(?:[a-z]{1,}[A-Z]{1}[a-z]*)+$|^([a-z]*)$/, name_str) do
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

  @spec add_relationship(module, :incoming | :outgoing, String.t(), module, atom, Keyword.t()) ::
          :ok
  def add_relationship(module, direction, type, related_node, name, opts) do
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

    info = relationship_info(direction, module, related_node, name, type, opts)

    Module.put_attribute(module, :relationships, {type_field, info})
    struct_fields = Module.get_attribute(module, :struct_fields)

    if List.keyfind(Module.get_attribute(module, :properties), type_field, 0) do
      raise ArgumentError,
            "[#{inspect(module)}] relationship type name #{inspect(type_field)} is already taken by a property."
    end

    if List.keyfind(struct_fields, name, 0) do
      raise ArgumentError,
            "[#{inspect(module)}] relationship field name #{inspect(type_field)} is already taken."
    end

    attr_name = String.to_atom(Atom.to_string(direction) <> "_relationships")

    if not (type_field in Module.get_attribute(module, attr_name)) do
      Module.put_attribute(module, attr_name, type_field)
    end

    Module.put_attribute(module, :struct_fields, {type_field, rel_not_loaded})

    Module.put_attribute(
      module,
      :struct_fields,
      {name, %NotLoaded{__primary_label__: "t", __type__: type}}
    )
  end

  defp relationship_info(direction, module, related_node, field, type, opts) do
    {struct_type, start_node, end_node} =
      if direction == :outgoing do
        {Relationship.Outgoing, module, related_node}
      else
        {Relationship.Incoming, related_node, module}
      end

    rel_schema = Keyword.get(opts, :through, nil)

    cardinality =
      unless rel_schema do
        Keyword.get(opts, :cardinality, :many)
      end

    data = %{
      start_node: start_node,
      end_node: end_node,
      field: field,
      type: type,
      cardinality: cardinality,
      schema: rel_schema
    }

    struct!(struct_type, data)
  end

  @spec check_property_type!(atom, atom) :: nil
  def check_property_type!(name, type) do
    unless type in Helper.valid_types() do
      raise raise ArgumentError,
                  "invalid or unknown type #{inspect(type)} for field #{inspect(name)}"
    end
  end
end
