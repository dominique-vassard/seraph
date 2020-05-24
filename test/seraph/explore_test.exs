defmodule Seraph.ExploreTest do
  use ExUnit.Case

  import Seraph.Query
  alias Seraph.Query.Builder

  alias Seraph.Test.{Post, User}
  alias Seraph.Test.UserToPost.Wrote
  alias Seraph.TestRepo

  test "unique" do
    # cql = """
    # MATCH
    # ()-[rel:WROTE]->()
    # WHERE
    # id(rel) = 117
    # RETURN
    # rel, startNode(rel) AS u, endNode(rel) AS p
    # """

    # TestRepo.query!(cql)
    # |> IO.inspect()

    uuid = "uuid-4"

    # query =
    #   match [{u, User}],
    #     # where: not is_nil(u.lastName),
    #     # return: [u, u.uuid, max(u.firstName), distinct(u.lastName)]
    #     return: [
    #       # 5,
    #       # collect(u.lastName),
    #       [num: 1],
    #       [uuid: ^uuid],
    #       [collect: collect(u.lastName)],
    #       [person: u, res: collect(u.firstName)],
    #       u.uuid,
    #       [percentile: percentile_disc(u.viewCount, 67)]
    #     ]

    # query =
    #   match([{u, User}])
    #   |> return(nb_person: count(distinct(u.firstName)))

    # queryable = Seraph.Test.User

    # res =
    #   TestRepo.query!("MATCH (n:User) RETURN n.uuid AS uuid LIMIT 1")
    #   |> List.first()
    #   |> IO.inspect()

    # TestRepo.Node.get(User, res["uuid"])

    # uuid = res["uuid"]

    # # query =
    # #   match [{u, User, %{uuid: ^uuid}}],
    # #     return: u

    # # query
    # # |> IO.inspect(label: "__________________________________")

    # |> prepare([])
    # |> IO.inspect()
  end

  test "2" do
    query =
      match([[{User}, [rel], {Post}]])
      |> prepare([])

    # |> IO.inspect()

    # ln = "James"

    # query =
    #   match([{u, User}])
    #   |> where(u.uuid == "uuid-1" and u.lastName == ^ln and u.firstName == "John")

    # prepare(query, [])
    # |> IO.inspect()
  end
end
