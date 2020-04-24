# Setting new data
This section could be call updating but there is no `update` command in Cypher but `set` is used to do this job.  
For the same reason, getting close to Neo4j idioms, there is no `update` functions in `Seraph` but `set/2` and the great `merge/3`(for Nodes) and `merge/4` (for Relationships) for this task.  
`set/2` allows to set new properties (and start / end nodes for relationships).  

## using `set/2`
Setting new data on nodes with `set/2` is straightforward:
```
GraphApp.Repo.Node.get(User, "87f6c568-0454-4688-b5e8-d7036b30b78b")
|> User.changeset(%{email: "john.new_email@mail.com"})
|> GraphApp.Repo.Node.set()

# Result
{:ok,
 %GraphApp.Blog.User{
   __id__: 1,
   __meta__: %Seraph.Schema.Node.Metadata{
     primary_label: "User",
     schema: GraphApp.Blog.User
   },
   additionalLabels: [],
   comments: #Seraph.Schema.Node.NotLoaded<nodes (Comment) through relationship :WROTE are not loaded>,
   email: "john.new_email@mail.com",
   firstName: "John",
   followed: #Seraph.Schema.Node.NotLoaded<nodes (User) through relationship :FOLLOWS are not loaded>,
   follows: #Seraph.Schema.Relationship.NotLoaded<relationships :FOLLOWS are not loaded>,
   has_profile: #Seraph.Schema.Relationship.NotLoaded<relationships :HAS_PROFILE are not loaded>,
   lastName: "Doe",
   posts: #Seraph.Schema.Node.NotLoaded<nodes (Post) through relationship :WROTE are not loaded>,
   profile: #Seraph.Schema.Node.NotLoaded<nodes (UserProfile) through relationship :HAS_PROFILE are not loaded>,
   read: #Seraph.Schema.Relationship.NotLoaded<relationships :READ are not loaded>,
   read_posts: #Seraph.Schema.Node.NotLoaded<nodes (Post) through relationship :READ are not loaded>,
   uuid: "87f6c568-0454-4688-b5e8-d7036b30b78b",
   wrote: #Seraph.Schema.Relationship.NotLoaded<relationships :WROTE are not loaded>
 }}
```

Setting properties is also available on Relationship and you can set new start and end nodes.  
```
new_user_data = %User{firstName: "Collin", lastName: "Chou", email: "collin.chou@mail.com"}
new_user = GraphApp.Repo.Node.create!(new_user_data)

GraphApp.Repo.Relationship.get(Wrote, john, post) |> Wrote.changeset(%{start_node: new_user}) |> GraphApp.Repo.Relationship.set()

# Result
{:ok,
 %GraphApp.Blog.Relationship.Wrote{
   __id__: 60,
   __meta__: %Seraph.Schema.Relationship.Metadata{
     schema: GraphApp.Blog.Relationship.Wrote,
     type: "WROTE"
   },
   end_node: %GraphApp.Blog.Post{
     __id__: 40,
     __meta__: %Seraph.Schema.Node.Metadata{
       primary_label: "Post",
       schema: GraphApp.Blog.Post
     },
     additionalLabels: [],
     author: #Seraph.Schema.Node.NotLoaded<nodes (User) through relationship :WROTE are not loaded>,
     comments: #Seraph.Schema.Node.NotLoaded<nodes (Comment) through relationship :IS_ABOUT are not loaded>,
     is_about: #Seraph.Schema.Relationship.NotLoaded<relationships :IS_ABOUT are not loaded>,
     rate: 0,
     read: #Seraph.Schema.Relationship.NotLoaded<relationships :READ are not loaded>,
     readers: #Seraph.Schema.Node.NotLoaded<nodes (User) through relationship :READ are not loaded>,
     text: "Blabla",
     title: "A wonderful first post",
     uuid: "d52ce3fc-f67a-44be-bc9d-95d2c23d884f",
     wrote: #Seraph.Schema.Relationship.NotLoaded<relationships :WROTE are not loaded>
   },
   start_node: %GraphApp.Blog.User{
     __id__: 59,
     __meta__: %Seraph.Schema.Node.Metadata{
       primary_label: "User",
       schema: GraphApp.Blog.User
     },
     additionalLabels: [],
     comments: #Seraph.Schema.Node.NotLoaded<nodes (Comment) through relationship :WROTE are not loaded>, 
     email: "collin.chou@mail.com",
     firstName: "Collin",
     followed: #Seraph.Schema.Node.NotLoaded<nodes (User) through relationship :FOLLOWS are not loaded>,
     follows: #Seraph.Schema.Relationship.NotLoaded<relationships :FOLLOWS are not loaded>,
     has_profile: #Seraph.Schema.Relationship.NotLoaded<relationships :HAS_PROFILE are not loaded>,
     lastName: "Chou",
     posts: #Seraph.Schema.Node.NotLoaded<nodes (Post) through relationship :WROTE are not loaded>,
     profile: #Seraph.Schema.Node.NotLoaded<nodes (UserProfile) through relationship :HAS_PROFILE are not loaded>,
     read: #Seraph.Schema.Relationship.NotLoaded<relationships :READ are not loaded>,
     read_posts: #Seraph.Schema.Node.NotLoaded<nodes (Post) through relationship :READ are not loaded>,
     uuid: "efc2b415-3a41-4b5f-aa8c-ad161a8baf43",
     wrote: #Seraph.Schema.Relationship.NotLoaded<relationships :WROTE are not loaded>
   },
   type: "WROTE",
   when: #DateTime<2020-04-23 08:54:50.000Z>
 }}
```
