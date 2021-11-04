# Link Prediction Pipeline Demo for Cross-Device Entity Resolution
Demonstrates the application of Neo4j Link Prediction Pipelines to a Cross Device 
Entity Resolution Problem.

The source data and challenge problem for this demo can be found at: 
https://competitions.codalab.org/competitions/11171. The data is not committed here.
To work with this example, please download `data-train-dca` from the above source, unzip,
and place in a subdirectory named `./data`

This repo contains 4 scripts which can be run sequentially to reproduce the demo. The first is a Python notebook and
the following three are scripts with commands that you can run in Neo4j browser.

1. __prepare-data.ipynb__: Script for sampling and formatting the source data into CSVs containing Nodes and Relationships
2. __ingest.cypher__: Script for loading the prepared CSVs into a Neo4j graph. Make sure to move the CSVs to the
Neo4j import directory.  See documentation [here](https://neo4j.com/developer/guide-import-csv/#_reading_csv_files) 
for details. 
3. __model-config-and-training.cypher__: Link Prediction Pipeline configuration and model training. 
4. __prediction-and-resolution.cypher__: Predict and write new entity linkages using the trained LP model.
Create and query consolidated views for resolved persons.

## Prerequisites:
 - Notebook uses Python=3.9.7
 - Neo4j Desktop >=1.4.8 & Graph Data Science (GDS) Library >=1.7.2
