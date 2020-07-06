# Seraph

[![Build Status](https://travis-ci.org/dominique-vassard/seraph.svg?branch=master)](https://travis-ci.org/dominique-vassard/seraph)

Docs: https://hexdocs.pm/seraph

Seraph is a tool to use Neo4j in Elixir project in a graph way.  
It is heavily inspired by Ecto and OGM projects (in Java and python in particular).  

The goal is to provide an API to interact easily with one or more Neo4j database.  

## Installation

The package can be installed by adding `seraph` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:seraph, "~> 0.2.0"}
  ]
end
```

# Configuration
```
# In your config/config.exs file
config :my_app, ecto_repos: [Sample.Repo]

config :my_app, Sample.Repo,
  hostname: "localhost",
  basic_auth: [username: "neo4j", password: "test"],
  port: 7687,
  pool_size: 5,
  max_overflow: 1

# In your application code
defmodule Sample.Repo do
  use Seraph.Repo, otp_app: :my_app
end

# In your application.ex
defmodule MyApp.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      Sample.Repo
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

### Contributing

- [Fork it](https://github.com/dominique-vassard/seraph/fork)
- Create your feature branch (`git checkout -b my-new-feature`)
- Test (`mix test`)
- Commit your changes (`git commit -am 'Add some feature'`)
- Push to the branch (`git push origin my-new-feature`)
- Create new Pull Request

