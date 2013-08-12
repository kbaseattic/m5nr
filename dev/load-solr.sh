#!/bin/bash

SOLR_DIR=$1
M5NR_VER=$2
DATA_FTP=ftp://ftp.metagenomics.anl.gov/data/M5nr/solr/v${M5NR_VER}/md5_annotations_v${M5NR_VER}.json.gz
DATA_SIZE=500000

# load as we download
cp chunk_post.pl $SOLR_DIR/example/exampledocs
cd $SOLR_DIR/example/exampledocs
wget -q -O - $DATA_FTP | zcat | ./chunk_post.pl $DATA_SIZE
