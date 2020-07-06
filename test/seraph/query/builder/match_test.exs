defmodule Seraph.Query.Builder.MatchTest do
  use ExUnit.Case, async: true

  alias Seraph.Query.Builder.Match

  alias Seraph.Test.User
  alias Seraph.Test.NoPropsRels.UserToUser.Follows

  describe "build/2" do
    ast =
      quote do: [
              {u, User, %{uuid: "user-uuid-1"}},
              {u2, User, %{uuid: "user-uuid-2"}},
              [{u}, [rel, Follows], {u2}]
            ]

    start_data = %Seraph.Query.Builder.Entity.Node{
      alias: nil,
      identifier: "u",
      labels: ["User"],
      properties: [
        %Seraph.Query.Builder.Entity.Property{
          alias: nil,
          bound_name: "u_uuid_0",
          entity_identifier: "u",
          entity_queryable: Seraph.Test.User,
          name: :uuid,
          type: nil,
          value: nil
        }
      ],
      queryable: Seraph.Test.User
    }

    end_data = %Seraph.Query.Builder.Entity.Node{
      alias: nil,
      identifier: "u2",
      labels: ["User"],
      properties: [
        %Seraph.Query.Builder.Entity.Property{
          alias: nil,
          bound_name: "u2_uuid_0",
          entity_identifier: "u2",
          entity_queryable: Seraph.Test.User,
          name: :uuid,
          type: nil,
          value: nil
        }
      ],
      queryable: Seraph.Test.User
    }

    rel_data = %Seraph.Query.Builder.Entity.Relationship{
      alias: nil,
      end: %Seraph.Query.Builder.Entity.Node{
        alias: nil,
        identifier: "u2",
        labels: ["User"],
        properties: [],
        queryable: Seraph.Test.User
      },
      identifier: "rel",
      properties: [],
      queryable: Seraph.Test.NoPropsRels.UserToUser.Follows,
      start: %Seraph.Query.Builder.Entity.Node{
        alias: nil,
        identifier: "u",
        labels: ["User"],
        properties: [],
        queryable: Seraph.Test.User
      },
      type: "FOLLOWS"
    }

    assert %{identifiers: identifiers, match: match, params: params} = Match.build(ast, __ENV__)

    assert %{"rel" => rel_data, "u" => start_data, "u2" => end_data} = identifiers
    assert %Match{entities: [rel_data, start_data, end_data]} = match
    assert [u2_uuid_0: "user-uuid-2", u_uuid_0: "user-uuid-1"] = params
  end
end
