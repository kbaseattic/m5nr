#!/bin/bash

target=/kb/runtime

if [[ $# -gt 0 ]] ; then
	target=$1
	shift
fi

set -e
set -x

# install solr
export SOLR_VERSION="4.10.3"

wget http://apache.mirrors.hoobly.com/lucene/solr/${SOLR_VERSION}/solr-${SOLR_VERSION}.tgz
tar -xzf solr-${SOLR_VERSION}.tgz -C $target
ln -s $target/solr-${SOLR_VERSION} $target/solr
rm solr-${SOLR_VERSION}.tgz

# init.d file
tpage --define target=$target solr.tt > /etc/init.d/solr
chmod +x /etc/init.d/solr
