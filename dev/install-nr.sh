#!/bin/bash

DATA_DIR=$1
DATA_FTP=ftp://ftp.metagenomics.anl.gov/data/MD5nr/current/md5nr_blast.tar.gz

cd $DATA_DIR
wget $DATA_FTP
tar -zxvf md5nr_blast.tar.gz
