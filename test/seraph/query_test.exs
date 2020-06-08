defmodule Seraph.QueryTest do
  use ExUnit.Case

  import Seraph.Query
  alias Seraph.Query.Builder

  alias Seraph.Test.{MergeKeys, Post, User}
  alias Seraph.Test.UserToPost.Wrote

  describe "match node" do
    test "ok: {u}" do
      query = match([{u}])

      node_data = %Seraph.Query.Builder.Entity.Node{
        alias: nil,
        identifier: "u",
        labels: [],
        properties: [],
        queryable: Seraph.Node
      }

      assert %{"u" => ^node_data} = query.identifiers
      assert map_size(query.identifiers) == 1
      assert %Builder.Match{entities: [^node_data]} = query.operations[:match]
      assert [] == query.params
    end

    test "ok: {u, User}" do
      query = match([{u, User}])

      node_data = %Seraph.Query.Builder.Entity.Node{
        alias: nil,
        identifier: "u",
        labels: ["User"],
        properties: [],
        queryable: Seraph.Test.User
      }

      assert %{"u" => ^node_data} = query.identifiers
      assert map_size(query.identifiers) == 1
      assert %Builder.Match{entities: [^node_data]} = query.operations[:match]
      assert [] == query.params
    end

    test "ok: {u, User, %{uuid: ^user_uuid}}" do
      user_uuid = "uuid-for-query"

      query = match([{u, User, %{uuid: ^user_uuid}}])

      node_data = %Seraph.Query.Builder.Entity.Node{
        alias: nil,
        identifier: "u",
        labels: ["User"],
        properties: [
          %Seraph.Query.Builder.Entity.Property{
            alias: nil,
            bound_name: "user_uuid",
            entity_identifier: "u",
            entity_queryable: Seraph.Test.User,
            name: :uuid,
            type: nil,
            value: nil
          }
        ],
        queryable: Seraph.Test.User
      }

      assert %{"u" => ^node_data} = query.identifiers
      assert map_size(query.identifiers) == 1
      assert %Builder.Match{entities: [^node_data]} = query.operations[:match]
      assert [user_uuid: "uuid-for-query"] == query.params
    end

    test "ok: {User, %{uuid: ^user_uuid}}" do
      user_uuid = "uuid-for-query"

      query = match([{User, %{uuid: "uuid-for-query"}}])

      node_data = %Seraph.Query.Builder.Entity.Node{
        alias: nil,
        identifier: nil,
        labels: ["User"],
        properties: [
          %Seraph.Query.Builder.Entity.Property{
            alias: nil,
            bound_name: "match__prop__uuid_0",
            entity_identifier: nil,
            entity_queryable: Seraph.Test.User,
            name: :uuid,
            type: nil,
            value: nil
          }
        ],
        queryable: Seraph.Test.User
      }

      assert %{} = query.identifiers
      assert map_size(query.identifiers) == 0
      assert %Builder.Match{entities: [^node_data]} = query.operations[:match]
      assert [match__prop__uuid_0: "uuid-for-query"] == query.params
    end

    test "ok: {u, %{uuid: \"uuid-for-query\"}}" do
      query = match([{u, %{uuid: "uuid-for-query"}}])

      node_data = %Seraph.Query.Builder.Entity.Node{
        alias: nil,
        identifier: "u",
        labels: [],
        properties: [
          %Seraph.Query.Builder.Entity.Property{
            alias: nil,
            bound_name: "u_uuid_0",
            entity_identifier: "u",
            entity_queryable: Seraph.Node,
            name: :uuid,
            type: nil,
            value: nil
          }
        ],
        queryable: Seraph.Node
      }

      assert %{"u" => ^node_data} = query.identifiers
      assert map_size(query.identifiers) == 1
      assert %Builder.Match{entities: [^node_data]} = query.operations[:match]
      assert [u_uuid_0: "uuid-for-query"] == query.params
    end

    test "ok: {u, %{uuid: ^user_uuid}}" do
      user_uuid = "uuid-for-query"
      query = match([{u, %{uuid: ^user_uuid}}])

      node_data = %Seraph.Query.Builder.Entity.Node{
        alias: nil,
        identifier: "u",
        labels: [],
        properties: [
          %Seraph.Query.Builder.Entity.Property{
            alias: nil,
            bound_name: "user_uuid",
            entity_identifier: "u",
            entity_queryable: Seraph.Node,
            name: :uuid,
            type: nil,
            value: nil
          }
        ],
        queryable: Seraph.Node
      }

      assert %{"u" => ^node_data} = query.identifiers
      assert map_size(query.identifiers) == 1
      assert %Builder.Match{entities: [^node_data]} = query.operations[:match]
      assert [user_uuid: "uuid-for-query"] == query.params
    end

    test "fail: empty node {}" do
      assert_raise ArgumentError, fn ->
        defmodule EmptyNode do
          import Seraph.Query
          match([{}])
        end
      end
    end

    test "fail: only queryable {}" do
      assert_raise ArgumentError, fn ->
        defmodule EmptyNode do
          import Seraph.Query
          match([{User}])
        end
      end
    end

    test "fail: already used alias" do
      assert_raise ArgumentError, fn ->
        defmodule WillFail do
          import Seraph.Query
          match([{u, User}, {u, Post}])
        end
      end
    end

    test "fail: unknown queryable" do
      assert_raise UndefinedFunctionError, fn ->
        defmodule WillFail do
          import Seraph.Query
          match([{u, Unknown}])
        end
      end
    end
  end

  describe "match relationship" do
    test "ok: [{u}, [rel], {v}]" do
      query = match([[{u}, [rel], {v}]])

      start_data = %Seraph.Query.Builder.Entity.Node{
        alias: nil,
        identifier: "u",
        labels: [],
        properties: [],
        queryable: Seraph.Node
      }

      end_data = %Seraph.Query.Builder.Entity.Node{
        alias: nil,
        identifier: "v",
        labels: [],
        properties: [],
        queryable: Seraph.Node
      }

      rel_data = %Seraph.Query.Builder.Entity.Relationship{
        alias: nil,
        end: end_data,
        identifier: "rel",
        properties: [],
        queryable: Seraph.Relationship,
        start: start_data,
        type: nil
      }

      assert %{"rel" => ^rel_data, "u" => ^start_data, "v" => ^end_data} = query.identifiers
      assert map_size(query.identifiers) == 3
      assert %Builder.Match{entities: [^rel_data]} = query.operations[:match]
      assert [] == query.params
    end

    test "ok: [{u}, [Wrote], {v}]" do
      query = match([[{u}, [Wrote], {v}]])

      start_data = %Seraph.Query.Builder.Entity.Node{
        alias: nil,
        identifier: "u",
        labels: ["User"],
        properties: [],
        queryable: Seraph.Test.User
      }

      end_data = %Seraph.Query.Builder.Entity.Node{
        alias: nil,
        identifier: "v",
        labels: ["Post"],
        properties: [],
        queryable: Seraph.Test.Post
      }

      rel_data = %Seraph.Query.Builder.Entity.Relationship{
        alias: nil,
        end: end_data,
        identifier: nil,
        properties: [],
        queryable: Seraph.Test.UserToPost.Wrote,
        start: start_data,
        type: "WROTE"
      }

      assert %{"u" => ^start_data, "v" => ^end_data} = query.identifiers
      assert map_size(query.identifiers) == 2
      assert %Builder.Match{entities: [^rel_data]} = query.operations[:match]
      assert [] == query.params
    end

    test "ok: [{u}, [rel, Wrote], {v}]" do
      query = match([[{u}, [rel, Wrote], {v}]])

      start_data = %Seraph.Query.Builder.Entity.Node{
        alias: nil,
        identifier: "u",
        labels: ["User"],
        properties: [],
        queryable: Seraph.Test.User
      }

      end_data = %Seraph.Query.Builder.Entity.Node{
        alias: nil,
        identifier: "v",
        labels: ["Post"],
        properties: [],
        queryable: Seraph.Test.Post
      }

      rel_data = %Seraph.Query.Builder.Entity.Relationship{
        alias: nil,
        end: end_data,
        identifier: "rel",
        properties: [],
        queryable: Seraph.Test.UserToPost.Wrote,
        start: start_data,
        type: "WROTE"
      }

      assert %{"rel" => ^rel_data, "u" => ^start_data, "v" => ^end_data} = query.identifiers
      assert map_size(query.identifiers) == 3
      assert %Builder.Match{entities: [^rel_data]} = query.operations[:match]
      assert [] == query.params
    end

    test "ok: [{u}, [Wrote, %{at: ^date}], {v}]" do
      date = DateTime.from_naive!(~N[2016-05-24 13:26:08], "Etc/UTC")
      query = match([[{u}, [Wrote, %{at: ^date}], {v}]])

      start_data = %Seraph.Query.Builder.Entity.Node{
        alias: nil,
        identifier: "u",
        labels: ["User"],
        properties: [],
        queryable: Seraph.Test.User
      }

      end_data = %Seraph.Query.Builder.Entity.Node{
        alias: nil,
        identifier: "v",
        labels: ["Post"],
        properties: [],
        queryable: Seraph.Test.Post
      }

      rel_data = %Seraph.Query.Builder.Entity.Relationship{
        alias: nil,
        end: end_data,
        identifier: nil,
        properties: [
          %Seraph.Query.Builder.Entity.Property{
            alias: nil,
            bound_name: "date",
            entity_identifier: nil,
            entity_queryable: Seraph.Test.UserToPost.Wrote,
            name: :at,
            type: nil,
            value: nil
          }
        ],
        queryable: Seraph.Test.UserToPost.Wrote,
        start: start_data,
        type: "WROTE"
      }

      assert %{"u" => ^start_data, "v" => ^end_data} = query.identifiers
      assert map_size(query.identifiers) == 2
      assert %Builder.Match{entities: [^rel_data]} = query.operations[:match]
      assert [date: _] = query.params
    end

    test "ok: [{u}, [rel, Wrote, %{at: \"2020-05-04\"}], {v}]" do
      query =
        match([
          [
            {u},
            [rel, Wrote, %{at: DateTime.from_naive!(~N[2016-05-24 13:26:08], "Etc/UTC")}],
            {v}
          ]
        ])

      start_data = %Seraph.Query.Builder.Entity.Node{
        alias: nil,
        identifier: "u",
        labels: ["User"],
        properties: [],
        queryable: Seraph.Test.User
      }

      end_data = %Seraph.Query.Builder.Entity.Node{
        alias: nil,
        identifier: "v",
        labels: ["Post"],
        properties: [],
        queryable: Seraph.Test.Post
      }

      rel_data = %Seraph.Query.Builder.Entity.Relationship{
        alias: nil,
        end: end_data,
        identifier: "rel",
        properties: [
          %Seraph.Query.Builder.Entity.Property{
            alias: nil,
            bound_name: "rel_at_0",
            entity_identifier: "rel",
            entity_queryable: Seraph.Test.UserToPost.Wrote,
            name: :at,
            type: nil,
            value: nil
          }
        ],
        queryable: Seraph.Test.UserToPost.Wrote,
        start: start_data,
        type: "WROTE"
      }

      assert %{"rel" => ^rel_data, "u" => ^start_data, "v" => ^end_data} = query.identifiers
      assert map_size(query.identifiers) == 3
      assert %Builder.Match{entities: [^rel_data]} = query.operations[:match]
      assert [rel_at_0: _] = query.params
    end

    test "ok: [{u}, [rel, Wrote, %{at: ^date}], {v}]" do
      date = DateTime.from_naive!(~N[2016-05-24 13:26:08], "Etc/UTC")
      query = match([[{u}, [rel, Wrote, %{at: ^date}], {v}]])

      start_data = %Seraph.Query.Builder.Entity.Node{
        alias: nil,
        identifier: "u",
        labels: ["User"],
        properties: [],
        queryable: Seraph.Test.User
      }

      end_data = %Seraph.Query.Builder.Entity.Node{
        alias: nil,
        identifier: "v",
        labels: ["Post"],
        properties: [],
        queryable: Seraph.Test.Post
      }

      rel_data = %Seraph.Query.Builder.Entity.Relationship{
        alias: nil,
        end: end_data,
        identifier: "rel",
        properties: [
          %Seraph.Query.Builder.Entity.Property{
            alias: nil,
            bound_name: "date",
            entity_identifier: "rel",
            entity_queryable: Seraph.Test.UserToPost.Wrote,
            name: :at,
            type: nil,
            value: nil
          }
        ],
        queryable: Seraph.Test.UserToPost.Wrote,
        start: start_data,
        type: "WROTE"
      }

      assert %{"rel" => ^rel_data, "u" => ^start_data, "v" => ^end_data} = query.identifiers
      assert map_size(query.identifiers) == 3
      assert %Builder.Match{entities: [^rel_data]} = query.operations[:match]
      assert [date: _] = query.params
    end

    test "ok: [{u}, [rel, %{at: ^date}], {v}]" do
      date = DateTime.from_naive!(~N[2016-05-24 13:26:08], "Etc/UTC")
      query = match([[{u}, [rel, %{at: ^date}], {v}]])

      start_data = %Seraph.Query.Builder.Entity.Node{
        alias: nil,
        identifier: "u",
        labels: [],
        properties: [],
        queryable: Seraph.Node
      }

      end_data = %Seraph.Query.Builder.Entity.Node{
        alias: nil,
        identifier: "v",
        labels: [],
        properties: [],
        queryable: Seraph.Node
      }

      rel_data = %Seraph.Query.Builder.Entity.Relationship{
        alias: nil,
        end: end_data,
        identifier: "rel",
        properties: [
          %Seraph.Query.Builder.Entity.Property{
            alias: nil,
            bound_name: "date",
            entity_identifier: "rel",
            entity_queryable: Seraph.Relationship,
            name: :at,
            type: nil,
            value: nil
          }
        ],
        queryable: Seraph.Relationship,
        start: start_data,
        type: nil
      }

      assert %{"rel" => ^rel_data, "u" => ^start_data, "v" => ^end_data} = query.identifiers
      assert map_size(query.identifiers) == 3
      assert %Builder.Match{entities: [^rel_data]} = query.operations[:match]
      assert [date: _] = query.params
    end

    test "ok: [{}, [rel], {v}]" do
      query = match([[{}, [rel], {v}]])

      start_data = %Seraph.Query.Builder.Entity.Node{
        alias: nil,
        identifier: nil,
        labels: [],
        properties: [],
        queryable: Seraph.Node
      }

      end_data = %Seraph.Query.Builder.Entity.Node{
        alias: nil,
        identifier: "v",
        labels: [],
        properties: [],
        queryable: Seraph.Node
      }

      rel_data = %Seraph.Query.Builder.Entity.Relationship{
        alias: nil,
        end: end_data,
        identifier: "rel",
        properties: [],
        queryable: Seraph.Relationship,
        start: start_data,
        type: nil
      }

      assert %{"rel" => ^rel_data, "v" => ^end_data} = query.identifiers
      assert map_size(query.identifiers) == 2
      assert %Builder.Match{entities: [^rel_data]} = query.operations[:match]
      assert [] = query.params
    end

    test "ok: [{u}, [], {v}]" do
      query = match([[{u}, [], {v}]])

      start_data = %Seraph.Query.Builder.Entity.Node{
        alias: nil,
        identifier: "u",
        labels: [],
        properties: [],
        queryable: Seraph.Node
      }

      end_data = %Seraph.Query.Builder.Entity.Node{
        alias: nil,
        identifier: "v",
        labels: [],
        properties: [],
        queryable: Seraph.Node
      }

      rel_data = %Seraph.Query.Builder.Entity.Relationship{
        alias: nil,
        end: end_data,
        identifier: nil,
        properties: [],
        queryable: Seraph.Relationship,
        start: start_data,
        type: nil
      }

      assert %{"u" => ^start_data, "v" => ^end_data} = query.identifiers
      assert map_size(query.identifiers) == 2
      assert %Builder.Match{entities: [^rel_data]} = query.operations[:match]
      assert [] = query.params
    end

    test "ok: [{u}, [rel], {p, Post}]" do
      query = match([[{u}, [rel], {p, Post}]])

      start_data = %Seraph.Query.Builder.Entity.Node{
        alias: nil,
        identifier: "u",
        labels: [],
        properties: [],
        queryable: Seraph.Node
      }

      end_data = %Seraph.Query.Builder.Entity.Node{
        alias: nil,
        identifier: "p",
        labels: ["Post"],
        properties: [],
        queryable: Seraph.Test.Post
      }

      rel_data = %Seraph.Query.Builder.Entity.Relationship{
        alias: nil,
        end: end_data,
        identifier: "rel",
        properties: [],
        queryable: Seraph.Relationship,
        start: start_data,
        type: nil
      }

      assert %{"rel" => ^rel_data, "u" => ^start_data, "p" => ^end_data} = query.identifiers
      assert map_size(query.identifiers) == 3
      assert %Builder.Match{entities: [^rel_data]} = query.operations[:match]
      assert [] = query.params
    end

    test "ok: [{u, User}, [rel], {p, Post}]" do
      query = match([[{u, User}, [rel], {p, Post}]])

      start_data = %Seraph.Query.Builder.Entity.Node{
        alias: nil,
        identifier: "u",
        labels: ["User"],
        properties: [],
        queryable: Seraph.Test.User
      }

      end_data = %Seraph.Query.Builder.Entity.Node{
        alias: nil,
        identifier: "p",
        labels: ["Post"],
        properties: [],
        queryable: Seraph.Test.Post
      }

      rel_data = %Seraph.Query.Builder.Entity.Relationship{
        alias: nil,
        end: end_data,
        identifier: "rel",
        properties: [],
        queryable: Seraph.Relationship,
        start: start_data,
        type: nil
      }

      assert %{"rel" => ^rel_data, "u" => ^start_data, "p" => ^end_data} = query.identifiers
      assert map_size(query.identifiers) == 3
      assert %Builder.Match{entities: [^rel_data]} = query.operations[:match]
      assert [] = query.params
    end

    test "ok: [{u, User, %{firstName: \"John\"}}, [rel], {p, Post}]" do
      query = match([[{u, User, %{firstName: "John"}}, [rel], {p, Post}]])

      start_data = %Seraph.Query.Builder.Entity.Node{
        alias: nil,
        identifier: "u",
        labels: ["User"],
        properties: [
          %Seraph.Query.Builder.Entity.Property{
            alias: nil,
            bound_name: "u_firstName_0",
            entity_identifier: "u",
            entity_queryable: Seraph.Test.User,
            name: :firstName,
            type: nil,
            value: nil
          }
        ],
        queryable: Seraph.Test.User
      }

      end_data = %Seraph.Query.Builder.Entity.Node{
        alias: nil,
        identifier: "p",
        labels: ["Post"],
        properties: [],
        queryable: Seraph.Test.Post
      }

      rel_data = %Seraph.Query.Builder.Entity.Relationship{
        alias: nil,
        end: end_data,
        identifier: "rel",
        properties: [],
        queryable: Seraph.Relationship,
        start: start_data,
        type: nil
      }

      assert %{"rel" => ^rel_data, "u" => ^start_data, "p" => ^end_data} = query.identifiers
      assert map_size(query.identifiers) == 3
      assert %Builder.Match{entities: [^rel_data]} = query.operations[:match]
      assert [u_firstName_0: "John"] = query.params
    end

    test "ok: [{User}, [rel], {Post}]" do
      query = match([[{User}, [rel], {Post}]])

      rel_data = %Seraph.Query.Builder.Entity.Relationship{
        alias: nil,
        end: %Seraph.Query.Builder.Entity.Node{
          alias: nil,
          identifier: nil,
          labels: ["Post"],
          properties: [],
          queryable: Seraph.Test.Post
        },
        identifier: "rel",
        properties: [],
        queryable: Seraph.Relationship,
        start: %Seraph.Query.Builder.Entity.Node{
          alias: nil,
          identifier: nil,
          labels: ["User"],
          properties: [],
          queryable: Seraph.Test.User
        },
        type: nil
      }

      assert %{"rel" => ^rel_data} = query.identifiers
      assert map_size(query.identifiers) == 1
      assert %Builder.Match{entities: [^rel_data]} = query.operations[:match]
    end

    test "ok: [{}, [\"WROTE\"], {}]" do
      query = match([[{}, ["WROTE"], {}]])

      rel_data = %Seraph.Query.Builder.Entity.Relationship{
        alias: nil,
        end: %Seraph.Query.Builder.Entity.Node{
          alias: nil,
          identifier: nil,
          labels: [],
          properties: [],
          queryable: Seraph.Node
        },
        identifier: nil,
        properties: [],
        queryable: Seraph.Relationship,
        start: %Seraph.Query.Builder.Entity.Node{
          alias: nil,
          identifier: nil,
          labels: [],
          properties: [],
          queryable: Seraph.Node
        },
        type: "WROTE"
      }

      assert %{} == query.identifiers
      assert %Builder.Match{entities: [^rel_data]} = query.operations[:match]
      assert [] == query.params
    end

    test "ok: [{}, [rel, \"WROTE\"], {}]" do
      query = match([[{}, [rel, "WROTE"], {}]])

      rel_data = %Seraph.Query.Builder.Entity.Relationship{
        alias: nil,
        end: %Seraph.Query.Builder.Entity.Node{
          alias: nil,
          identifier: nil,
          labels: [],
          properties: [],
          queryable: Seraph.Node
        },
        identifier: "rel",
        properties: [],
        queryable: Seraph.Relationship,
        start: %Seraph.Query.Builder.Entity.Node{
          alias: nil,
          identifier: nil,
          labels: [],
          properties: [],
          queryable: Seraph.Node
        },
        type: "WROTE"
      }

      assert %{"rel" => ^rel_data} = query.identifiers
      assert map_size(query.identifiers) == 1
      assert %Builder.Match{entities: [^rel_data]} = query.operations[:match]
      assert [] == query.params
    end

    test "ok: [{}, [rel, \"WROTE\", %{count: 5}], {}]" do
      query = match([[{}, [rel, "WROTE", %{count: 5}], {}]])

      rel_data = %Seraph.Query.Builder.Entity.Relationship{
        alias: nil,
        end: %Seraph.Query.Builder.Entity.Node{
          alias: nil,
          identifier: nil,
          labels: [],
          properties: [],
          queryable: Seraph.Node
        },
        identifier: "rel",
        properties: [
          %Seraph.Query.Builder.Entity.Property{
            alias: nil,
            bound_name: "rel_count_0",
            entity_identifier: "rel",
            entity_queryable: Seraph.Relationship,
            name: :count,
            type: nil,
            value: nil
          }
        ],
        queryable: Seraph.Relationship,
        start: %Seraph.Query.Builder.Entity.Node{
          alias: nil,
          identifier: nil,
          labels: [],
          properties: [],
          queryable: Seraph.Node
        },
        type: "WROTE"
      }

      assert %{"rel" => ^rel_data} = query.identifiers
      assert map_size(query.identifiers) == 1
      assert %Builder.Match{entities: [^rel_data]} = query.operations[:match]
      assert [rel_count_0: 5] == query.params
    end

    test "ok: [{}, [\"WROTE\", %{count: 5}], {}]" do
      query = match([[{}, ["WROTE", %{count: 5}], {}]])

      rel_data = %Seraph.Query.Builder.Entity.Relationship{
        alias: nil,
        end: %Seraph.Query.Builder.Entity.Node{
          alias: nil,
          identifier: nil,
          labels: [],
          properties: [],
          queryable: Seraph.Node
        },
        identifier: nil,
        properties: [
          %Seraph.Query.Builder.Entity.Property{
            alias: nil,
            bound_name: "match__prop__count_0",
            entity_identifier: nil,
            entity_queryable: Seraph.Relationship,
            name: :count,
            type: nil,
            value: nil
          }
        ],
        queryable: Seraph.Relationship,
        start: %Seraph.Query.Builder.Entity.Node{
          alias: nil,
          identifier: nil,
          labels: [],
          properties: [],
          queryable: Seraph.Node
        },
        type: "WROTE"
      }

      assert %{} == query.identifiers
      assert %Builder.Match{entities: [^rel_data]} = query.operations[:match]
      assert [match__prop__count_0: 5] == query.params
    end

    test "fail: empty rel [{}, [], {}]" do
      assert_raise ArgumentError, fn ->
        defmodule EmptyRel do
          import Seraph.Query
          match([[{}, [], {}]])
        end
      end
    end

    test "fail: already used alias (rel)" do
      assert_raise(ArgumentError, fn ->
        defmodule WillFail do
          import Seraph.Query
          match([{rel}, [{}, [rel], {}]])
        end
      end)
    end

    test "fail: already used alias (node)" do
      assert_raise ArgumentError, fn ->
        defmodule WillFail do
          import Seraph.Query
          match([{n, User}, [{n, Post}, [rel], {}]])
        end
      end
    end

    test "fail: unknown queryable" do
      assert_raise UndefinedFunctionError, fn ->
        defmodule WillFail do
          import Seraph.Query
          match([[{}, [rel, Unknown], {}]])
        end
      end
    end

    test "fail: invalid relationship type" do
      assert_raise ArgumentError, fn ->
        defmodule WillFail do
          import Seraph.Query
          match([[{}, ["333NOT_VALID"], {}]])
        end
      end
    end
  end

  describe "where" do
    test "ok: operator :== with direct value" do
      query =
        match [{u, User}],
          where: u.uuid == "uuid-1"

      condition = %Seraph.Query.Builder.Condition{
        bound_name: "where__0",
        conditions: nil,
        entity_identifier: "u",
        join_operator: :and,
        operator: :==,
        value: nil,
        variable: :uuid
      }

      assert condition == query.operations[:where]
      assert [where__0: "uuid-1"] = query.params
    end

    test "ok: operator :== with pinned value" do
      uuid = "uuid-1"

      query =
        match [{u, User}],
          where: u.uuid == ^uuid

      condition = %Seraph.Query.Builder.Condition{
        bound_name: "uuid",
        conditions: nil,
        entity_identifier: "u",
        join_operator: :and,
        operator: :==,
        value: nil,
        variable: :uuid
      }

      assert condition == query.operations[:where]
      assert [uuid: "uuid-1"] = query.params
    end

    test "ok: operator :and" do
      query =
        match([{u, User}])
        |> where(u.uuid == "uuid-1" and u.firstName == "John")

      condition = %Seraph.Query.Builder.Condition{
        bound_name: nil,
        conditions: [
          %Seraph.Query.Builder.Condition{
            bound_name: "where__0",
            conditions: nil,
            entity_identifier: "u",
            join_operator: :and,
            operator: :==,
            value: nil,
            variable: :uuid
          },
          %Seraph.Query.Builder.Condition{
            bound_name: "where__1",
            conditions: nil,
            entity_identifier: "u",
            join_operator: :and,
            operator: :==,
            value: nil,
            variable: :firstName
          }
        ],
        entity_identifier: nil,
        join_operator: :and,
        operator: :and,
        value: nil,
        variable: nil
      }

      assert condition == query.operations[:where]
      assert [where__1: "John", where__0: "uuid-1"] = query.params
    end

    test "ok: operator :is_nil" do
      query =
        match [{u, User}],
          where: is_nil(u.lastName)

      condition = %Seraph.Query.Builder.Condition{
        bound_name: nil,
        conditions: nil,
        entity_identifier: "u",
        join_operator: :and,
        operator: :is_nil,
        value: nil,
        variable: :lastName
      }

      assert condition == query.operations[:where]
      assert [] == query.params
    end

    test "ok: operator :not" do
      query =
        match [{u, User}],
          where: not is_nil(u.lastName)

      condition = %Seraph.Query.Builder.Condition{
        bound_name: nil,
        conditions: [
          %Seraph.Query.Builder.Condition{
            bound_name: nil,
            conditions: nil,
            entity_identifier: "u",
            join_operator: :and,
            operator: :is_nil,
            value: nil,
            variable: :lastName
          }
        ],
        entity_identifier: nil,
        join_operator: :and,
        operator: :not,
        value: nil,
        variable: nil
      }

      assert condition == query.operations[:where]
      assert [] == query.params
    end

    test "ok: multiple bound params" do
      ln = "James"

      query =
        match([{u, User}])
        |> where(u.uuid == "uuid-1" and u.lastName == ^ln and u.firstName == "John")

      assert [where__1: "John", ln: "James", where__0: "uuid-1"] == query.params
    end
  end

  describe "return" do
    test "ok: entity return" do
      query =
        match([{u, User}])
        |> return([u])
        |> prepare([])

      return = %Seraph.Query.Builder.Return{
        distinct?: false,
        raw_variables: nil,
        variables: %{
          "u" => %Seraph.Query.Builder.Entity.Node{
            alias: nil,
            identifier: "u",
            labels: ["User"],
            properties: [],
            queryable: Seraph.Test.User
          }
        }
      }

      assert return == query.operations[:return]
      assert [] == query.params
    end

    test "ok: property return" do
      query =
        match([{u, User}])
        |> return([u.uuid])
        |> prepare([])

      return = %Seraph.Query.Builder.Return{
        distinct?: false,
        raw_variables: nil,
        variables: %{
          "u.uuid" => %Seraph.Query.Builder.Entity.Property{
            alias: nil,
            bound_name: nil,
            entity_identifier: "u",
            entity_queryable: Seraph.Test.User,
            name: :uuid,
            type: nil,
            value: nil
          }
        }
      }

      assert return == query.operations[:return]
      assert [] == query.params
    end

    test "ok: aliased returns" do
      query =
        match([{u, User}])
        |> return(res_node: u, res_prop: u.uuid)
        |> prepare([])

      return = %Seraph.Query.Builder.Return{
        distinct?: false,
        raw_variables: nil,
        variables: %{
          "res_node" => %Seraph.Query.Builder.Entity.Node{
            alias: :res_node,
            identifier: "u",
            labels: ["User"],
            properties: [],
            queryable: Seraph.Test.User
          },
          "res_prop" => %Seraph.Query.Builder.Entity.Property{
            alias: :res_prop,
            bound_name: nil,
            entity_identifier: "u",
            entity_queryable: Seraph.Test.User,
            name: :uuid,
            type: nil,
            value: nil
          }
        }
      }

      assert return == query.operations[:return]
      assert [] == query.params
    end

    test "ok: function" do
      query =
        match([{u, User}])
        |> return(firstNames: collect(u.firstName))
        |> prepare([])

      return = %Seraph.Query.Builder.Return{
        distinct?: false,
        raw_variables: nil,
        variables: %{
          "firstNames" => %Seraph.Query.Builder.Entity.Function{
            alias: :firstNames,
            args: [
              %Seraph.Query.Builder.Entity.Property{
                alias: nil,
                bound_name: nil,
                entity_identifier: "u",
                entity_queryable: Seraph.Test.User,
                name: :firstName,
                type: nil,
                value: nil
              }
            ],
            name: :collect
          }
        }
      }

      assert return == query.operations[:return]
      assert [] == query.params
    end

    test "ok: function in function" do
      query =
        match([{u, User}])
        |> return(firstNames: size(collect(u.firstName)))
        |> prepare([])

      return = %Seraph.Query.Builder.Return{
        distinct?: false,
        raw_variables: nil,
        variables: %{
          "firstNames" => %Seraph.Query.Builder.Entity.Function{
            alias: :firstNames,
            args: [
              %Seraph.Query.Builder.Entity.Function{
                alias: nil,
                args: [
                  %Seraph.Query.Builder.Entity.Property{
                    alias: nil,
                    bound_name: nil,
                    entity_identifier: "u",
                    entity_queryable: Seraph.Test.User,
                    name: :firstName,
                    type: nil,
                    value: nil
                  }
                ],
                name: :collect
              }
            ],
            name: :size
          }
        }
      }

      assert return == query.operations[:return]
      assert [] == query.params
    end

    test "ok: value" do
      query =
        match([{u, User}])
        |> return(num: 1)
        |> prepare([])

      return = %Seraph.Query.Builder.Return{
        distinct?: false,
        raw_variables: nil,
        variables: %{
          "num" => %Seraph.Query.Builder.Entity.Value{
            alias: :num,
            bound_name: "return__0",
            value: nil
          }
        }
      }

      assert return == query.operations[:return]
      assert [return__0: 1] == query.params
    end

    test "raise: aliases inner function" do
      assert_raise ArgumentError, fn ->
        defmodule WillFail do
          import Seraph.Query

          match([{u, User}])
          |> return(firstNames: size(invalid_alias: collect(u.firstName)))
          |> prepare([])
        end
      end
    end
  end

  describe "create" do
    test "ok: create one node" do
      query = create([{User, %{firstName: "Aron"}}])

      node_data = %Seraph.Query.Builder.Entity.Node{
        alias: nil,
        identifier: nil,
        labels: ["User"],
        properties: [
          %Seraph.Query.Builder.Entity.Property{
            alias: nil,
            bound_name: "create__prop__firstName_0",
            entity_identifier: nil,
            entity_queryable: Seraph.Test.User,
            name: :firstName,
            type: nil,
            value: nil
          }
        ],
        queryable: Seraph.Test.User
      }

      assert %{} == query.identifiers
      assert %Builder.Create{raw_entities: [^node_data]} = query.operations[:create]
      assert [create__prop__firstName_0: "Aron"] == query.params
    end

    test "ok: create one relationship" do
      query = create([[{u}, [rel, Wrote], {v}]])

      start_data = %Seraph.Query.Builder.Entity.Node{
        alias: nil,
        identifier: "u",
        labels: [],
        properties: [],
        queryable: Seraph.Node
      }

      end_data = %Seraph.Query.Builder.Entity.Node{
        alias: nil,
        identifier: "v",
        labels: [],
        properties: [],
        queryable: Seraph.Node
      }

      rel_data = %Seraph.Query.Builder.Entity.Relationship{
        alias: nil,
        end: end_data,
        identifier: "rel",
        properties: [],
        queryable: Seraph.Test.UserToPost.Wrote,
        start: start_data,
        type: "WROTE"
      }

      assert %{"rel" => ^rel_data, "u" => ^start_data, "v" => ^end_data} = query.identifiers
      assert map_size(query.identifiers) == 3
      assert %Builder.Create{raw_entities: [^rel_data]} = query.operations[:create]
      assert [] == query.params
    end
  end

  describe "set" do
  end

  describe "prepare/2" do
    test "match node fail: invalid property" do
      assert_raise Seraph.QueryError, fn ->
        defmodule WillFail do
          import Seraph.Query

          match([{u, User, %{firstName: "ok", invalid: 5}}])
          |> prepare([])
        end
      end
    end

    test "match node fail: invalid property type" do
      assert_raise Seraph.QueryError, fn ->
        defmodule WillFail do
          import Seraph.Query

          match([{u, User, %{uuid: :invalid}}])
          |> prepare([])
        end
      end
    end

    test "match relationship fail: invalid property" do
      assert_raise Seraph.QueryError, fn ->
        defmodule WillFail do
          import Seraph.Query

          match([[{}, [Wrote, %{invalid: 5}], {}]])
          |> prepare([])
        end
      end
    end

    test "match relationship fail: invalid property type" do
      assert_raise Seraph.QueryError, fn ->
        defmodule WillFail do
          import Seraph.Query

          match([[{}, [Wrote, %{at: 5}], {}]])
          |> prepare([])
        end
      end
    end

    test "where raise: unknwon property on entity" do
      assert_raise Seraph.QueryError, fn ->
        defmodule Willfail do
          match([{u, User}])
          |> where(u.invalid == "5")
          |> prepare([])
        end
      end
    end

    test "where raise: invalid property type" do
      assert_raise Seraph.QueryError, fn ->
        defmodule Willfail do
          match([{u, User}])
          |> where(u.uuid == 5)
          |> prepare([])
        end
      end
    end

    test "where raise: unknown identifier" do
      assert_raise Seraph.QueryError, fn ->
        defmodule Willfail do
          match([{u, User}])
          |> where(p.uuid == "5")
          |> prepare([])
        end
      end
    end

    test "create node fail: invalid property" do
      assert_raise Seraph.QueryError, fn ->
        defmodule WillFail do
          import Seraph.Query

          create([{u, User, %{firstName: "ok", invalid: 5}}])
          |> prepare([])
        end
      end
    end

    test "create node fail: invalid property type" do
      assert_raise Seraph.QueryError, fn ->
        defmodule WillFail do
          import Seraph.Query

          create([{u, User, %{uuid: :invalid}}])
          |> prepare([])
        end
      end
    end

    test "merge node fail: invalid property" do
      assert_raise Seraph.QueryError, fn ->
        defmodule WillFail do
          import Seraph.Query

          merge({u, User, %{firstName: "ok", invalid: 5}})
          |> prepare([])
        end
      end
    end

    test "merge node fail: invalid property type" do
      assert_raise Seraph.QueryError, fn ->
        defmodule WillFail do
          import Seraph.Query

          merge({u, User, %{uuid: :invalid}})
          |> prepare([])
        end
      end
    end

    test "set raise: unknown identifier" do
      assert_raise Seraph.QueryError, fn ->
        defmodule Willfail do
          match([{u, User}])
          |> set([p.uuid = 5])
          |> prepare([])
        end
      end
    end

    test "set raise: invalid property" do
      assert_raise Seraph.QueryError, fn ->
        defmodule Willfail do
          match([{u, User}])
          |> set([u.unknown = 5])
          |> prepare([])
        end
      end
    end

    test "set raise: invalid property type" do
      assert_raise Seraph.QueryError, fn ->
        defmodule Willfail do
          match([{u, User}])
          |> set([u.uuid = 5])
          |> prepare([])
        end
      end
    end

    test "set raise: unknown identifierin function" do
      assert_raise Seraph.QueryError, fn ->
        defmodule Willfail do
          match([{u, User}])
          |> set([u.uuid = p.uuid + 2])
          |> prepare([])
        end
      end
    end

    test "set raise: invalid property in function" do
      assert_raise Seraph.QueryError, fn ->
        defmodule Willfail do
          match([{u, User}])
          |> set([u.uuid = u.unknwon + 4])
          |> prepare([])
        end
      end
    end

    test "return raise: unknown identifier" do
      assert_raise Seraph.QueryError, fn ->
        defmodule Willfail do
          match([{u, User}])
          |> return([p])
          |> prepare([])
        end
      end
    end

    test "return raise: unknwon property on entity" do
      assert_raise Seraph.QueryError, fn ->
        defmodule Willfail do
          match([{u, User}])
          |> return([u.invalid])
          |> prepare([])
        end
      end
    end

    test "return raise: unaliased value" do
      assert_raise Seraph.QueryError, fn ->
        defmodule Willfail do
          match([{u, User}])
          |> return([5])
          |> prepare([])
        end
      end
    end

    test "return raise: unaliased function" do
      assert_raise Seraph.QueryError, fn ->
        defmodule Willfail do
          match([{u, User}])
          |> return([collect(u.firstName)])
          |> prepare([])
        end
      end
    end

    test "match then create: ok with replaced identifiers" do
      query =
        match([{u, User, %{firstName: "John"}}])
        |> create([[{u}, [rel, Wrote], {p, Post, %{uuid: "new-uuid"}}]])
        |> prepare([])

      start_data = %Seraph.Query.Builder.Entity.Node{
        alias: nil,
        identifier: "u",
        labels: ["User"],
        properties: [
          %Seraph.Query.Builder.Entity.Property{
            alias: nil,
            bound_name: "u_firstName_0",
            entity_identifier: "u",
            entity_queryable: Seraph.Test.User,
            name: :firstName,
            type: nil,
            value: nil
          }
        ],
        queryable: Seraph.Test.User
      }

      end_data = %Seraph.Query.Builder.Entity.Node{
        alias: nil,
        identifier: "p",
        labels: ["Post"],
        properties: [
          %Seraph.Query.Builder.Entity.Property{
            alias: nil,
            bound_name: "p_uuid_0",
            entity_identifier: "p",
            entity_queryable: Seraph.Test.Post,
            name: :uuid,
            type: nil,
            value: nil
          }
        ],
        queryable: Seraph.Test.Post
      }

      rel_data = %Seraph.Query.Builder.Entity.Relationship{
        alias: nil,
        end: end_data,
        identifier: "rel",
        properties: [],
        queryable: Seraph.Test.UserToPost.Wrote,
        start: start_data,
        type: "WROTE"
      }

      assert %{"rel" => ^rel_data, "u" => ^start_data, "p" => ^end_data} = query.identifiers
      assert map_size(query.identifiers) == 3
      assert %Builder.Create{entities: [^rel_data]} = query.operations[:create]
      assert [u_firstName_0: "John", p_uuid_0: "new-uuid"] == query.params
    end

    test "post_check: fails when identifier is not set at creation (match + create / create)" do
      assert_raise Seraph.QueryError, fn ->
        defmodule WillFail do
          import Seraph.Query

          match([{u, User, %{firstName: "John"}}])
          |> create([[{u}, [rel, Wrote], {p, Post}]])
          |> set([p.title = "Wow post"])
          |> prepare([])
        end
      end

      assert_raise Seraph.QueryError, fn ->
        defmodule WillFail do
          import Seraph.Query

          create([{u, User}])
          |> prepare([])
        end
      end
    end

    test "post_check: fails when identifier is changed at merge (match + set)" do
      assert_raise Seraph.QueryError, fn ->
        defmodule WillFail do
          import Seraph.Query

          match([{u, User, %{firstName: "John"}}])
          |> set([u.uuid = "invalid"])
          |> prepare([])
        end
      end
    end

    test "post_check: fails when merge_keys is changed at merge (merge)" do
      assert_raise Seraph.QueryError, fn ->
        defmodule WillFail1 do
          import Seraph.Query

          match([{mk, MergeKeys, %{uuid: "uuid-1"}}])
          |> set([mk.mkField1 = "not allowed"])
          |> prepare([])
        end
      end

      # assert_raise Seraph.QueryError, fn ->
      #   defmodule WillFail2 do
      #     import Seraph.Query

      #     merge({mk, MergeKeys, %{uuid: "uuid-1"}})
      #     |> set([mk.mkField1 = "not allowed"])
      #     |> prepare([])
      #   end
      # end

      assert_raise Seraph.QueryError, fn ->
        defmodule WillFail3 do
          import Seraph.Query

          merge({mk, MergeKeys, %{uuid: "uuid-1"}})
          |> on_match_set([mk.mkField1 = "not allowed"])
          |> prepare([])
        end
      end
    end
  end

  describe "operations order" do
    test "ok: match as entry point" do
      assert %Seraph.Query{} = match([{u}])
    end

    test "ok: match as follow-up operation" do
      assert %Seraph.Query{} =
               create([[{u, User}, [Wrote], {p, Post}]])
               |> match([{u}])
    end

    test "ok: create as entry point" do
      assert %Seraph.Query{} = create([[{u, User}, [Wrote], {p, Post}]])
    end

    test "ok: create as follow-up operation" do
      assert %Seraph.Query{} =
               match([{u, User}])
               |> create([[{u}, [Wrote], {p, Post}]])
    end

    test "ok: where as follow-up operation" do
      assert %Seraph.Query{} =
               match([{u}])
               |> where(u.uuid == "uuid-3")
    end

    test "ok: return as follow-up operation" do
      assert %Seraph.Query{} =
               match([{u}])
               |> where(u.uuid == "uuid-3")
               |> return([u])
    end

    test "ok: set as follow-up operation" do
      assert %Seraph.Query{} =
               create([[{u}, [Wrote], {p, Post}]])
               |> set([u.firstName = "Hello"])
    end

    test "fail: where as entry point" do
      assert_raise CompileError, fn ->
        defmodule WillFail do
          import Seraph.Query

          where(u.uuid == "uuid-3")
        end
      end
    end

    test "fail: return as entry point" do
      assert_raise CompileError, fn ->
        defmodule Willfail do
          import Seraph.Query

          return([u])
        end
      end
    end

    test "fail: set as entry point" do
      assert_raise CompileError, fn ->
        defmodule Willfail do
          import Seraph.Query

          set([u.firstName = "John"])
        end
      end
    end
  end
end
