config = [
  hostname: "localhost",
  basic_auth: [username: "neo4j", password: "test"],
  port: 7687,
  pool_size: 5,
  max_overflow: 1
]

Application.put_env(:seraph, Seraph.TestRepo, config)

defmodule Seraph.TestRepo do
  use Seraph.Repo, otp_app: :seraph
end

Seraph.TestRepo.start_link()
