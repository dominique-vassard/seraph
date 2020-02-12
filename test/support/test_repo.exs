config = [
  hostname: "localhost",
  basic_auth: [username: "neo4j", password: "test"],
  port: 7687,
  pool_size: 5,
  max_overflow: 1
]

Application.put_env(:neo4jex, Neo4jex.TestRepo, config)

defmodule Neo4jex.TestRepo do
  use Neo4jex.Repo, otp_app: :neo4jex
end

Neo4jex.TestRepo.start_link()
