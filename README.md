# Link Prediction Pipeline Demo for Cross-Device Entity Resolution
Demonstrates the application of Neo4j Link Prediction Pipelines to a Cross Device 
Entity Resolution Problem.

The source data and challenge problem for this demo can be found at: 
https://competitions.codalab.org/competitions/11171. The data is not committed here.
To work with this example, please download `data-train-dca` from the above source, unzip,
and place in a subdirectory named `./data`

This repo contains 4 scripts which can be run sequentially to reproduce the demo:

1. __prepare-data.ipynb__: Script for sampling and formatting the source data into CSVs containing Nodes and Relationships
2. __ingest.cypher__: Script for loading the prepared CSVs into a Neo4j graph
3. __model-config-and-training.cypher__: Link Prediction Pipeline configuration and model training. 
4. __prediction-and-resolution.cypher__: Predict and write new entity linkages using the trained LP model. Create and query consolidated views for resolved persons