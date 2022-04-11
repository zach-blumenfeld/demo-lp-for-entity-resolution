/*///////////////////////
  Pre-Processing
*////////////////////////

// Project named graph - project entire graph with undirected relationships
// reference - https://neo4j.com/docs/graph-data-science/current/graph-project/#graph-project-native-syntax
CALL gds.graph.project(
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

// Mutate the graph projection with fastRP embeddings based on VISITED and CHILD_OF relationships
// reference - https://neo4j.com/docs/graph-data-science/current/machine-learning/node-embeddings/fastrp/#algorithms-embeddings-fastrp-syntax
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

// Create Link Prediction Pipeline
// reference - https://neo4j.com/docs/graph-data-science/current/machine-learning/node-embeddings/fastrp/#algorithms-embeddings-fastrp-syntax
CALL gds.beta.pipeline.linkPrediction.create('er-pipe');

// Add L2 link feature
// reference - https://neo4j.com/docs/graph-data-science/current/machine-learning/linkprediction-pipelines/#_syntax_3
CALL gds.beta.pipeline.linkPrediction.addFeature(
  'er-pipe',
  'l2',
  {
    nodeProperties: ['embedding']
  }
) YIELD featureSteps;

// Add cosine link feature
// reference - https://neo4j.com/docs/graph-data-science/current/machine-learning/linkprediction-pipelines/#_syntax_3
CALL gds.beta.pipeline.linkPrediction.addFeature(
  'er-pipe',
  'cosine',
  {
    nodeProperties: ['embedding']
  }
) YIELD featureSteps;

// Configure relationship splits
// reference - https://neo4j.com/docs/graph-data-science/current/machine-learning/linkprediction-pipelines/#_syntax_4
CALL gds.beta.pipeline.linkPrediction.configureSplit(
  'er-pipe',
  {
    testFraction: 0.3,
    trainFraction: 0.7,
    negativeSamplingRatio: 10,
    validationFolds: 5
  }
) YIELD splitConfig;

// Configure model parameters
// reference - https://neo4j.com/docs/graph-data-science/current/appendix-b/migration-ml/
CALL gds.beta.pipeline.linkPrediction.addLogisticRegression(
  'er-pipe',
  {
    penalty: 0.0,
    patience: 3,
    maxEpochs: 2000,
    tolerance: 0.00001
  }
) YIELD parameterSpace;

CALL gds.beta.pipeline.linkPrediction.addLogisticRegression(
  'er-pipe',
  {
    penalty: 0.01,
    patience: 3,
    maxEpochs: 1000,
    tolerance: 0.00001
  }
) YIELD parameterSpace;

CALL gds.beta.pipeline.linkPrediction.addLogisticRegression(
  'er-pipe',
  {
    penalty: 1.0,
    patience: 3,
    maxEpochs: 1000,
    tolerance: 0.00001
  }
) YIELD parameterSpace;

/*///////////////////////
  Train Model
*////////////////////////

// Train the model
// reference - https://neo4j.com/docs/graph-data-science/current/machine-learning/linkprediction-pipelines/#_syntax_6
CALL gds.beta.pipeline.linkPrediction.train(
  'er-projection',
  {
    modelName: 'entity-linkage-model',
    pipeline: 'er-pipe',
    randomSeed: 7474,
    concurrency: 4,
    nodeLabels: ['User'],
    relationshipTypes: ['SAME_AS'],
    negativeClassWeight: 1.0/10.0
  }
) YIELD modelInfo
RETURN
    modelInfo.bestParameters AS winningModel,
    modelInfo.metrics.AUCPR.outerTrain AS trainGraphScore,
    modelInfo.metrics.AUCPR.test AS testGraphScore;

// (Optional) Train model with true class ration approach
// changes AUCPR. See docs for more details: https://neo4j.com/docs/graph-data-science/current/algorithms/ml-models/linkprediction/#_class_imbalance
CALL gds.beta.pipeline.linkPrediction.train(
  'er-projection',
  {
    modelName: 'entity-linkage-model-imb',
    pipeline: 'er-pipe',
    randomSeed: 7474,
    concurrency: 4,
    nodeLabels: ['User'],
    relationshipTypes: ['SAME_AS'],
    negativeClassWeight:11499
  }
) YIELD modelInfo
RETURN
    modelInfo.bestParameters AS winningModel,
    modelInfo.metrics.AUCPR.outerTrain AS trainGraphScore,
    modelInfo.metrics.AUCPR.test AS testGraphScore;