#!/bin/bash

SOLR_DIR=$1
M5NR_VER=$2
FILES=(source ontology taxonomy annotation)
DATA_FTP=ftp://ftp.metagenomics.anl.gov/data/M5nr/solr/v${M5NR_VER}
DATA_SIZE=500000

# load as we download
cp chunk_post.pl $SOLR_DIR/example/exampledocs
cd $SOLR_DIR/example/exampledocs
for F in ${FILES[@]}; do
    wget -q -O - ${DATA_FTP}/m5nr_v${M5NR_VER}.${F}.gz | zcat | ./chunk_post.pl $DATA_SIZE
