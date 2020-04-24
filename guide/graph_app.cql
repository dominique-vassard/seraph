CREATE
(u1:User {uuid: "user1", firstName: "John", lastName: "Doe", email: "john.doe@mail.com"}),
(u2:User {uuid: "user2", firstName: "James", lastName: "Who", email: "whostheboss@mail.com"}),
(u3:User {uuid: "user3", firstName: "Lilian", lastName: "Reader", email: "lilian.reader@mail.com"}),

(up1:UserProfile {uuid: "userprofile1", isPremium: true, age: 32}),
(up2:UserProfile {uuid: "userprofile2", isPremium: true, age: 32}),
(up3:UserProfile {uuid: "userprofile3", isPremium: false, age: 22}),

(p1:Post {uuid: "post1", title: "First post", text: "This is my first post. So proud!", rate: 0}),
(p2:Post {uuid: "post2", title: "Today I learned...", text: "...a lot of things!", rate: 1}),
(p3:Post {uuid: "post3", title: "About Elixir and greatness", text: "Elixir is very very great", rate: 4}),
(p4:Post {uuid: "post4", title: "Just saw Matrix Reloaded", text: "And wow that's great!", rate: 4}),
(p5:Post {uuid: "post5", title: "Seraph, the exile", text: "Seraph is an old program of the Matrix.", rate: 5}),

(c1:Comment {uuid: "comment1", text: "I liked this movie"}),
(c2:Comment {uuid: "comment2", text: "Elixir is THE thing"}),
(c3:Comment {uuid: "comment3", text: "I :heart Elixir"}),
(c4:Comment {uuid: "comment4", text: "collin is so great in this movie"}),
(c5:Comment {uuid: "comment5", text: "Exile are the punks of the Matrix"}),
(c6:Comment {uuid: "comment6", text: "Long live the Exiles!"}),
(c7:Comment {uuid: "comment7", text: "No way, it's such a shame after the first opus"}),
(c8:Comment {uuid: "comment8", text: "Oh yeah I agree."}),

(u1)-[:HAS_PROFILE]->(up1),
(u1)-[:HAS_PROFILE]->(up2),
(u1)-[:HAS_PROFILE]->(up3),

(u1)-[:WROTE]->(p1),
(u1)-[:WROTE]->(p2),
(u1)-[:WROTE]->(p3),
(u2)-[:WROTE]->(p4),
(u2)-[:WROTE]->(p5),




(u3)-[:WROTE]->(c1),
(u2)-[:WROTE]->(c2),
(u2)-[:WROTE]->(c3),
(u3)-[:WROTE]->(c4),
(u3)-[:WROTE]->(c5),
(u3)-[:WROTE]->(c6),
(u3)-[:WROTE]->(c7),
(u2)-[:WROTE]->(c8),


(c1)-[:IS_ABOUT]->(p4),
(c2)-[:IS_ABOUT]->(p3),
(c3)-[:IS_ABOUT]->(p3),
(c4)-[:IS_ABOUT]->(p4),
(c5)-[:IS_ABOUT]->(p5),
(c6)-[:IS_ABOUT]->(p5),
(c7)-[:IS_ABOUT]->(p3),
(c8)-[:IS_ABOUT]->(p2),

(u2)-[:READ]->(p3),
(u2)-[:READ]->(p2),
(u3)-[:READ]->(p4),
(u2)-[:READ]->(p3),
(u2)-[:READ]->(p5),

(u3)-[:FOLLOWS]->(u1),
(u1)-[:FOLLOWS]->(u2)