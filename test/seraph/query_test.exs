defmodule Seraph.QueryTest do
  use ExUnit.Case, async: true
  alias Seraph.TestRepo
  alias Seraph.Test.User
  alias Seraph.Test.Post
  alias Seraph.Test.UserToPost.Wrote

  import Seraph.Query
  alias Seraph.Query.Builder

  test "exploration" do
    # n(u in User)

    uuid = "uuid-3"
    at2 = DateTime.utc_now() |> DateTime.truncate(:second)
    at = DateTime.utc_now() |> DateTime.truncate(:second)
    f_name = "John"

    # query =
    #   match([
    #     {v},
    #     {Seraph.Test.User},
    #     {p, Post},
    #     {u, User, %{uuid: "azeazrazr-23234234"}},
    #     [{u}, [rel], {v}],
    #     [{u}, [Wrote], {w}],
    #     [{u}, [rel2, Wrote], {v}],
    #     # [{User}, [rel3, Wrote, %{at: 5}], {Post}],
    #     [{User}, [rel3, Wrote, %{at: ^at2}], {Post}],
    #     [{u2, User}, [rel4, Wrote, %{at: ^at}], {p2, Post}],
    #     [{u3, User, %{firstName: ^f_name}}, [rel5, Wrote], {p3, Post}]

    #     # node_(u),
    #     # node_(User),
    #     # node_(u, User),
    #     # node_(v, User, %{uuid: "uuid-1", value: 3}),
    #     # rel_(u, Wrote, v),
    #     # rel_(node_(User), Wrote, node_(Post))
    #     # rel_(node_(User), [rel, Wrote], node_(Post))
    #     # rel_(node_(User), [rel, Wrote, %{uuid: "uuid-1", value: 3}], node_(Post))
    #   ])
    #   |> where(u.uuid == ^uuid and p.uuid == 6)
    #   |> return([u, u2.uuid])

    # IO.puts("<<<<<<<<<<<<<<<<<<<<<<<<<<<< 1ST QUERY END")

    # # |> IO.inspect(label: "QUERY")

    # # |> IO.inspect()

    # query =
    #   match([[{u}, [rel, Wrote], {p, Post}]])
    #   |> return([u, rel, p, u.uuid])

    # query =
    #   match([[{u}, [rel, Wrote], {p, Post}]],
    #     where: u.firstName == "John",
    #     return: [u, rel, p, u.uuid]
    #   )
    #   |> IO.inspect(label: "DSL")

    # return_fields = Keyword.get(query.operations, :return)

    # {statement, params} =
    #   Builder.new()
    #   # |> Builder.match(query.match)
    #   # |> Builder.where(query.where)
    #   # |> Builder.return(%Builder.ReturnExpr{fields: query.return})
    #   |> Builder.match(Keyword.get(query.operations, :match))
    #   |> Builder.where(Keyword.get(query.operations, :where))
    #   # |> Builder.return(%Builder.ReturnExpr{fields: return_fields})
    #   |> Builder.return(Keyword.get(query.operations, :return))
    #   |> Builder.params(Enum.into(query.params, %{}))
    #   |> Builder.to_string()

    # # IO.puts(statement)
    # # IO.inspect(params)

    # IO.puts(">>>>>>>>>>>>>>>>>>>")
    # IO.inspect(query.operations)
    # # IO.inspect(query)

    # # IO.puts(">>>>>>>>>>>>>>>>>>>")

    # # query.operations
    # # |> Enum.reverse()
    # # |> Enum.map(&Seraph.Query.Stringifier.stringify/1)
    # # |> Enum.reject(&is_nil/1)
    # # |> Enum.join("\n")
    # # |> IO.puts()

    # TestRepo.all(query)
    # |> IO.inspect()

    # query.literal
    # |> Enum.join("\n")
    # |> IO.puts()

    # |> where(p.uuid == ^uuid and (not is_nil(u2.firstName) or not is_nil(u.firstName)))

    # |> IO.inspect()
  end

  # describe "DSL + PIPED" do
  #   test "piped" do
  #     IO.puts("PIPED SYNTAX -------------------------------------------")

  #     uuid = "uuid-3"
  #     # uuid = 3
  #     uuid2 = "uuid-unkown"

  #     query =
  #       match([[{u}, [rel, Wrote], {p, Post, %{uuid: ^uuid, title: "John"}}]])
  #       |> where(u.firstName == "John" and u.uuid == ^uuid2)
  #       # |> return([[fnode: u], rel, p, u.uuid])
  #       |> IO.inspect(label: "PIPED RESULT")
  #   end

  #   test "dsl" do
  #     IO.puts("DSL SYNTAX -------------------------------------------")
  #     uuid = "uuid-3"
  #     uuid2 = "uuid-unkown"

  #     query =
  #       match [[{u}, [rel, Wrote], {p, Post, %{uuid: ^uuid}}]],
  #         where: u.firstName == "John" and u.uuid == ^uuid2,
  #         return: [u, rel, p, u.uuid]

  #     # Repo.all(query)

  #     IO.inspect(query, label: "DSL RESULT")
  #   end
  # end

  describe "match node" do
    test "ok: {u}" do
      assert %Seraph.Query{
               aliases: [
                 v:
                   {nil,
                    %Seraph.Query.Builder.NodeExpr{
                      alias: nil,
                      index: nil,
                      labels: nil,
                      properties: %{},
                      variable: "v"
                    }}
               ],
               literal: ["match:\n\t{v}"],
               operations: [
                 match: [
                   %Seraph.Query.Builder.NodeExpr{
                     alias: nil,
                     index: nil,
                     labels: nil,
                     properties: %{},
                     variable: "v"
                   }
                 ]
               ],
               params: []
             } = match([{v}])
    end

    test "ok: {u, User}" do
      assert %Seraph.Query{
               aliases: [
                 u:
                   {Seraph.Test.User,
                    %Seraph.Query.Builder.NodeExpr{
                      alias: nil,
                      index: nil,
                      labels: ["User"],
                      properties: %{},
                      variable: "u"
                    }}
               ],
               literal: ["match:\n\t{u, User}"],
               operations: [
                 match: [
                   %Seraph.Query.Builder.NodeExpr{
                     alias: nil,
                     index: nil,
                     labels: ["User"],
                     properties: %{},
                     variable: "u"
                   }
                 ]
               ],
               params: []
             } = match([{u, User}])
    end

    test "ok: {u, Seraph.Test.User}" do
      assert %Seraph.Query{
               aliases: [
                 u:
                   {Seraph.Test.User,
                    %Seraph.Query.Builder.NodeExpr{
                      alias: nil,
                      index: nil,
                      labels: ["User"],
                      properties: %{},
                      variable: "u"
                    }}
               ],
               literal: ["match:\n\t{u, Seraph.Test.User}"],
               operations: [
                 match: [
                   %Seraph.Query.Builder.NodeExpr{
                     alias: nil,
                     index: nil,
                     labels: ["User"],
                     properties: %{},
                     variable: "u"
                   }
                 ]
               ]
             } = match([{u, Seraph.Test.User}])
    end

    test "ok: {u, User, %{uuid: \"uuid-2\"}}" do
      assert %Seraph.Query{
               aliases: [
                 u:
                   {Seraph.Test.User,
                    %Seraph.Query.Builder.NodeExpr{
                      alias: nil,
                      index: nil,
                      labels: ["User"],
                      properties: %{uuid: "u_uuid"},
                      variable: "u"
                    }}
               ],
               literal: ["match:\n\t{u, User, %{uuid: \"uuid-2\"}}"],
               operations: [
                 match: [
                   %Seraph.Query.Builder.NodeExpr{
                     alias: nil,
                     index: nil,
                     labels: ["User"],
                     properties: %{uuid: "u_uuid"},
                     variable: "u"
                   }
                 ]
               ],
               params: [u_uuid: "uuid-2"]
             } = match([{u, User, %{uuid: "uuid-2"}}])
    end

    test "ok: {u, User, %{uuid: ^user_uuid}}" do
      user_uuid = "uuid-3"

      assert %Seraph.Query{
               aliases: [
                 u:
                   {Seraph.Test.User,
                    %Seraph.Query.Builder.NodeExpr{
                      alias: nil,
                      index: nil,
                      labels: ["User"],
                      properties: %{uuid: "u_uuid"},
                      variable: "u"
                    }}
               ],
               literal: ["match:\n\t{u, User, %{uuid: ^user_uuid}}"],
               operations: [
                 match: [
                   %Seraph.Query.Builder.NodeExpr{
                     alias: nil,
                     index: nil,
                     labels: ["User"],
                     properties: %{uuid: "u_uuid"},
                     variable: "u"
                   }
                 ]
               ],
               params: [u_uuid: "uuid-3"]
             } = match([{u, User, %{uuid: ^user_uuid}}])
    end

    test "ok: {u, %{uuid: ^user_uuid}}" do
      user_uuid = "uuid-3"

      assert %Seraph.Query{
               aliases: [
                 u:
                   {nil,
                    %Seraph.Query.Builder.NodeExpr{
                      alias: nil,
                      index: nil,
                      labels: nil,
                      properties: %{uuid: "u_uuid"},
                      variable: "u"
                    }}
               ],
               literal: ["match:\n\t{u, %{uuid: ^user_uuid}}"],
               operations: [
                 match: [
                   %Seraph.Query.Builder.NodeExpr{
                     alias: nil,
                     index: nil,
                     labels: nil,
                     properties: %{uuid: "u_uuid"},
                     variable: "u"
                   }
                 ]
               ],
               params: [u_uuid: "uuid-3"]
             } = match([{u, %{uuid: ^user_uuid}}])
    end

    test "fail: empty node {}" do
      assert_raise ArgumentError, fn ->
        defmodule EmptyNode do
          import Seraph.Query
          match([{}])
        end
      end
    end

    test "fail: already used alias" do
      assert_raise ArgumentError, fn ->
        defmodule EmptyNode do
          import Seraph.Query
          match([{u, User}, {u, Post}])
        end
      end
    end

    test "fail: unknown queryable" do
      assert_raise UndefinedFunctionError, fn ->
        defmodule EmptyNode do
          import Seraph.Query
          match([{u, Unknown}])
        end
      end
    end

    test "fail: unknown pinned variable" do
      assert_raise CompileError, fn ->
        defmodule EmptyNode do
          import Seraph.Query
          match([{u, User, %{uuid: ^uuid}}])
        end
      end
    end

    test "fail: invalid property" do
      assert_raise Seraph.QueryError, fn ->
        defmodule EmptyNode do
          import Seraph.Query
          match([{u, User, %{invalid: 5}}])
        end
      end
    end

    test "fail: invalid property type" do
      assert_raise Seraph.QueryError, fn ->
        defmodule EmptyNode do
          import Seraph.Query
          match([{u, User, %{uuid: :invalid}}])
        end
      end
    end
  end

  describe "match relationship" do
    test "ok: [{u}, [rel], {v}]" do
      assert %Seraph.Query{
               aliases: [
                 rel:
                   {nil,
                    %Seraph.Query.Builder.RelationshipExpr{
                      alias: nil,
                      end: %Seraph.Query.Builder.NodeExpr{},
                      index: nil,
                      properties: %{},
                      start: %Seraph.Query.Builder.NodeExpr{},
                      type: nil,
                      variable: "rel"
                    }},
                 v: {nil, %Seraph.Query.Builder.NodeExpr{}},
                 u: {nil, %Seraph.Query.Builder.NodeExpr{}}
               ],
               literal: ["match:\n\t[{u}, [rel], {v}]"],
               operations: [
                 match: [
                   %Seraph.Query.Builder.RelationshipExpr{
                     alias: nil,
                     end: %Seraph.Query.Builder.NodeExpr{},
                     index: nil,
                     properties: %{},
                     start: %Seraph.Query.Builder.NodeExpr{},
                     type: nil,
                     variable: "rel"
                   }
                 ]
               ],
               params: []
             } = match([[{u}, [rel], {v}]])
    end

    test "ok: [{u}, [Wrote], {v}]" do
      assert %Seraph.Query{
               aliases: [
                 v: {Seraph.Test.Post, %Seraph.Query.Builder.NodeExpr{}},
                 u: {Seraph.Test.User, %Seraph.Query.Builder.NodeExpr{}}
               ],
               literal: ["match:\n\t[{u}, [Wrote], {v}]"],
               operations: [
                 match: [
                   %Seraph.Query.Builder.RelationshipExpr{
                     alias: nil,
                     end: %Seraph.Query.Builder.NodeExpr{},
                     index: nil,
                     properties: %{},
                     start: %Seraph.Query.Builder.NodeExpr{},
                     type: "WROTE",
                     variable: nil
                   }
                 ]
               ],
               params: []
             } = match([[{u}, [Wrote], {v}]])
    end

    test "ok: [{u}, [rel, Wrote], {v}]" do
      assert %Seraph.Query{
               aliases: [
                 rel:
                   {Seraph.Test.UserToPost.Wrote,
                    %Seraph.Query.Builder.RelationshipExpr{
                      alias: nil,
                      end: %Seraph.Query.Builder.NodeExpr{},
                      index: nil,
                      properties: %{},
                      start: %Seraph.Query.Builder.NodeExpr{},
                      type: "WROTE",
                      variable: "rel"
                    }},
                 v: {Seraph.Test.Post, %Seraph.Query.Builder.NodeExpr{}},
                 u: {Seraph.Test.User, %Seraph.Query.Builder.NodeExpr{}}
               ],
               literal: ["match:\n\t[{u}, [rel, Wrote], {v}]"],
               operations: [
                 match: [
                   %Seraph.Query.Builder.RelationshipExpr{
                     alias: nil,
                     end: %Seraph.Query.Builder.NodeExpr{
                       labels: ["Post"]
                     },
                     index: nil,
                     properties: %{},
                     start: %Seraph.Query.Builder.NodeExpr{
                       labels: ["User"]
                     },
                     type: "WROTE",
                     variable: "rel"
                   }
                 ]
               ],
               params: []
             } = match([[{u}, [rel, Wrote], {v}]])
    end

    test "ok: [{u}, [rel, Wrote, %{at: \"2020-05-04\"}], {v}]" do
      assert %Seraph.Query{
               aliases: [
                 rel:
                   {Seraph.Test.UserToPost.Wrote,
                    %Seraph.Query.Builder.RelationshipExpr{
                      alias: nil,
                      end: %Seraph.Query.Builder.NodeExpr{},
                      index: nil,
                      properties: %{at: "rel_at"},
                      start: %Seraph.Query.Builder.NodeExpr{},
                      type: "WROTE",
                      variable: "rel"
                    }},
                 v: {Seraph.Test.Post, %Seraph.Query.Builder.NodeExpr{}},
                 u: {Seraph.Test.User, %Seraph.Query.Builder.NodeExpr{}}
               ],
               literal: [
                 "match:\n\t[{u}, [rel, Wrote, %{at: DateTime.from_naive!(~N\"2016-05-24 13:26:08\", \"Etc/UTC\")}], {v}]"
               ],
               operations: [
                 match: [
                   %Seraph.Query.Builder.RelationshipExpr{
                     alias: nil,
                     end: %Seraph.Query.Builder.NodeExpr{},
                     index: nil,
                     properties: %{at: "rel_at"},
                     start: %Seraph.Query.Builder.NodeExpr{},
                     type: "WROTE",
                     variable: "rel"
                   }
                 ]
               ],
               params: [rel_at: _]
             } =
               match([
                 [
                   {u},
                   [rel, Wrote, %{at: DateTime.from_naive!(~N[2016-05-24 13:26:08], "Etc/UTC")}],
                   {v}
                 ]
               ])
    end

    test "ok: [{u}, [rel, Wrote, %{at: ^date}], {v}]" do
      date = DateTime.from_naive!(~N[2016-05-24 13:26:08], "Etc/UTC")

      assert %Seraph.Query{
               aliases: [
                 rel:
                   {Seraph.Test.UserToPost.Wrote,
                    %Seraph.Query.Builder.RelationshipExpr{
                      alias: nil,
                      end: %Seraph.Query.Builder.NodeExpr{},
                      index: nil,
                      properties: %{at: "rel_at"},
                      start: %Seraph.Query.Builder.NodeExpr{},
                      type: "WROTE",
                      variable: "rel"
                    }},
                 v: {Seraph.Test.Post, %Seraph.Query.Builder.NodeExpr{}},
                 u: {Seraph.Test.User, %Seraph.Query.Builder.NodeExpr{}}
               ],
               literal: ["match:\n\t[{u}, [rel, Wrote, %{at: ^date}], {v}]"],
               operations: [
                 match: [
                   %Seraph.Query.Builder.RelationshipExpr{
                     alias: nil,
                     end: %Seraph.Query.Builder.NodeExpr{},
                     index: nil,
                     properties: %{at: "rel_at"},
                     start: %Seraph.Query.Builder.NodeExpr{},
                     type: "WROTE",
                     variable: "rel"
                   }
                 ]
               ],
               params: [rel_at: _]
             } = match([[{u}, [rel, Wrote, %{at: ^date}], {v}]])
    end

    test "ok: [{u}, [rel, %{at: ^date}], {v}]" do
      date = DateTime.from_naive!(~N[2016-05-24 13:26:08], "Etc/UTC")

      assert %Seraph.Query{
               aliases: [
                 rel:
                   {nil,
                    %Seraph.Query.Builder.RelationshipExpr{
                      alias: nil,
                      end: %Seraph.Query.Builder.NodeExpr{},
                      index: nil,
                      properties: %{at: "rel_at"},
                      start: %Seraph.Query.Builder.NodeExpr{},
                      type: nil,
                      variable: "rel"
                    }},
                 v: {nil, %Seraph.Query.Builder.NodeExpr{}},
                 u: {nil, %Seraph.Query.Builder.NodeExpr{}}
               ],
               literal: ["match:\n\t[{u}, [rel, %{at: ^date}], {v}]"],
               operations: [
                 match: [
                   %Seraph.Query.Builder.RelationshipExpr{
                     alias: nil,
                     end: %Seraph.Query.Builder.NodeExpr{},
                     index: nil,
                     properties: %{at: "rel_at"},
                     start: %Seraph.Query.Builder.NodeExpr{},
                     type: nil,
                     variable: "rel"
                   }
                 ]
               ],
               params: [rel_at: _]
             } = match([[{u}, [rel, %{at: ^date}], {v}]])
    end

    test "ok: [{}, [rel], {p}]" do
      assert %Seraph.Query{
               aliases: [
                 rel:
                   {nil,
                    %Seraph.Query.Builder.RelationshipExpr{
                      alias: nil,
                      end: %Seraph.Query.Builder.NodeExpr{},
                      index: nil,
                      properties: %{},
                      start: %Seraph.Query.Builder.NodeExpr{
                        alias: nil,
                        index: nil,
                        labels: nil,
                        properties: %{},
                        variable: nil
                      },
                      type: nil,
                      variable: "rel"
                    }},
                 p: {nil, %Seraph.Query.Builder.NodeExpr{}}
               ],
               literal: ["match:\n\t[{}, [rel], {p}]"],
               operations: [
                 match: [
                   %Seraph.Query.Builder.RelationshipExpr{
                     alias: nil,
                     end: %Seraph.Query.Builder.NodeExpr{},
                     index: nil,
                     properties: %{},
                     start: %Seraph.Query.Builder.NodeExpr{
                       alias: nil,
                       index: nil,
                       labels: nil,
                       properties: %{},
                       variable: nil
                     },
                     type: nil,
                     variable: "rel"
                   }
                 ]
               ],
               params: []
             } = match([[{}, [rel], {p}]])
    end

    test "ok: [{u}, [], {p}]" do
      assert %Seraph.Query{
               aliases: [
                 p:
                   {nil,
                    %Seraph.Query.Builder.NodeExpr{
                      alias: nil,
                      index: nil,
                      labels: nil,
                      properties: %{},
                      variable: "p"
                    }},
                 u:
                   {nil,
                    %Seraph.Query.Builder.NodeExpr{
                      alias: nil,
                      index: nil,
                      labels: nil,
                      properties: %{},
                      variable: "u"
                    }}
               ],
               literal: ["match:\n\t[{u}, [], {p}]"],
               operations: [
                 match: [
                   %Seraph.Query.Builder.RelationshipExpr{
                     alias: nil,
                     end: %Seraph.Query.Builder.NodeExpr{
                       alias: nil,
                       index: nil,
                       labels: nil,
                       properties: %{},
                       variable: "p"
                     },
                     index: nil,
                     properties: %{},
                     start: %Seraph.Query.Builder.NodeExpr{
                       alias: nil,
                       index: nil,
                       labels: nil,
                       properties: %{},
                       variable: "u"
                     },
                     type: nil,
                     variable: nil
                   }
                 ]
               ],
               params: []
             } = match([[{u}, [], {p}]])
    end

    test "ok: [{u}, [rel], {p, Post}]" do
      assert %Seraph.Query{
               aliases: [
                 rel:
                   {nil,
                    %Seraph.Query.Builder.RelationshipExpr{
                      alias: nil,
                      end: %Seraph.Query.Builder.NodeExpr{},
                      index: nil,
                      properties: %{},
                      start: %Seraph.Query.Builder.NodeExpr{},
                      type: nil,
                      variable: "rel"
                    }},
                 p: {Seraph.Test.Post, %Seraph.Query.Builder.NodeExpr{}},
                 u: {nil, %Seraph.Query.Builder.NodeExpr{}}
               ],
               literal: ["match:\n\t[{u}, [rel], {p, Post}]"],
               operations: [
                 match: [
                   %Seraph.Query.Builder.RelationshipExpr{
                     alias: nil,
                     end: %Seraph.Query.Builder.NodeExpr{},
                     index: nil,
                     properties: %{},
                     start: %Seraph.Query.Builder.NodeExpr{},
                     type: nil,
                     variable: "rel"
                   }
                 ]
               ],
               params: []
             } = match([[{u}, [rel], {p, Post}]])
    end

    test "ok: [{u, User}, [rel], {p, Post}]" do
      assert %Seraph.Query{
               aliases: [
                 rel:
                   {nil,
                    %Seraph.Query.Builder.RelationshipExpr{
                      alias: nil,
                      end: %Seraph.Query.Builder.NodeExpr{},
                      index: nil,
                      properties: %{},
                      start: %Seraph.Query.Builder.NodeExpr{},
                      type: nil,
                      variable: "rel"
                    }},
                 p: {Seraph.Test.Post, %Seraph.Query.Builder.NodeExpr{}},
                 u: {Seraph.Test.User, %Seraph.Query.Builder.NodeExpr{}}
               ],
               literal: ["match:\n\t[{u, User}, [rel], {p, Post}]"],
               operations: [
                 match: [
                   %Seraph.Query.Builder.RelationshipExpr{
                     alias: nil,
                     end: %Seraph.Query.Builder.NodeExpr{},
                     index: nil,
                     properties: %{},
                     start: %Seraph.Query.Builder.NodeExpr{},
                     type: nil,
                     variable: "rel"
                   }
                 ]
               ],
               params: []
             } = match([[{u, User}, [rel], {p, Post}]])
    end

    test "ok: [{u, User, %{firtName: \"John\"}}, [rel], {p, Post}]" do
      assert %Seraph.Query{
               aliases: [
                 rel:
                   {nil,
                    %Seraph.Query.Builder.RelationshipExpr{
                      alias: nil,
                      end: %Seraph.Query.Builder.NodeExpr{},
                      index: nil,
                      properties: %{},
                      start: %Seraph.Query.Builder.NodeExpr{},
                      type: nil,
                      variable: "rel"
                    }},
                 p: {Seraph.Test.Post, %Seraph.Query.Builder.NodeExpr{}},
                 u:
                   {Seraph.Test.User,
                    %Seraph.Query.Builder.NodeExpr{properties: %{firstName: "u_firstName"}}}
               ],
               literal: ["match:\n\t[{u, User, %{firstName: \"John\"}}, [rel], {p, Post}]"],
               operations: [
                 match: [
                   %Seraph.Query.Builder.RelationshipExpr{
                     alias: nil,
                     end: %Seraph.Query.Builder.NodeExpr{},
                     index: nil,
                     properties: %{},
                     start: %Seraph.Query.Builder.NodeExpr{
                       properties: %{firstName: "u_firstName"}
                     },
                     type: nil,
                     variable: "rel"
                   }
                 ]
               ],
               params: [u_firstName: "John"]
             } = match([[{u, User, %{firstName: "John"}}, [rel], {p, Post}]])
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
      assert_raise ArgumentError, fn ->
        defmodule WillFail do
          import Seraph.Query
          match([{rel}, [{}, [rel], {}]])
        end
      end
    end

    test "fail: already used alias (node)" do
      match([{n}, [{n}, [rel], {}]])
      match([{n, User}, [{n}, [rel], {}]])

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

    test "fail: invalid property" do
      assert_raise Seraph.QueryError, fn ->
        defmodule WillFail do
          import Seraph.Query
          match([[{n, Post}, [rel, Wrote, %{unknown: 4}], {}]])
        end
      end
    end

    test "fail: invalid property type" do
      assert_raise Seraph.QueryError, fn ->
        defmodule WillFail do
          import Seraph.Query
          match([[{n, Post}, [rel, Wrote, %{at: 4}], {}]])
        end
      end
    end
  end

  describe "where" do
    test "ok: operator :and" do
      assert %Seraph.Query{operations: operations, params: [param_1: "John", param_0: "uuid-1"]} =
               match([{u, User}])
               |> where(u.uuid == "uuid-1" and u.firstName == "John")

      assert %Seraph.Query.Condition{
               conditions: [
                 %Seraph.Query.Condition{
                   conditions: nil,
                   field: :uuid,
                   join_operator: :and,
                   operator: :==,
                   source: "u",
                   value: "param_0"
                 },
                 %Seraph.Query.Condition{
                   conditions: nil,
                   field: :firstName,
                   join_operator: :and,
                   operator: :==,
                   source: "u",
                   value: "param_1"
                 }
               ],
               field: nil,
               join_operator: :and,
               operator: :and,
               source: nil,
               value: nil
             } = Keyword.get(operations, :where)
    end

    test "ok: operator :==" do
      assert %Seraph.Query{operations: operations, params: [param_0: "uuid-1"]} =
               match([{u, User}])
               |> where(u.uuid == "uuid-1")

      assert %Seraph.Query.Condition{
               conditions: nil,
               field: :uuid,
               join_operator: :and,
               operator: :==,
               source: "u",
               value: "param_0"
             } = Keyword.get(operations, :where)
    end

    #   test "ok: operator :or"

    test "ok: pinned variable" do
      uuid = "uuid-1"

      assert %Seraph.Query{operations: operations, params: [uuid: "uuid-1"]} =
               match([{u, User}])
               |> where(u.uuid == ^uuid)

      assert %Seraph.Query.Condition{
               conditions: nil,
               field: :uuid,
               join_operator: :and,
               operator: :==,
               source: "u",
               value: "uuid"
             } = Keyword.get(operations, :where)
    end

    test "raise: unknwon alias" do
      assert_raise Seraph.QueryError, fn ->
        defmodule Willfail do
          match([{u, User}])
          |> where(p.uuid == "5")
        end
      end
    end

    test "raise: unknwon property on alias" do
      assert_raise Seraph.QueryError, fn ->
        defmodule Willfail do
          match([{u, User}])
          |> where(u.invalid == "5")
        end
      end
    end

    test "raise: invalid property type" do
      assert_raise Seraph.QueryError, fn ->
        defmodule Willfail do
          match([{u, User}])
          |> where(p.uuid == 5)
        end
      end
    end
  end

  describe "return" do
    test "ok: entity return" do
      assert %Seraph.Query{
               literal: ["match:\n\t{u, User}", "return:\n\tu"],
               operations: operations,
               params: [],
               result_aliases: []
             } =
               match([{u, User}])
               |> return([u])

      assert %Seraph.Query.Builder.ReturnExpr{
               distinct?: false,
               fields: [
                 %Seraph.Query.Builder.NodeExpr{
                   alias: nil,
                   index: nil,
                   labels: ["User"],
                   properties: %{},
                   variable: "u"
                 }
               ]
             } = operations[:return]
    end

    test "ok: property return" do
      assert %Seraph.Query{
               literal: ["match:\n\t{u, User}", "return:\n\tu.uuid"],
               operations: operations,
               params: [],
               result_aliases: []
             } =
               match([{u, User}])
               |> return([u.uuid])

      assert %Seraph.Query.Builder.ReturnExpr{
               distinct?: false,
               fields: [%Seraph.Query.Builder.FieldExpr{alias: nil, name: :uuid, variable: "u"}]
             } == operations[:return]
    end

    test "ok: aliased returns" do
      assert %Seraph.Query{operations: operations, result_aliases: [res_node: :u]} =
               match([{u, User}])
               |> return(res_node: u, res_prop: u.uuid)

      assert %Seraph.Query.Builder.ReturnExpr{
               distinct?: false,
               fields: [
                 %Seraph.Query.Builder.FieldExpr{alias: "res_prop", name: :uuid, variable: "u"},
                 %Seraph.Query.Builder.NodeExpr{
                   alias: "res_node",
                   index: nil,
                   labels: ["User"],
                   properties: %{},
                   variable: "u"
                 }
               ]
             } = operations[:return]
    end

    test "raise: unknwon alias" do
      assert_raise Seraph.QueryError, fn ->
        defmodule Willfail do
          match([{u, User}])
          |> return([p])
        end
      end
    end

    test "raise: unknwon property on alias" do
      assert_raise Seraph.QueryError, fn ->
        defmodule Willfail do
          match([{u, User}])
          |> return([u.invalid])
        end
      end
    end
  end

  describe "query entrypoints" do
    test "ok: match" do
      assert %Seraph.Query{} = match([])
    end
  end

  describe "to_string/2" do
  end
end
