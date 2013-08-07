#!/bin/bash

target=/kb/runtime

if [[ $# -gt 0 ]] ; then
	target=$1
	shift
fi

# install solr
wget http://apache.mirrors.hoobly.com/lucene/solr/4.4.0/solr-4.4.0.tgz
tar -xzf solr-4.4.0.tgz -C $target
ln -s $target/solr-4.4.0 $target/solr
rm solr-4.4.0.tgz

# init.d file
cp solr /etc/init.d/solr
