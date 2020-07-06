# Using the Seraph.Query API

## Notation
There is two entities in Neo4j graph database: Node and Relationship.  
To be as close as possible to Cypher, we used the following notations in queries.

Nodes are defined between `{}`
```elixir
{u, GraphApp.Blog.User, %{firstName: "John"}}
 ^       ^                 ^
 |       |                 |
 |       |                 -- properties 
 |       -- schema
 -- variable

All variations are valid depending on the query keyword.

``` 
Relationship are defined betwen `[]`
```elixir
[{u}, [rel, GraphApp.Blog.Relationship.Wrote, %{at: ...}], {p}]
  ^     ^              ^                           ^        ^
  |     |              |                           |        |
  |     |              |                           |        -- end_node
  |     |              |                           -- properties 
  |     |              -- schema
  |     -- variable
  -- start_node

``` 
All variations are valid depending on the query keyword.

## About keywords
### Available keywords
For now, the available keywords are:  
  - [`match`](Seraph.Query.html#match/2)
  - [`create`](Seraph.Query.html#create/2)
  - [`merge`](Seraph.Query.html#merge/2)
  - [`delete`](Seraph.Query.html#delete/2)
  - [`set`](Seraph.Query.html#set/2)
  - [`on_create_set`](Seraph.Query.html#on_create_set/2)
  - [`on_match_set`](Seraph.Query.html#on_match_set/2)
  - [`remove`](Seraph.Query.html#remove/2)
  - [`where`](Seraph.Query.html#where/2)
  - [`return`](Seraph.Query.html#return/2)
  - [`order_by`](Seraph.Query.html#order_by/2)
  - [`skip`](Seraph.Query.html#skip/2)
  - [`limit`](Seraph.Query.html#limit/2)
  
  Click on each keyword for more information (inputs, restrictions, etc.)

### Keyword order
Keywords can be used in any order in order to give flexibility whne writing queries.  
But only `match`, `create` and `merge` can be used to start a query.  
   
## Query syntax
There are to ways to write query: kewyord syntax and macro syntax.

Keyword syntax
```elixir
import Seraph.Query

query = match [{u, User}],
  where: [u.firstName == "John"],
  return: [u]

GraphApp.Repo.all(query)
```

Macro syntax
```elixir
import Seraph.Query

match([{u, User}])
|> where([u.firstName == "John"])
|> return([u])
|> GraphApp.Repo.query()
```

Both syntaxes required variables to be pinned using `^`:
```elixir
import Seraph.Query

first_name = "John"
match([{u, User}])
|> where([u.firstName == ^first_name])
|> return([u])
|> GraphApp.Repo.query()
```

### Query options
## `:with_stats`
Sometimes, a query result is not enough, we need to get its summary, especially when dealing with create, merge, set or delete operations.  
To get the summary, just use the option `with_stats: true`.  

Examples:
```elixir
# default - with_stats: false
import Seraph.Query
create([{u, GraphApp.Blog.User}])
|> set([u.uuid = "0223a553-a474-46e1-8798-805411827b20", u.firstName = "Jim", u.lastName = "Cook"])
|> return([u])
|> GraphApp.Repo.one()

# Result
%{
  "u" => %GraphApp.Blog.User{
    __id__: 1,
    __meta__: %Seraph.Schema.Node.Metadata{
      primary_label: "User",
      schema: GraphApp.Blog.User
    },
    additionalLabels: [],
    uuid: "0223a553-a474-46e1-8798-805411827b20",
    firstName: "Jim",
    lastName: "Cook",
    ...
  }
}


# with_stats: true
create([{u, GraphApp.Blog.User}])
|> set([u.uuid = "1f178997-5f32-4c1b-acc7-0079f7eea9c6", u.firstName = "Jane", u.lastName = "Doe"])
|> return([u])
|> GraphApp.Repo.one(with_stats: true) 

# Result
%{
  results: %{
    "u" => %GraphApp.Blog.User{
      __id__: 42,
      __meta__: %Seraph.Schema.Node.Metadata{
        primary_label: "User",
        schema: GraphApp.Blog.User
      },
      additionalLabels: [],
      uuid: "1f178997-5f32-4c1b-acc7-0079f7eea9c6",
      firstName: "Jane",
      lastName: "Doe",
      ...
    }
  },
  stats: %{"labels-added" => 1, "nodes-created" => 1, "properties-set" => 3}
}
```

## `:relationship_result`
Relatinship struct holds both start node and end node data and this can be quite a lot of data when retrieving numerous relationships. 
Also sometimes, we just want the complete relationship without having to return the start and end nodes from the query.  
`:relationship_result` address both this issue with 3 values:
- `:contextual` (default) - The relationship will be built only using the query result, meaning that if the nodes aren't part of the return, start and end node will be empty
- `:no_nodes` - start and end node data won't be filled up, even if they are present in query return
- `:full` - start and end node data will be filled up, even if they are not present in query return

Examples:
Let's create a relationship first
```elixir
match([
    {u, GraphApp.Blog.User, %{firstName: "Jim"}},
    {u2, GraphApp.Blog.User, %{firstName: "Jane"}}
])
|> merge([{u}, [GraphApp.Blog.Relationship.NoProperties.Follows], {u2}])
|> GraphApp.Repo.execute(with_stats: true)

# Result
{:ok, %{results: [], stats: %{"relationships-created" => 1}}}
```

Now we build query
```elixir
query = match [
    {u, GraphApp.Blog.User, %{firstName: "Jim"}},
    {u2, GraphApp.Blog.User, %{firstName: "Jane"}},
    [{u}, [rel, GraphApp.Blog.Relationship.NoProperties.UserToUser.Follows], {u2}]
],
return: [u, rel]
```

#### relationship_result: :contextual (default value)
```elixir
GraphApp.Repo.all(query)

# Result
# end_node is nil because it is not part of query result
[
  %{
    "rel" => %GraphApp.Blog.Relationship.NoProperties.UserToUser.Follows{
      __id__: 42,
      __meta__: %Seraph.Schema.Relationship.Metadata{...},
      end_node: nil,
      start_node: %GraphApp.Blog.User{
        __id__: 1,
        __meta__: %Seraph.Schema.Node.Metadata{
          primary_label: "User",
          schema: GraphApp.Blog.User
        },
        additionalLabels: [],
        uuid: "0223a553-a474-46e1-8798-805411827b20",
        firstName: "Jim",
        lastName: "Cook",
        ...
      },
      type: "FOLLOWS"
    },
    "u" => %GraphApp.Blog.User{
      __id__: 1,
      __meta__: %Seraph.Schema.Node.Metadata{...},
      additionalLabels: [],
      uuid: "0223a553-a474-46e1-8798-805411827b20",
      firstName: "Jim",
      lastName: "Cook",
      ...
    }
  }
]
```
### relationship_result: :no_nodes
```elixir
GraphApp.Repo.all(query, relationship_result: :no_nodes)

# Result
# Both start_node and end_node are nil, even if the start_node (u) is part of the query result
[
  %{
    "rel" => %GraphApp.Blog.Relationship.NoProperties.UserToUser.Follows{
      __id__: 42,
      __meta__: %Seraph.Schema.Relationship.Metadata{
        schema: GraphApp.Blog.Relationship.NoProperties.UserToUser.Follows,
        type: "FOLLOWS"
      },
      end_node: nil,
      start_node: nil,
      type: "FOLLOWS"
    },
    "u" => %GraphApp.Blog.User{
      __id__: 1,
      __meta__: %Seraph.Schema.Node.Metadata{...},
      additionalLabels: [],
      uuid: "0223a553-a474-46e1-8798-805411827b20",
      firstName: "Jim",
      lastName: "Cook",
      ...
    }
  }
]
```

### relationship_result: :full
```elixir
GraphApp.Repo.all(query, relationship_result: :full)

# Result
# start_node and end_node are filled up, even if end_node (u2) is not part of query result
[
  %{
    "rel" => %GraphApp.Blog.Relationship.NoProperties.UserToUser.Follows{
      __id__: 42,
      __meta__: %Seraph.Schema.Relationship.Metadata{...},
      end_node: %GraphApp.Blog.User{
        __id__: 42,
        __meta__: %Seraph.Schema.Node.Metadata{...},
        additionalLabels: [],
        uuid: "1f178997-5f32-4c1b-acc7-0079f7eea9c6",
        firstName: "Jane",
        lastName: "Doe",
      },
      start_node: %GraphApp.Blog.User{
        __id__: 1,
        __meta__: %Seraph.Schema.Node.Metadata{
          primary_label: "User",
          schema: GraphApp.Blog.User
        },
        additionalLabels: [],
        uuid: "0223a553-a474-46e1-8798-805411827b20",
        firstName: "Jim",
        lastName: "Cook",
        ...
      },
      type: "FOLLOWS"
    },
    "u" => %GraphApp.Blog.User{
      __id__: 1,
      __meta__: %Seraph.Schema.Node.Metadata{...},
      additionalLabels: [],
      uuid: "0223a553-a474-46e1-8798-805411827b20",
      firstName: "Jim",
      lastName: "Cook",
      ...
    }
  }
]
```