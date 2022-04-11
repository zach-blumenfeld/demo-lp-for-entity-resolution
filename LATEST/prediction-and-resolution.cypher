/*///////////////////////
  Predict & Write New Entity Linkages
*////////////////////////

// Use pipeline for prediction
CALL gds.beta.pipeline.linkPrediction.predict.mutate(
  'er-projection',
  {
    modelName: 'entity-linkage-model',
    mutateRelationshipType: 'SAME_AS_PREDICTED',
    nodeLabels: ['User'],
    relationshipTypes: ['SAME_AS'],
    topN: 20,
    threshold: 0.0
  }
);

// Write predicted relationships back to DB and delete duplicates
// reference - https://neo4j.com/docs/graph-data-science/current/graph-catalog-relationship-ops/#catalog-graph-write-relationship-example
CALL gds.graph.writeRelationship('er-projection', 'SAME_AS_PREDICTED', 'probability');

// Undirected relationships will have a relationship for each direction, we only need one
MATCH (n:User)-[r:SAME_AS_PREDICTED]->(m:User) WHERE id(n) < id(m) DELETE r;

// Visualize Predicted Entity Links
MATCH (n:User)-[r:SAME_AS_PREDICTED]->(m:User) RETURN n,r,m;

// Show predicted entity links ordered by probability
MATCH (u1:User)-[r:SAME_AS_PREDICTED]->(u2:User)
RETURN u1.userId AS user1, u2.userId AS user2, r.probability as entityLinkageProbability
ORDER BY entityLinkageProbability DESC;

/*///////////////////////
  Create Resolved Person Ids
*////////////////////////

// Use Weakly Connected Components (WCC) to create resolved person ids based of given and predicted entity links
// reference - https://neo4j.com/docs/graph-data-science/current/algorithms/wcc/#algorithms-wcc-syntax
CALL gds.wcc.write(
  'er-projection',
  {
    nodeLabels: ['User'],
    writeProperty: 'personId'
  }
) YIELD componentCount, nodePropertiesWritten, writeMillis, computeMillis;

/*///////////////////////
  Query Resolved Person Views
*////////////////////////

// Get all resolved persons who have a newly predicted entity link
MATCH (n:User)-[:SAME_AS_PREDICTED]-()
WITH DISTINCT n.personId AS personIdList
// Get all browsing activity for those persons
MATCH (n:User)-[r:VISITED]->(w:Website)
WHERE n.personId IN personIdList
// Return each person with userIds and summary browsing activity
WITH n.personId as personId,
     collect(
        {
          website:w.url,
          firstTimeStamp: r.timeStamps[0],
          lastTimeStamp: last(r.timeStamps)
        }
     ) AS webActivity,
     collect(DISTINCT n.userId) AS userIds
RETURN personId, webActivity, userIds
ORDER BY personId DESC;