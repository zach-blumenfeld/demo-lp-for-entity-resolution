// Create Constraints
CREATE CONSTRAINT userId_not_null IF NOT EXISTS
FOR (user:User)
REQUIRE user.userId IS NOT NULL;

CREATE CONSTRAINT userId_unique IF NOT EXISTS
FOR (user:User)
REQUIRE user.userId  IS UNIQUE;

CREATE CONSTRAINT url_not_null IF NOT EXISTS
FOR (website:Website)
REQUIRE website.url IS NOT NULL;

CREATE CONSTRAINT url_unique IF NOT EXISTS
FOR (website:Website)
REQUIRE website.url IS UNIQUE;

// Visualise the schema of the data
CALL db.schema.visualization();

/*///////////////////////
// Data Loading
// You can use `file:///` if you're running this example locally.
// For AuraDS, see: https://www.neo4j.com/docs/aura/aurads/importing-data/load-csv/
*////////////////////////

// Load Users
LOAD CSV WITH HEADERS FROM 'file:///users.csv' AS row
MERGE (user:User {userId:row.uid})
RETURN count(user);

//load websites
LOAD CSV WITH HEADERS FROM 'file:///websites.csv' AS row
MERGE (website:Website {url: row.url, urlPathDepth: toInteger(row.url_path_depth)})
RETURN count(website);

//load ground truth identity alignments
LOAD CSV WITH HEADERS FROM 'file:///user_alignments.csv' AS row
MATCH(user1:User {userId:row.uid1})
MATCH(user2:User {userId:row.uid2})
MERGE (user1)-[r:SAME_AS]->(user2)
RETURN count(user1), count(user2);

//load website hierarchy
:auto USING PERIODIC COMMIT 10000
LOAD CSV WITH HEADERS FROM 'file:///web_hierarchy.csv' AS row
MATCH(website1:Website {url: row.url1})
MATCH(website2:Website {url: row.url2})
MERGE (website2)-[r:CHILD_OF {weight: toInteger(website1.urlPathDepth)}]->(website1)
RETURN count(r);

//load visits
:auto USING PERIODIC COMMIT 10000
LOAD CSV WITH HEADERS FROM 'file:///user_website_visits.csv' AS row
MATCH(user:User {userId:row.uid})
MATCH(website:Website {url: row.url})
with user, website, row, toInteger(row.number_of_visits) as num_visits
MERGE (user)-[r:VISITED {
    eventIds: split(replace(replace(row.fid,'{',''),'}',''),', '),
    timeStamps: reduce(dateTimes = [],
                e in split(replace(replace(row.ts,'[',''),']',''),', ') |
                dateTimes + datetime({epochMillis:toInteger(e)})),
    facts: row.facts,
    numberOfVisits: num_visits,
    weight: num_visits * website.urlPathDepth
  }]->(website)
RETURN count(r);


