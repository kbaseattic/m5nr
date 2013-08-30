TOP_DIR = ../..
TOOLS_DIR = $(TOP_DIR)/tools
DEPLOY_RUNTIME ?= /kb/runtime
TARGET ?= /kb/deployment
-include $(TOOLS_DIR)/Makefile.common

PERL_PATH = $(DEPLOY_RUNTIME)/bin/perl
M5NR_VERSION = 9
SERVICE_NAME = m5nr
SERVICE_PORT = 8983
SERVICE_URL  = http://localhost:$(SERVICE_PORT)
SERVICE_DIR  = $(TARGET)/services/$(SERVICE_NAME)
SERVICE_STORE = /mnt/$(SERVICE_NAME)
SERVICE_DATA  = $(SERVICE_STORE)/data
TPAGE_CGI_ARGS = --define perl_path=$(PERL_PATH) --define perl_lib=$(SERVICE_DIR)/api
TPAGE_LIB_ARGS = --define m5nr_collect=$(SERVICE_NAME) \
--define m5nr_solr=$(SERVICE_URL)/solr \
--define m5nr_fasta=$(SERVICE_STORE)/md5nr \
--define api_dir=$(SERVICE_DIR)/api
TPAGE_DEV_ARGS = --define core_name=$(SERVICE_NAME) \
--define host_port=$(SERVICE_PORT) \
--define data_dir=$(SERVICE_DATA)
TPAGE := $(shell which tpage)

# to run local solr in kbase env
# 	make deploy-dev
# to run outside of kbase env
# 	make standalone PERL_PATH=<perl bin> SERVICE_STORE=<dir for large data> DEPLOY_RUNTIME=<dir to place solr>
# to just install and load solr
# 	make dependencies
# 	make deploy-solr SERVICE_STORE=<dir to place solr data> DEPLOY_RUNTIME=<dir to place solr> M5NR_VERSION=<m5nr version #>

# Default make target
default:
	@echo "Do nothing by default"

# Test Section
test: test-service test-client test-scripts

test-client:
	@echo "testing client (m5nr API) ..."
	test/test_web.sh http://localhost/api.cgi client
	test/test_web.sh http://localhost/api.cgi/m5nr m5nr

test-scripts:
	@echo "testing scripts (m5tools) ..."
	# do stuff here

test-service:
	@echo "testing service (solr API) ..."
	test/test_web.sh $(SERVICE_URL)/solr/$(SERVICE_NAME)/select service

# Deployment
all: deploy

clean:
	-rm -rf support
	-rm -rf temp
	-rm -rf lib
	-rm -rf api

uninstall: clean
	-/etc/init.d/solr stop
	-rm -rf $(SERVICE_STORE)
	-rm -rf $(SERVICE_DIR)
	-rm -rf $(DEPLOY_RUNTIME)/solr*

deploy: deploy-service deploy-client deploy-docs

deploy-service: build-service
	-mkdir -p $(SERVICE_DIR)
	cp -vR api $(SERVICE_DIR)/.
	$(TPAGE) --define m5nr_dir=$(SERVICE_DIR)/api conf/apache.conf.tt > /etc/apache2/sites-available/default
	echo "restarting apache ..."
	-/etc/init.d/nginx stop
	/etc/init.d/apache2 restart
	@echo "done executing deploy-service target"

build-service:
	git clone https://github.com/MG-RAST/MG-RAST.git support
	-mkdir -p api/resources
	cp support/src/MGRAST/lib/resources/resource.pm api/resources/resource.pm
	cp support/src/MGRAST/lib/resources/m5nr.pm api/resources/m5nr.pm
	cp support/src/MGRAST/lib/GoogleAnalytics.pm api/GoogleAnalytics.pm
	$(TPAGE) $(TPAGE_LIB_ARGS) conf/Conf.pm > api/Conf.pm
	sed '1d' support/src/MGRAST/cgi/api.cgi | cat conf/header - | $(TPAGE) $(TPAGE_CGI_ARGS) > api/api.cgi
	chmod +x api/api.cgi

deploy-client: build-libs deploy-libs build-scripts deploy-scripts
	@echo "Client tools deployed"

build-libs:
	-mkdir lib
	-mkdir temp
	perl support/bin/api2js.pl -url http://localhost/api.cgi -outfile temp/m5nr.json
	perl support/bin/definition2typedef.pl -json temp/m5nr.json -typedef temp/m5nr.typedef
	compile_typespec --impl M5NR --js M5NR --py M5NR temp/m5nr.typedef lib
	@echo "Done building typespec libs"

build-scripts:
	-mkdir scripts
	cp support/src/Babel/bin/m5tools.pl scripts/m5tools.pl

deploy-docs:
	perl support/bin/api2html.pl -url http://localhost/api.cgi -site_name M5NR -outfile temp/api.html
	cp temp/api.html $(SERVICE_DIR)/api/api.html

deploy-dev: deploy-solr build-nr
	@echo "Done deploying local M5NR data store"

build-nr:
	-mkdir -p $(SERVICE_STORE)
	cd dev; ./install-nr.sh $(SERVICE_STORE)

deploy-solr: build-solr load-solr

build-solr:
	cd dev; ./install-solr.sh $(DEPLOY_RUNTIME)
	mv $(DEPLOY_RUNTIME)/solr/example/solr/collection1 $(DEPLOY_RUNTIME)/solr/example/solr/$(SERVICE_NAME)
	cp conf/schema.xml $(DEPLOY_RUNTIME)/solr/example/solr/$(SERVICE_NAME)/conf/schema.xml
	$(TPAGE) $(TPAGE_DEV_ARGS) conf/solrconfig.xml.tt > $(DEPLOY_RUNTIME)/solr/example/solr/$(SERVICE_NAME)/conf/solrconfig.xml
	$(TPAGE) $(TPAGE_DEV_ARGS) conf/solr.xml.tt > $(DEPLOY_RUNTIME)/solr/example/solr/solr.xml

load-solr:
	/etc/init.d/solr start
	sleep 3
	cd dev; ./load-solr.sh $(DEPLOY_RUNTIME)/solr $(M5NR_VERSION)

# this is for non-kbase env
dependencies:
	sudo apt-get update
	sudo apt-get -y upgrade
	sudo apt-get -y install build-essential git curl emacs bc apache2 libjson-perl libwww-perl libtemplate-perl openjdk-7-jre

standalone: dependencies deploy-dev deploy-service deploy-docs
	-mkdir -p $(SERVICE_DIR)/bin
	cp scripts/* $(SERVICE_DIR)/bin/.
	chmod +x $(SERVICE_DIR)/bin/*
	@echo "done installing stand alone version"

-include $(TOOLS_DIR)/Makefile.common.rules
