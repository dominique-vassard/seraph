defmodule Seraph.Support.Storage do
  def clear(repo) do
    repo.query!("MATCH (n) DETACH DELETE n", %{}, with_stats: true)

    # [
    #   Seraph.Cypher.Node.list_all_constraints(""),
    #   Seraph.Cypher.Node.list_all_indexes("")
    # ]
    # |> Enum.map(fn cql ->
    #   repo.raw_query!(cql)
    #   |> Map.get(:records, [])
    # end)
    # |> List.flatten()
    # |> Enum.map(&Seraph.Cypher.Node.drop_constraint_index_from_cql/1)
    # |> Enum.map(&repo.query/1)
  end

  def add_fixtures(repo) do
    cql = """
    CREATE
    (a:Admin {uuid: $admin}),
    (u1:User {uuid: $user1, firstName: "John", lastName: "Doe", viewCount: 0}),
    (u2:User {uuid: $user2, firstName: "James", lastName: "Who", viewCount: 0}),
    (u3:User {uuid: $user3, firstName: "Igor", lastName: "Gone", viewCount: 0}),
    (p1:Post {uuid: $post1, title: "post1", text: "This post 1"}),
    (p2:Post {uuid: $post2, title: "post2", text: "This post 2"}),
    (p3:Post {uuid: $post3, title: "post3", text: "This post 3"}),
    (p4:Post {uuid: $post4, title: "post4", text: "This post 4"}),
    (p5:Post {uuid: $post5, title: "post5", text: "This post 5"}),
    (p6:Post {uuid: $post6, title: "post6", text: "This post 6"}),
    (c1:Comment {uuid: $comment1, title: "comment1", text: "This is number 1", rate: 4}),
    (c2:Comment {uuid: $comment2, title: "comment2", text: "This is number 2", rate: 4}),
    (c3:Comment {uuid: $comment3, title: "comment3", text: "This is number 3", rate: 4}),
    (c4:Comment {uuid: $comment4, title: "comment4", text: "This is number 4", rate: 4}),
    (c5:Comment {uuid: $comment5, title: "comment5", text: "This is number 5", rate: 4}),
    (c6:Comment {uuid: $comment6, title: "comment6", text: "This is number 6", rate: 4}),
    (c7:Comment {uuid: $comment7, title: "comment7", text: "This is number 7", rate: 4}),
    (c8:Comment {uuid: $comment8, title: "comment8", text: "This is number 8", rate: 4}),
    (u1)-[:IS_A]->(a),
    (u1)-[:IS_A]->(a),
    (u2)-[:IS_A]->(a),
    (u1)-[:WROTE]->(p1),
    (u1)-[:WROTE]->(p2),
    (u1)-[:WROTE]->(p3),
    (u1)-[:WROTE]->(p4),
    (u2)-[:WROTE]->(p5),
    (u1)-[:WROTE]->(c1),
    (u1)-[:WROTE]->(c2),
    (u1)-[:WROTE]->(c3),
    (u1)-[:WROTE]->(c4),
    (u1)-[:WROTE]->(c5),
    (u2)-[:WROTE]->(c6),
    (u2)-[:WROTE]->(c7),
    (u2)-[:WROTE]->(c8),
    (u1)-[:READ]->(p1),
    (u2)-[:READ]->(p1),
    (u2)-[:READ]->(p2),
    (u2)-[:READ]->(p3),
    (u2)-[:FOLLOWS]->(u1),
    (p2)-[:EDITED_BY]->(u1),
    (p3)-[:EDITED_BY]->(u1),
    (p3)-[:EDITED_BY]->(u2)
    """

    params = %{
      admin: UUID.uuid4(),
      user1: UUID.uuid4(),
      user2: UUID.uuid4(),
      user3: UUID.uuid4(),
      post1: UUID.uuid4(),
      post2: UUID.uuid4(),
      post3: UUID.uuid4(),
      post4: UUID.uuid4(),
      post5: UUID.uuid4(),
      post6: UUID.uuid4(),
      comment1: UUID.uuid4(),
      comment2: UUID.uuid4(),
      comment3: UUID.uuid4(),
      comment4: UUID.uuid4(),
      comment5: UUID.uuid4(),
      comment6: UUID.uuid4(),
      comment7: UUID.uuid4(),
      comment8: UUID.uuid4()
    }

    repo.query!(cql, params)
    [uuids: params]
  end
end
