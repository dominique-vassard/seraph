# Up and running

The aim of this guide is to explain how Seraph works with a full example.  

Neo4j is required, so if you haven't installed it yet, get it at https://neo4j.com/download/.

Be sure to have a running database with the following credentials:  
- login: `neo4j`
- password: `graph_app_pass`

## The Project: GraphApp
We are going to build a backend to manage the data for a blog application.  
The model will be as follow:  
![GraphApp Model](assets/model.png) 
 
a `User` can only have one `UserProfile`.  
a `User` can write multiple `Posts`.  
a `User` can read multiple `Posts`.
a `User` can write multiple `Comments`.  
a `Post` can have multiple `Comments`.  

`User` properties:
- firstName 
- lastName
- email

`UserProfile` properties:
- isPremium
- age

`Post` properties:
- title
- text

`Comment` properties:
- text

`:WROTE` (from `User` to `Post`, and from `User` to `Comment`) properties:
- when

### Relationship cardinalities
```
(User)-[:WROTE]->(Post)  
  1        -        x  
(User)-[:WROTE]->(Comment)  
  1        -        x  
(User)-[:READ]->(Post)  
  x        -        x  
(User)-[:FOLLOWS]->(User)  
  1        -        x  
(User)-[:HAS_PROFILE]->(UserProfile)  
  1        -              1  
(Comment)-[:IS_ABOUT]->(Post)  
  x        -        1  
```

### Create the application
We create our supervised application via
```bash
mix new --sup graph_app
* creating README.md
* creating .formatter.exs
...
* creating test/graph_app_test.exs

Your Mix project was created successfully.
You can use "mix" to compile it, test it, and more:

    cd graph_app
    mix test

Run "mix help" for more commands.
```

Now, we can add our dependencies in `mix.exs`:  
```elixir
# mix.exs
defp deps do
    [
      {:seraph, "~> 0.1"}
    ]
  end
```
and
```bash
mix do deps get, compile
```

### Configuration
It's time to define our Repo and to add its config.  

Open `config/config.exs` and add th repo config:
```
# config/config.exs
config :graph_app, GraphApp.Repo,
  hostname: 'localhost',
  basic_auth: [username: "neo4j", password: "graph_app_pass"],
  port: 7687

``` 

We create our repo module:  
```elixir
# lib/graph_app/repo.ex
defmodule GraphApp.Repo do
  use Seraph.Repo, otp_app: :graph_app
end
```

Note that besides `GraphApp.Repo`, we can also use `GraphApp.Repo.Node` and `GraphApp.Repo.Relationship` for entity-specific operations. 

And we don't forget to add to our application supervisor:
```elixir
# lib/graph_app/application
def start(_type, _args) do
  # List all child processes to be supervised
  children = [
    GraphApp.Repo
  ]
  opts = [strategy: :one_for_one, name: GraphApp.Supervisor]
  Supervisor.start_link(children, opts)
end
```

Now, we can make our first query in `iex` to test that everything has been well configured:  
```elixir
iex -S mix
iex> GraphApp.Repo.query!("RETURN 1 AS num")
[%{"num" => 1}]
```

### Formating
`Seraph` has functions with custom formating.  
Be sure to get these benefits by adding this to your `.formatter.exs`:
```elixir
# .formatter.exs
...
import_deps: [:seraph]
...
``` 