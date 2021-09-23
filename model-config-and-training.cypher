/*///////////////////////
  Pre-Processing
*////////////////////////

//create named graph - project entire graph with undirected relationships
CALL gds.graph.create(
    'cikm-projection',
    ['User', 'Website'],
    {
      SAME_AS: {
        type: 'SAME_AS',
        orientation: 'UNDIRECTED'
      },
      CHILD_OF: {
        type: 'CHILD_OF',
        orientation: 'UNDIRECTED',
        properties: {
          weight: 'weight'
        }
      },
      VISITED: {
        type: 'VISITED',
        orientation: 'UNDIRECTED',
        properties: {
          weight: 'weight'
        }
      }
    }
);

//create fastRP embeddings based on VISITED and CHILD_OF relationships only.
CALL gds.fastRP.mutate(
  'cikm-projection',
  {
    mutateProperty: 'embedding',
    relationshipTypes: ['CHILD_OF' , 'VISITED'],
    iterationWeights: [0.0, 1.0, 0.7, 0.5, 0.5, 0.4, 0.4, 0.4],
    embeddingDimension: 128,
    randomSeed: 7474
  }
);

/*///////////////////////
  Configure LP Pipeline
*////////////////////////

//create pipeline
CALL gds.alpha.ml.pipeline.linkPrediction.create('pipe');

//add degree centrality node feature
CALL gds.alpha.ml.pipeline.linkPrediction.addNodeProperty('pipe', 'degree', {
  orientation: "UNDIRECTED",
  mutateProperty: "degreeCentrality"
})

//add L2 link feature
CALL gds.alpha.ml.pipeline.linkPrediction.addFeature('pipe', 'l2', {
  nodeProperties: ['embedding']
}) YIELD featureSteps;

//add cosine link feature
CALL gds.alpha.ml.pipeline.linkPrediction.addFeature('pipe', 'cosine', {
  nodeProperties: ['embedding']
}) YIELD featureSteps;

//configure data splitting
CALL gds.alpha.ml.pipeline.linkPrediction.configureSplit('pipe', {
  testFraction: 0.2,
  trainFraction: 0.4,
  validationFolds: 5,
  negativeSamplingRatio: 2.0
}) YIELD splitConfig;

//configure model parameters
CALL gds.alpha.ml.pipeline.linkPrediction.configureParams('pipe', [
  {
      penalty: 0.0,
      patience: 3,
      maxEpochs: 2000,
      tolerance: 0.00001
  },
  {
      penalty: 0.01,
      patience: 3,
      maxEpochs: 1000,
      tolerance: 0.00001
  }
]) YIELD parameterSpace;

/*///////////////////////
  Train Model
*////////////////////////

CALL gds.alpha.ml.pipeline.linkPrediction.train( 'cikm-projection', {
    modelName: 'entity-resolution-model',
    pipeline: 'pipe',
    randomSeed: 7474,
    concurrency: 4,
    nodeLabels: ['User'],
    relationshipTypes: ['SAME_AS'],
    negativeClassWeight: 1.0/2.0
}) YIELD modelInfo
RETURN
  modelInfo.bestParameters AS winningModel,
  modelInfo.metrics.AUCPR.outerTrain AS trainGraphScore,
  modelInfo.metrics.AUCPR.test AS testGraphScore;