/*///////////////////////
  Pre-Processing
*////////////////////////

//create named graph - project entire graph with undirected relationships
CALL gds.graph.create(
  'er-projection',
  ['User', 'Website'],
  {
    SAME_AS: {
      type: 'SAME_AS',
      orientation: 'UNDIRECTED'
    },
    CHILD_OF: {
      type: 'CHILD_OF',
      orientation: 'UNDIRECTED'
    },
    VISITED: {
      type: 'VISITED',
      orientation: 'UNDIRECTED'
    }
  }
) YIELD nodeCount, relationshipCount, createMillis;

//create fastRP embeddings based on VISITED and CHILD_OF relationships
CALL gds.fastRP.mutate(
  'er-projection',
  {
    mutateProperty: 'embedding',
    relationshipTypes: ['CHILD_OF' , 'VISITED'],
    iterationWeights: [0.0, 1.0, 0.7, 0.5, 0.5, 0.4],
    embeddingDimension: 128,
    randomSeed: 7474
  }
) YIELD nodePropertiesWritten, computeMillis;

/*///////////////////////
  Configure LP Pipeline
*////////////////////////

//create pipeline
CALL gds.alpha.ml.pipeline.linkPrediction.create('er-pipe');

//add L2 link feature
CALL gds.alpha.ml.pipeline.linkPrediction.addFeature('er-pipe', 'l2', {
  nodeProperties: ['embedding']
}) YIELD featureSteps;

//add cosine link feature
CALL gds.alpha.ml.pipeline.linkPrediction.addFeature('er-pipe', 'cosine', {
  nodeProperties: ['embedding']
}) YIELD featureSteps;

//configure data splitting
CALL gds.alpha.ml.pipeline.linkPrediction.configureSplit('er-pipe', {
  testFraction: 0.3,
  trainFraction: 0.7,
  negativeSamplingRatio: 10,
  validationFolds: 5
}) YIELD splitConfig;

//configure model parameters
CALL gds.alpha.ml.pipeline.linkPrediction.configureParams('er-pipe', [
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
  },
  {
      penalty: 1.0,
      patience: 3,
      maxEpochs: 1000,
      tolerance: 0.00001
  }
]) YIELD parameterSpace;

/*///////////////////////
  Train Model
*////////////////////////

//train the model
CALL gds.alpha.ml.pipeline.linkPrediction.train( 'er-projection', {
    modelName: 'entity-linkage-model',
    pipeline: 'er-pipe',
    randomSeed: 7474,
    concurrency: 4,
    nodeLabels: ['User'],
    relationshipTypes: ['SAME_AS'],
    negativeClassWeight: 1.0/10.0
}) YIELD modelInfo
RETURN
  modelInfo.bestParameters AS winningModel,
  modelInfo.metrics.AUCPR.outerTrain AS trainGraphScore,
  modelInfo.metrics.AUCPR.test AS testGraphScore;

// (optional) train model with true class ration approach
// changes AUCPR. See docs for more details: https://neo4j.com/docs/graph-data-science/1.8/algorithms/ml-models/linkprediction/#_class_imbalance
CALL gds.alpha.ml.pipeline.linkPrediction.train( 'er-projection', {
    modelName: 'entity-linkage-model-imb',
    pipeline: 'er-pipe',
    randomSeed: 7474,
    concurrency: 4,
    nodeLabels: ['User'],
    relationshipTypes: ['SAME_AS'],
    negativeClassWeight:11499
}) YIELD modelInfo
RETURN
  modelInfo.bestParameters AS winningModel,
  modelInfo.metrics.AUCPR.outerTrain AS trainGraphScore,
  modelInfo.metrics.AUCPR.test AS testGraphScore;