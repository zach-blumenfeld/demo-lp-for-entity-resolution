/*///////////////////////
  Predict & Write New Entity Linkages
*////////////////////////

//use pipeline for prediction
CALL gds.alpha.ml.pipeline.linkPrediction.predict.mutate('cikm-projection', {
  modelName: 'entity-resolution-model',
  mutateRelationshipType: 'SAME_AS_PREDICTED',
  nodeLabels: ['User'],
  relationshipTypes: ['SAME_AS'],
  topN: 20,
  threshold: 0.0
});

//write predicted relationships back to DB and delete duplicates
CALL gds.graph.writeRelationship('cikm-projection', 'SAME_AS_PREDICTED', 'probability');
// undirected relationships will have a relationship for each direction, we only need one
MATCH (n:User)-[r:SAME_AS_PREDICTED]->(m:User) WHERE id(n) < id(m) DELETE r;

//Visualize Predicted Entity Links
MATCH (n:User)-[r:SAME_AS_PREDICTED]->(m:User) RETURN n,r,m;

/*///////////////////////
  Create Resolved Person Ids
  & Query Resolved Person Views
*////////////////////////

// use Weakly Connected Components (WCC) to create resolved person ids based of given and predicted entity links
CALL gds.wcc.write(
  'cikm-projection', {
  nodeLabels: ['User'],
  writeProperty: 'personId'
  }
);

//demonstrate views of resolved persons
MATCH (n:User)-[:SAME_AS_PREDICTED]-() WITH DISTINCT n.personId AS personIdList
MATCH (n:User)-[r:VISITED]->(w:Website) WHERE n.personId IN personIdList
WITH n.personId as personId, collect({website:w.url, timeStamp: r.timeStamps[0],
                        duration: duration.inSeconds(r.timeStamps[0], last(r.timeStamps))}) AS webActivity,
                        collect(DISTINCT n.userId) as userIds
RETURN personId, webActivity, userIds;