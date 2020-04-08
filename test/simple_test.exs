defmodule Seraph.RepoTest do
  use ExUnit.Case, async: true
  alias Seraph.TestRepo
  # alias Seraph.Test.User

  test "create and retrieve node" do
    cql = """
    CREATE
      (t:Test {uuid: "1", value: "ok right"})
    RETURN
      t
    """

    TestRepo.query!(cql, %{}, with_stats: true)
    |> IO.inspect()
  end

  # test "Node alone (bare, no changeset)" do
  #       user = %User{
  #         firstName: "John",
  #         lastName: "Doe",
  #         viewCount: 5
  #       }

  #       assert {:ok, created_user} = TestRepo.create(user)

  #       assert %Seraph.Test.User{
  #                firstName: "John",
  #                lastName: "Doe",
  #                viewCount: 5
  #              } = created_user

  #       refute is_nil(created_user.__id__)
  #       refute is_nil(created_user.uuid)

  #       cql = """
  #       MATCH
  #         (u:User)
  #       WHERE
  #         u.firstName = $firstName
  #         AND u.lastName = $lastName
  #         AND u.viewCount = $viewCount
  #         AND id(u) = $id
  #         AND u.uuid = $uuid
  #       RETURN
  #         COUNT(u) AS nb_result
  #       """

  #       params = %{
  #         uuid: created_user.uuid,
  #         firstName: "John",
  #         lastName: "Doe",
  #         viewCount: 5,
  #         id: created_user.__id__
  #       }

  #       assert [%{"nb_result" => 1}] = TestRepo.query!(cql, params)
  #     end
end
