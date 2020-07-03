defmodule Seraph.Query do
  @moduledoc ~S"""
  Provide the query DSL.

  Queries are used to retrieve and manipulate data from a repository (see `Seraph.Repo`).
  They can be written using keywords or macros.

  Basic example:

      # Keyword syntax
      match [{n}],
      return: [n]

      # Macro syntax
      match([{n}])
      |> return([n])

  ## Node and relationship representation
  Seraph try to be as close to Cypher syntax as possible.

  Nodes are represented by `{variable, schema, properties}` where:
   - variable is a `string`,
   - schema is a `Seraph.Schema.Node`,
   - properties are a `map`

  All variants are valid depending on the context.

  Note that primary label will be deducted from schema and additional labels should be added
  as properties under the key `:additionalLabels`

  Node examples:

      # Fully fleshed node
      {u, MyApp.User, %{firstName: "John", lastName: "Doe"}}

      # Node with no / useless properties
      {u, MyApp.User}

      # Node with only properties
      {u, %{firstName: "John"}}

      # Node with additional labels
      {u, MyApp.User, %{additionalLabels: ["New", "Premium"]}}


  Relationships are represented by `[start_node, [variable, schema, properties], end_node]` where:
  - start_node is a valid node representation
  - variable is a `string`,
  - schema is a `Seraph.Schema.Relationship`,
  - properties are a `map`
  - end_node is a valid node representation

  All variants are valid depending on the context

  Relationship examples:

      # Fully flesh relationship
      [{u, MyApp.User, %{firstName: "John"}}, [rel, MyApp.Wrote, %{nb_edits: 5}], {p, MyApp.Post}]

      # Relatinship without properties
      [{u, MyApp.User}, [rel, MyApp.Wrote], {p, MyApp.Post}]

      # Relatinship without variable
      [{u, MyApp.User}, [MyApp.Wrote], {p, MyApp.Post}]

  ## About literals and interpolation
  The following literals are allowe in queries:
  - Integers
  - Floats
  - Strings
  - Boolean
  - Lists

  For the other types or dynamic values, you can interpolate them using `^`:

      first_name = "John"
      match([{u, MyApp.User}])
      |> where([u.firstName == ^first_name])

  ## Keyword order and entry points
  In Cypher, keyword can be used in any order but only some can start a query. The same applies for Seraph queries.
  The entry point keywords / macros are:
  - `match`
  - `create`
  - `merge`

  Note that because of this versability, it is possible to write invalid queries, a databse error will then be raised.

  ## About operators and functions
  Each Keyword / macro has a specific set ef availabe operators and functions.
  Please see the keyword / macro documentation for the aviable operators and functions.

  ## About `nil`
  In Neo4j, `NULL` doesn't exists. This means that you can't have a null property and that **setting a property to null will remove it**.

  Also, it is preferred to us `is_nil` in where clause instead of using `%{property: nil}`
  """

  defmodule Change do
    @moduledoc false
    alias Seraph.Query.Builder.Entity
    defstruct [:entity, :change_type]

    @type t :: %__MODULE__{
            entity: Entity.all(),
            change_type: :create | :merge
          }
  end

  alias Seraph.Query.Builder
  defstruct identifiers: %{}, params: [], operations: [], literal: []

  @type operation :: :match | :where | :return

  @type t :: %__MODULE__{
          identifiers: %{String.t() => Builder.Entity.t()},
          params: [{atom, any()}],
          operations: [{operation(), any()}],
          literal: [String.t()]
        }

  @doc """
  Create a `MATCH` clause from a list of nodes and / or relationships.

    - Cypher keyword: `MATCH`
    - Entry point: yes
    - Expects: a list of nodes and / or relationships
    - Invalid data:
      - Empty node: {},
      - Empty relationship: [{}, [], {}]

  ## Examples

        # Keyword syntax
        match [
          {u, User},
          {p, Post},
          [{u}, [rel, Wrote], {p}]
        ]

        # Macro syntax
        match([
          {u, User},
          {p, Post},
          [{u}, [rel, Wrote], {p}]
        ])

  """
  defmacro match(expr, operations_kw \\ [])

  defmacro match(expr, []) do
    do_match(expr, [], __CALLER__, true)
  end

  defmacro match(expr, operations_kw) do
    do_match(
      expr,
      operations_kw,
      __CALLER__,
      Keyword.keyword?(operations_kw)
    )
  end

  defp do_match(expr, operations, env, true) do
    operations = [{:match, expr} | operations]

    query =
      %Seraph.Query{}
      |> Macro.escape()

    query =
      Enum.reduce(operations, query, fn {op, expression}, query ->
        func = "build_" <> Atom.to_string(op)
        Kernel.apply(Seraph.Query, String.to_atom(func), [query, expression, env])
      end)

    quote do
      unquote(query)
    end
  end

  defp do_match(query, expr, env, false) do
    build_match(query, expr, env)
  end

  @doc """
  Create a `CREATE` clause from a list of nodes and/or relationships.

    - Cypher keyword: `CREATE`
    - Entry point: yes
    - Expects: a list of nodes and / or relationships
    - Invalid data:
      - Empty node: {},
      - Empty relationship: [{}, [], {}]
      - Node without schema: {u, %{prop1: value}} , {u}


      ## Examples

          # Creating a node (keyword syntax)
          create [{u, MyApp.User, %{uid: 1, firstName: "John"}}],
            return: [u]

          # Creating a node (macro syntax)
          create([{u, MyApp.User, %{uid: 1, firstName: "John"}}])
          |> return([u])

          # Creating a relationship (keyword syntax)
          create [
            [
              {u, MyApp.User, %{uid: 1}},
              [rel, MyApp.Wrote, %{nb_edit: 5}],
              {p, MyApp.Post, %{uid: 2}}
            ]
          ],
            return: [rel]

          # Creating a relationship with a previous MATCH (keyword syntax)
          match [
            {u, MyApp.User, %{uid: 1}},
            {p, MyApp.Post, %{uid: 2}}
          ],
            create: [[{u}, [rel, MyApp.Wrote, %{nb_edit: 5}], {p}]],
            return: [rel]

           # Creating a relationship (macro syntax)
          create([
            [
              {u, MyApp.User, %{uid: 1}},
              [rel, MyApp.Wrote, %{nb_edit: 5}],
              {p, MyApp.Post, %{uid: 2}}
            ]
          ])
          |> return([rel])
  """
  defmacro create(expr, operations_kw \\ [])

  defmacro create(expr, []) do
    do_create(expr, [], __CALLER__, true)
  end

  defmacro create(expr, operations_kw) do
    do_create(
      expr,
      operations_kw,
      __CALLER__,
      Keyword.keyword?(operations_kw)
    )
  end

  defp do_create(expr, operations, env, true) do
    operations = [{:create, expr} | operations]

    query =
      %Seraph.Query{}
      |> Macro.escape()

    query =
      Enum.reduce(operations, query, fn {op, expression}, query ->
        func = "build_" <> Atom.to_string(op)
        Kernel.apply(Seraph.Query, String.to_atom(func), [query, expression, env])
      end)

    quote do
      unquote(query)
    end
  end

  defp do_create(query, expr, env, false) do
    build_create(query, expr, env)
  end

  @doc """
  Create a `MERGE` clause from a node or relationship.

  - Cypher keyword: `MERGE`
    - Entry point: yes
    - Expects: a node or a relationship
    - Invalid data:
      - Empty node: {},
      - Empty relationship: [{}, [], {}]
      - Relationship without schema: [{u}, [rel], {p}]

  ## Examples

      # Merging a node (keyword syntax)
      merge [{u, MyApp.User, %{uid: 1, firstName: "John"}}],
        return: [u]

      # Merging a node (macro syntax)
      merge([{u, MyApp.User, %{uid: 1, firstName: "John"}}])
      |> return([u])

      # Merging a relationship (keyword syntax)
      merge [
        [
          {u, MyApp.User, %{uid: 1}},
          [rel, MyApp.Wrote, %{nb_edit: 5}],
          {p, MyApp.Post, %{uid: 2}}
        ]
      ],
        return: [rel]

      # Merging a relationship with a previous MATCH (keyword syntax)
      match [
        {u, MyApp.User, %{uid: 1}},
        {p, MyApp.Post, %{uid: 2}}
      ],
        merge: [[{u}, [rel, MyApp.Wrote, %{nb_edit: 5}], {p}]],
        return: [rel]

        # Merging a relationship (macro syntax)
      merge([
        [
          {u, MyApp.User, %{uid: 1}},
          [rel, MyApp.Wrote, %{nb_edit: 5}],
          {p, MyApp.Post, %{uid: 2}}
        ]
      ])
      |> return([rel])

  """
  defmacro merge(expr, operations_kw \\ [])

  defmacro merge(expr, []) do
    do_merge(expr, [], __CALLER__, true)
  end

  defmacro merge(expr, operations_kw) do
    do_merge(
      expr,
      operations_kw,
      __CALLER__,
      Keyword.keyword?(operations_kw)
    )
  end

  defp do_merge(expr, operations, env, true) do
    operations = [{:merge, expr} | operations]

    query =
      %Seraph.Query{}
      |> Macro.escape()

    query =
      Enum.reduce(operations, query, fn {op, expression}, query ->
        func = "build_" <> Atom.to_string(op)
        Kernel.apply(Seraph.Query, String.to_atom(func), [query, expression, env])
      end)

    quote do
      unquote(query)
    end
  end

  defp do_merge(query, expr, env, false) do
    build_merge(query, expr, env)
  end

  @doc """
  Create a `WHERE` clause from a boolean expression.

    - Cypher keyword: `WHERE`
    - Entry point: no
    - Expects: a boolean expression

  ## Valid operators
    - `and` (infix)
    - `or` (infix)
    - `xor`

    - `in` (infix)

    - `==` (infix)
    - `<>` (infix)
    - `>` (infix)
    - `>=` (infix)
    - `<` (infix)
    - `<=` (infix)

    - `is_nil`
    - `not`
    - `exists`

    - `starts_with`
    - `ends_with`
    - `contains`
    - `=~`

  ## Examples

      # Keyword syntax
      match [{u, MyApp.User}],
        where: exists(u.lastName) and start_with(u.firstName, "J"),
        return: [u.firstName]

      # Macro syntax
      match([{u, MyApp.User}])
      |> where(exists(u.lastName) and start_with(u.firstName, "J"))
      |> return([u.firstName])
  """
  defmacro where(query, expr) do
    build_where(query, expr, __CALLER__)
  end

  @doc """
  Create a `RETURN` clause from a list of variables and / or properties and / or functions.

    - Cypher keyword: `RETURN`
    - Entry point: no
    - Expects: a list of variables and / or properties and / or functions.

  Note that functions and bare value must be aliased.

  ## Available functions
    - `min`
    - `max`
    - `count`
    - `avg`
    - `sum`
    - `st_dev`
    - `percentile_disc`
    - `distinct` (only to be used with aggregate function)

    - `collect`
    - `size`

    - `id`
    - `labels`
    - `type`
    - `start_node`
    - `end_node`


  ## Examples

        # return matched data and properties
        match [{u, MyApp.User, %{uid: 1}, {p, MyApp.Post}],
          return: [u.firstName, p]

        # aliased return
        match [{u, MyApp.User}],
          return: [names: u.firstName, bare_value: 5]

        # return function result
        match [{u, MyApp.User, %{uid: 1}, {p, MyApp.Post}],
          return: [nb_post: count(distinct(p))]

        # Macro syntax
        match([{u, MyApp.User, %{uid: 1}, {p, MyApp.Post}])
        |> return([nb_post: count(distinct(p))])

  """
  defmacro return(query, expr) do
    build_return(query, expr, __CALLER__)
  end

  @doc """
  Create a `DELETE` clause from list of variables.

    - Cypher keyword: `DELETE`
    - Entry point: no
    - Expects: a list of variables.

  ## Examples

        # Keyword syntax
        match [{u, MyApp.User, %{uid: 5}}],
          delete: [u]

        # Macro syntax
        match([{u, MyApp.User, %{uid: 5}}])
        |> delete([u])
  """
  defmacro delete(query, expr) do
    build_delete(query, expr, __CALLER__)
  end

  @doc """
  Create a `SET` clause from a list of expressions.

    - Cypher keyword: `SET`
    - Entry point: no
    - Expects: a list of expressions.

  ## Valid operators
    - `+`
    - `-`
    - `*`
    - `/`

  ## Valid functions
    - `collect`
    - `id`
    - `labels`
    - `type`
    - `size`

  ## Examples

        # with match (Keyword syntax)
        match [{u, Myapp.User, %{uid: 1}}],
          set: [u.firstName = "OtherName"]

        match [{p, MyApp.Post}],
          set: [p.viewCount = viewCount + 1]

        match [
          {p, MyApp.Post, %{uid: 45}},
          {u, MyApp.User},
          [{u}, [rel, MyApp.Read], {p}]
        ],
          set: [p.viewCount = size(collect(u.uid))]

        # with create (Keyword syntax)
        create [{u, Myapp.User, %{uid: 99}}],
          set: [u.firstName = "Collin", lastName = "Chou"]

        # Set label (Keyword syntax)
        match [{u, Myapp.User, %{uid: 1}}],
          set: [{u, NewAdditionalLabel}]

        # Set multiple label (Keyword syntax)
        match [{u, Myapp.User, %{uid: 1}}],
          set: [{u, [NewAdditionalLabel1, NewAdditionalLabel2]}]

        # Macro syntax
        match([{u, Myapp.User, %{uid: 1}}])
        |> set([u.firstName = "OtherName"])
  """
  defmacro set(query, expr) do
    build_set(query, expr, __CALLER__)
  end

  @doc """
  Create a `REMOVE` clause from a list of properties and / or labels.

    - Cypher keyword: `REMOVE`
    - Entry point: no
    - Expects: a list of properties and / or labels.

  ## Examples

      # Remove property (Keyword syntax)
      match [{u, MyApp.User, %{uid: 1}}],
        remove: [u.firstName],
        return: [u]

      # Remove label (Keyword syntax)
      match [{u, MyApp.User, %{uid: 1}}],
        remove: [{u, OldLabel}],
        return: [u]

      # Remove multiple labels (Keyword syntax)
      match [{u, MyApp.User, %{uid: 1}}],
        remove: [{u, [OldLabel1, OldLabel2]}],
        return: [u]

      # Remove property (Macro syntax)
      match([{u, MyApp.User, %{uid: 1}}])
      |> remove([u.firstName])
      |> return([u])
  """
  defmacro remove(query, expr) do
    build_remove(query, expr, __CALLER__)
  end

  @doc """
  Create a `ON CREATE SET` clause from a list of expression.

  Require a `MERGE`

  See `set/2` for usage details.
  """
  defmacro on_create_set(query, expr) do
    build_on_create_set(query, expr, __CALLER__)
  end

  @doc """
  Create a `ON MATCH SET` clause from a list of expression.

  Require a `MERGE`.

  See `set/2` for usage details.
  """
  defmacro on_match_set(query, expr) do
    build_on_match_set(query, expr, __CALLER__)
  end

  @doc """
  Create a `ORDER BY` clause from a list of orders.

    - Cypher keyword: `ORDER_BY`
    - Entry point: no
    - Expects: a list of orders.

  Default order is ascending (ASC)

  ## Examples

        # with default order (keyword syntax)
        match [{u, MyApp.User}],
          return: [u.firstName, u.lastName],
          order_by: [u.firstName]

        # with specific order (keyword syntax)
        match [{u, MyApp.User}],
          return: [u.firstName, u.lastName],
          order_by: [desc: u.firstName]

        # Macro syntax
        match([{u, MyApp.User}])
        |> return([u.firstName, u.lastName])
        |> order_by([u.firstName])

  """
  defmacro order_by(query, expr) do
    build_order_by(query, expr, __CALLER__)
  end

  @doc """
  Create a `SKIP` clause from value.

  - Cypher keyword: `SKIP`
    - Entry point: no
    - Expects: a value.

  ## Examples

        # Keyword syntax
        match [{u, MyApp.User}],
          return: [u.firstName, u.lastName],
          skip: 2

        # Maccro syntax
        match([{u, MyApp.User}])
        |> return([u.firstName, u.lastName])
        |> skip(2)
  """
  defmacro skip(query, expr) do
    build_skip(query, expr, __CALLER__)
  end

  @doc """
  Create a `LIMIT` clause from value.

  - Cypher keyword: `LIMIT`
    - Entry point: no
    - Expects: a value.

  ## Examples

        # Keyword syntax
        match [{u, MyApp.User}],
          return: [u.firstName, u.lastName],
          limit: 2

        # Maccro syntax
        match([{u, MyApp.User}])
        |> return([u.firstName, u.lastName])
        |> limit(2)
  """
  defmacro limit(query, expr) do
    build_limit(query, expr, __CALLER__)
  end

  @doc false
  @spec build_match(Macro.t(), Macro.t(), Macro.Env.t()) :: Macro.t()
  def build_match(query, expr, env) do
    %{match: match, identifiers: identifiers, params: params} = Builder.Match.build(expr, env)

    match = Macro.escape(match)
    identifiers = Macro.escape(identifiers)

    literal =
      expr
      |> Enum.map(&Macro.to_string/1)
      |> Enum.join(",\n\t")

    quote bind_quoted: [
            query: query,
            match: match,
            identifiers: identifiers,
            params: params,
            literal: literal
          ] do
      %{
        query
        | identifiers: Map.merge(query.identifiers, identifiers),
          operations: query.operations ++ [match: match],
          params: Keyword.merge(query.params, params),
          literal: query.literal ++ ["match:\n\t" <> literal]
      }
    end
  end

  @doc false
  @spec build_create(Macro.t(), Macro.t(), Macro.Env.t()) :: Macro.t()
  def build_create(query, expr, env) do
    %{create: create, identifiers: identifiers, params: params} = Builder.Create.build(expr, env)

    create = Macro.escape(create)
    identifiers = Macro.escape(identifiers)

    literal =
      expr
      |> Enum.map(&Macro.to_string/1)
      |> Enum.join(",\n\t")

    quote bind_quoted: [
            query: query,
            create: create,
            identifiers: identifiers,
            params: params,
            literal: literal
          ] do
      %{
        query
        | # Order is crucial here
          identifiers: Map.merge(identifiers, query.identifiers),
          operations: query.operations ++ [create: create],
          params: Keyword.merge(query.params, params),
          literal: query.literal ++ ["create:\n\t" <> literal]
      }
    end
  end

  @doc false
  @spec build_merge(Macro.t(), Macro.t(), Macro.Env.t()) :: Macro.t()
  def build_merge(query, expr, env) do
    %{merge: merge, identifiers: identifiers, params: params} = Builder.Merge.build(expr, env)

    merge = Macro.escape(merge)

    identifiers = Macro.escape(identifiers)

    literal = Macro.to_string(expr)

    quote bind_quoted: [
            query: query,
            merge: merge,
            identifiers: identifiers,
            params: params,
            literal: literal
          ] do
      %{
        query
        | # Order is crucial here
          identifiers: Map.merge(identifiers, query.identifiers),
          operations: query.operations ++ [merge: merge],
          params: Keyword.merge(query.params, params),
          literal: query.literal ++ ["merge:\n\t" <> literal]
      }
    end
  end

  @doc false
  @spec build_where(Macro.t(), Macro.t(), Macro.Env.t()) :: Macro.t()
  def build_where(query, expr, env) do
    %{condition: condition, params: params} = Seraph.Query.Builder.Where.build(expr, env)

    condition = Macro.escape(condition)

    literal =
      expr
      |> Macro.to_string()
      |> String.replace("()", "")

    quote bind_quoted: [
            query: query,
            condition: condition,
            params: params,
            literal: literal
          ] do
      %{
        query
        | operations: query.operations ++ [where: condition],
          params: Keyword.merge(query.params, params),
          literal: query.literal ++ ["where:\n\t" <> literal]
      }
    end
  end

  @doc false
  @spec build_return(Macro.t(), Macro.t(), Macro.Env.t()) :: Macro.t()
  def build_return(query, expr, env) when not is_list(expr) do
    build_return(query, [expr], env)
  end

  def build_return(query, expr, env) do
    %{return: return, params: params} = Seraph.Query.Builder.Return.build(expr, env)

    return = Macro.escape(return)

    literal =
      expr
      |> Enum.map(&Macro.to_string/1)
      |> Enum.join(", ")
      |> String.replace("()", "")

    quote bind_quoted: [query: query, literal: literal, return: return, params: params] do
      %{
        query
        | operations: query.operations ++ [return: return],
          literal: query.literal ++ ["return:\n\t" <> literal],
          params: Keyword.merge(query.params, params)
      }
    end
  end

  @doc false
  @spec build_delete(Macro.t(), Macro.t(), Macro.Env.t()) :: Macro.t()
  def build_delete(query, expr, env) do
    delete =
      Seraph.Query.Builder.Delete.build(expr, env)
      |> Macro.escape()

    literal =
      expr
      |> Enum.map(&Macro.to_string/1)
      |> Enum.join(", ")
      |> String.replace("()", "")

    quote bind_quoted: [query: query, literal: literal, delete: delete] do
      %{
        query
        | operations: query.operations ++ [delete: delete],
          literal: query.literal ++ ["delete:\n" <> literal]
      }
    end
  end

  @doc false
  @spec build_on_create_set(Macro.t(), Macro.t(), Macro.Env.t()) :: Macro.t()
  def build_on_create_set(query, expr, env) do
    %{on_create_set: on_create_set, params: params} =
      Seraph.Query.Builder.OnCreateSet.build(expr, env)

    on_create_set = Macro.escape(on_create_set)

    literal =
      expr
      |> Enum.map(&Macro.to_string/1)
      |> Enum.join(", \n\t")
      |> String.replace("()", "")

    quote bind_quoted: [
            query: query,
            on_create_set: on_create_set,
            params: params,
            literal: literal
          ] do
      %{
        query
        | operations: query.operations ++ [on_create_set: on_create_set],
          literal: query.literal ++ ["on_create_set: \n\t" <> literal],
          params: Keyword.merge(query.params, params)
      }
    end
  end

  @doc false
  @spec build_on_match_set(Macro.t(), Macro.t(), Macro.Env.t()) :: Macro.t()
  def build_on_match_set(query, expr, env) do
    %{on_match_set: on_match_set, params: params} =
      Seraph.Query.Builder.OnMatchSet.build(expr, env)

    on_match_set = Macro.escape(on_match_set)

    literal =
      expr
      |> Enum.map(&Macro.to_string/1)
      |> Enum.join(", \n\t")
      |> String.replace("()", "")

    quote bind_quoted: [
            query: query,
            on_match_set: on_match_set,
            params: params,
            literal: literal
          ] do
      %{
        query
        | operations: query.operations ++ [on_match_set: on_match_set],
          literal: query.literal ++ ["on_match_set: \n\t" <> literal],
          params: Keyword.merge(query.params, params)
      }
    end
  end

  @doc false
  @spec build_set(Macro.t(), Macro.t(), any) :: Macro.t()
  def build_set(query, expr, env) do
    %{set: set, params: params} = Seraph.Query.Builder.Set.build(expr, env)

    set = Macro.escape(set)

    literal =
      expr
      |> Enum.map(&Macro.to_string/1)
      |> Enum.join(", \n\t")
      |> String.replace("()", "")

    quote bind_quoted: [query: query, set: set, params: params, literal: literal] do
      %{
        query
        | operations: query.operations ++ [set: set],
          literal: query.literal ++ ["set: \n\t" <> literal],
          params: Keyword.merge(query.params, params)
      }
    end
  end

  @doc false
  @spec build_remove(Macro.t(), Macro.t(), Macro.Env.t()) :: Macro.t()
  def build_remove(query, expr, env) do
    remove =
      Seraph.Query.Builder.Remove.build(expr, env)
      |> Macro.escape()

    literal =
      expr
      |> Enum.map(&Macro.to_string/1)
      |> Enum.join(", \n\t")
      |> String.replace("()", "")

    quote bind_quoted: [query: query, remove: remove, literal: literal] do
      %{
        query
        | operations: query.operations ++ [remove: remove],
          literal: query.literal ++ ["remove: \n\t" <> literal]
      }
    end
  end

  @doc false
  @spec build_order_by(Macro.t(), Macro.t(), Macro.Env.t()) :: Macro.t()
  def build_order_by(query, expr, env) do
    order_by =
      Builder.OrderBy.build(expr, env)
      |> Macro.escape()

    literal =
      expr
      |> Enum.map(&Macro.to_string/1)
      |> Enum.join(", \n\t")
      |> String.replace("()", "")

    quote bind_quoted: [query: query, order_by: order_by, literal: literal] do
      %{
        query
        | operations: query.operations ++ [order_by: order_by],
          literal: query.literal ++ ["order_by: \n\t" <> literal]
      }
    end
  end

  @doc false
  @spec build_skip(Macro.t(), Macro.t(), Macro.Env.t()) :: Macro.t()
  def build_skip(query, expr, env) do
    %{skip: skip, params: params} = Builder.Skip.build(expr, env)

    skip = Macro.escape(skip)

    literal =
      expr
      |> Macro.to_string()
      |> String.replace("()", "")

    quote bind_quoted: [query: query, skip: skip, params: params, literal: literal] do
      %{
        query
        | operations: query.operations ++ [skip: skip],
          literal: query.literal ++ ["skip: " <> literal],
          params: Keyword.merge(query.params, params)
      }
    end
  end

  @doc false
  @spec build_limit(Macro.t(), Macro.t(), Macro.Env.t()) :: Macro.t()
  def build_limit(query, expr, env) do
    %{limit: limit, params: params} = Builder.Limit.build(expr, env)

    limit = Macro.escape(limit)

    literal =
      expr
      |> Macro.to_string()
      |> String.replace("()", "")

    quote bind_quoted: [query: query, limit: limit, params: params, literal: literal] do
      %{
        query
        | operations: query.operations ++ [limit: limit],
          literal: query.literal ++ ["limit: " <> literal],
          params: Keyword.merge(query.params, params)
      }
    end
  end

  @doc false
  @spec prepare(Seraph.Query.t(), Keyword.t()) :: Seraph.Query.t()
  def prepare(query, opts) do
    check(query, opts)

    do_prepare(query, opts)
    |> post_check(opts)
  end

  @spec check(Seraph.Query.t(), Keyword.t()) :: :ok
  defp check(query, _opts) do
    Enum.each(query.operations, fn {operation, operation_data} ->
      mod_name =
        operation
        |> Atom.to_string()
        |> Inflex.camelize()

      module = Module.concat(["Seraph.Query.Builder", mod_name])

      apply(module, :check, [operation_data, query])
      |> raise_if_fail!(query)
    end)
  end

  @spec do_prepare(Seraph.Query.t(), Keyword.t()) :: Seraph.Query.t()
  defp do_prepare(query, opts) do
    Enum.reduce(query.operations, query, fn
      {:return, return}, old_query ->
        new_return = Builder.Return.prepare(return, old_query, opts)

        %{
          old_query
          | operations: Keyword.update!(old_query.operations, :return, fn _ -> new_return end)
        }

      {:create, create}, old_query ->
        %{create: new_create, new_identifiers: new_identifiers} =
          Builder.Create.prepare(create, old_query, opts)

        %{
          old_query
          | identifiers: Map.merge(query.identifiers, new_identifiers),
            operations: Keyword.update!(old_query.operations, :create, fn _ -> new_create end)
        }

      {:merge, merge}, old_query ->
        %{merge: new_merge, new_identifiers: new_identifiers} =
          Builder.Merge.prepare(merge, old_query, opts)

        %{
          old_query
          | identifiers: Map.merge(query.identifiers, new_identifiers),
            operations: Keyword.update!(old_query.operations, :merge, fn _ -> new_merge end)
        }

      {:delete, delete}, old_query ->
        new_delete = Builder.Delete.prepare(delete, query, opts)

        %{
          old_query
          | operations: Keyword.update!(old_query.operations, :delete, fn _ -> new_delete end)
        }

      {:order_by, order_by}, old_query ->
        new_order_by = Builder.OrderBy.prepare(order_by, query, opts)

        %{
          old_query
          | operations: Keyword.update!(old_query.operations, :order_by, fn _ -> new_order_by end)
        }

      _, old_query ->
        old_query
    end)
  end

  @spec post_check(Seraph.Query.t(), Keyword.t()) :: Seraph.Query.t()
  defp post_check(%Seraph.Query{} = query, _opts) do
    changes =
      Enum.reduce(query.operations, %{}, fn
        {:create, create_data}, changes ->
          Enum.map(create_data.raw_entities, &extract_changes(&1, :create))
          |> List.flatten()
          |> Enum.reduce(changes, fn data, changes ->
            Map.put(changes, data.identifier, data)
          end)

        {:merge, merge_data}, changes ->
          change = change = extract_changes(merge_data.raw_entities, :create_or_merge)

          if is_list(change) do
            Enum.reduce(change, changes, fn data, changes ->
              Map.put(changes, data.identifier, data)
            end)
          else
            Map.put(changes, change.identifier, change)
          end

        {:set, set_data}, changes ->
          extract_set_changes(set_data, query, changes)

        # {:on_create_set, on_create_set_data}, changes ->
        #   extract_set_changes(on_create_set_data, query, changes)

        {:on_match_set, on_match_set_data}, changes ->
          extract_set_changes(on_match_set_data, query, changes)

        _, changes ->
          changes
      end)

    do_check_changes(Map.values(changes))
    |> raise_if_fail!(query)
  end

  defp extract_changes(%Builder.Entity.Node{} = entity, change_type) do
    changed_props =
      case change_type do
        :create_or_merge ->
          []

        _ ->
          Enum.map(entity.properties, fn %Builder.Entity.Property{name: prop_name} ->
            prop_name
          end)
      end

    %{
      identifier: entity.identifier,
      queryable: entity.queryable,
      changed_properties: changed_props,
      change_type: change_type
    }
  end

  defp extract_changes(
         %Builder.Entity.Relationship{start: start_node, end: end_node},
         change_type
       ) do
    start_data = extract_changes(start_node, change_type)
    end_data = extract_changes(end_node, change_type)
    [start_data, end_data]
  end

  defp extract_set_changes(set_data, query, changes) do
    Enum.reduce(set_data.expressions, changes, fn
      %Builder.Entity.Property{} = property, changes ->
        case Map.fetch(changes, property.entity_identifier) do
          {:ok, change} ->
            entity = Map.fetch!(query.identifiers, property.entity_identifier)

            if entity.queryable.__schema__(:entity_type) == :node do
              new_props = [property.name | change.changed_properties]
              # new_change = Map.put(change, :changed_properties, new_props)
              new_change_type =
                case change.change_type do
                  :create_or_merge ->
                    # if Kernel.match?(%Builder.OnCreateSet{}, set_data) do
                    #   :create
                    # else
                    #   :merge
                    # end

                    if Kernel.match?(%Builder.OnMatchSet{}, set_data) do
                      :merge
                    else
                      :create_or_merge
                    end

                  c_type ->
                    c_type
                end

              new_change = %{change | changed_properties: new_props, change_type: new_change_type}

              Map.put(changes, property.entity_identifier, new_change)
            else
              changes
            end

          :error ->
            entity = Map.fetch!(query.identifiers, property.entity_identifier)

            if entity.queryable.__schema__(:entity_type) == :node do
              new_change = %{
                identifier: property.entity_identifier,
                queryable: entity.queryable,
                changed_properties: [property.name],
                change_type: :merge
              }

              Map.put(changes, property.entity_identifier, new_change)
            else
              changes
            end
        end

      _, changes ->
        changes
    end)
  end

  defp do_check_changes(changes, result \\ :ok)

  defp do_check_changes([], result) do
    result
  end

  defp do_check_changes(_, {:error, _} = error) do
    error
  end

  defp do_check_changes([%{queryable: Seraph.Node, changed_properties: []} | rest], :ok) do
    do_check_changes(rest, :ok)
  end

  defp do_check_changes([change | rest], :ok) do
    %{queryable: queryable, changed_properties: changed_properties} = change

    result =
      case change.change_type do
        :create ->
          do_check_id_field(change)

        # It is not possible to know if merge will be a create or a merge...
        :create_or_merge ->
          :ok

        # do_check_id_field(change)

        :merge ->
          id_field = Seraph.Repo.Helper.identifier_field!(queryable)

          case id_field in changed_properties do
            true ->
              message =
                "[MERGE/SET] Identifier field `#{id_field}` must NOT be changed on Node `#{
                  change.identifier
                }` for `#{queryable}`"

              {:error, message}

            false ->
              merge_keys = queryable.__schema__(:merge_keys)

              case changed_properties -- merge_keys do
                ^changed_properties ->
                  :ok

                _ ->
                  message =
                    "[MERGE/SET] Merge keys `#{inspect(merge_keys)} should not be changed on Node `#{
                      change.identifier
                    }` for `#{queryable}`"

                  {:error, message}
              end
          end
      end

    do_check_changes(rest, result)
  end

  defp do_check_id_field(change) do
    case change.queryable.__schema__(:identifier) do
      {id_field, _, _} ->
        case id_field in change.changed_properties do
          true ->
            :ok

          false ->
            message =
              "[CREATE / MERGE] Identifier field `#{id_field}` must be set on Node `#{
                change.identifier
              }` for `#{change.queryable}`"

            {:error, message}
        end

      false ->
        :ok
    end
  end

  defp raise_if_fail!(:ok, query) do
    query
  end

  defp raise_if_fail!({:error, message}, query) do
    raise Seraph.QueryError, message: message, query: query.literal
  end
end
