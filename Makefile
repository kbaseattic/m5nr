TOP_DIR = ../..
TOOLS_DIR = $(TOP_DIR)/tools
DEPLOY_RUNTIME ?= /kb/runtime
TARGET ?= /kb/deployment
-include $(TOOLS_DIR)/Makefile.common

SOLR_PORT = 8983
SOLR_URL  = http://localhost:$(SOLR_PORT)
PERL_PATH = $(DEPLOY_RUNTIME)/bin/perl
M5NR_VERSION = 10
SERVICE_NAME = m5nr
SERVICE_PORT = 7103
SERVICE_URL = http://localhost:$(SERVICE_PORT)
SERVICE_DIR  = $(TARGET)/services/$(SERVICE_NAME)
SERVICE_STORE = $(BUILDROOT)/mnt/$(SERVICE_NAME)_$(M5NR_VERSION)
SERVICE_DATA  = $(SERVICE_STORE)/data
TPAGE_CGI_ARGS = --define perl_path=$(PERL_PATH) --define perl_lib=$(SERVICE_DIR)/api
TPAGE_LIB_ARGS = --define target=$(TARGET) \
--define m5nr_name=$(SERVICE_NAME) \
--define m5nr_solr=$(SOLR_URL)/solr \
--define m5nr_fasta=$(SERVICE_STORE)/md5nr \
--define api_dir=$(SERVICE_DIR)/api
TPAGE_SOLR_ARGS = --define host_port=$(SOLR_PORT) --define data_dir=$(SERVICE_DATA) --define max_bool=100000
TPAGE := $(shell which tpage)

# to run local solr in kbase env
# 	make deploy-dev
# to run outside of kbase env
# 	make standalone-m5nr PERL_PATH=<perl bin> SERVICE_STORE=<dir for large data> DEPLOY_RUNTIME=<dir to place solr> M5NR_VERSION=<m5nr version #> SERVICE_DIR=<location of service>
# to just install and load solr
# 	make standalone-solr SERVICE_STORE=<dir to place solr data> DEPLOY_RUNTIME=<dir to place solr> M5NR_VERSION=<m5nr version #>

### Default make target
default: build-scripts

### Test Section
TESTS = $(wildcard test/scripts/test_*.t)

test: test-service test-client test-scripts

test-service:
	@echo "testing service (solr API) ..."
	test/test_web.sh $(SERVICE_URL)/api.cgi service

test-client:
	@echo "testing client (m5nr API) ..."
	test/test_web.sh $(SERVICE_URL)/api.cgi/m5nr client

test-scripts:
	@echo "testing scripts ..."
	for t in $(TESTS); do \
		echo $$t; \
		$(DEPLOY_RUNTIME)/bin/perl $$t; \
		if [ $$? -ne 0 ]; then \
			exit 1; \
		fi \
	done

### Deployment
all: deploy

clean:
	-rm -rf tools
	-rm -rf support
	-rm -rf scripts
	-rm -rf docs
	-rm -rf lib
	-rm -rf api

uninstall: clean
	-/etc/init.d/solr stop
	-rm -rf $(SERVICE_STORE)
	-rm -rf $(SERVICE_DIR)
	-rm -rf $(DEPLOY_RUNTIME)/solr*

deploy: deploy-cfg | deploy-service deploy-client deploy-docs
	@echo "stoping apache ..."
	$(SERVICE_DIR)/stop_service

deploy-service: build-nr build-service
	-mkdir -p $(SERVICE_DIR)
	-mkdir -p $(SERVICE_DIR)/conf
	cp -vR api $(SERVICE_DIR)/.
	$(TPAGE) --define target=$(TARGET) service/start_service.tt > $(SERVICE_DIR)/start_service
	cp service/stop_service $(SERVICE_DIR)/stop_service
	chmod +x $(SERVICE_DIR)/start_service
	chmod +x $(SERVICE_DIR)/stop_service
	$(TPAGE) --define m5nr_dir=$(SERVICE_DIR)/api --define m5nr_api_port=$(SERVICE_PORT) config/apache.conf.tt > $(BUILDROOT)/etc/apache2/sites-available/default
	$(TPAGE) --define m5nr_dir=$(SERVICE_DIR)/api --define m5nr_api_port=$(SERVICE_PORT) config/httpd.conf.tt > $(SERVICE_DIR)/conf/httpd.conf
	@echo "restarting apache ..."
	chmod +x $(SERVICE_DIR)/start_service
	$(SERVICE_DIR)/stop_service || echo "Ignore"
	$(SERVICE_DIR)/start_service
	@echo "done executing deploy-service target"

build-service:
	-rm -rf support
	git submodule init support
	git submodule update support
	cd support; git pull origin develop
	-mkdir -p api/resources
	cp support/src/MGRAST/lib/resources/resource.pm api/resources/resource.pm
	cp support/src/MGRAST/lib/resources/m5nr.pm api/resources/m5nr.pm
	cp support/src/MGRAST/lib/GoogleAnalytics.pm api/GoogleAnalytics.pm
	$(TPAGE) $(TPAGE_LIB_ARGS) config/Conf.pm.tt > api/Conf.pm
	sed '1d' support/src/MGRAST/cgi/api.cgi | cat config/header.tt - | $(TPAGE) $(TPAGE_CGI_ARGS) > api/api.cgi
	chmod +x api/api.cgi

deploy-client: deploy-scripts | build-libs deploy-libs
	@echo "client tools deployed"

build-libs:
	-mkdir lib
	-mkdir docs
	api2js -url $(SERVICE_URL)/api.cgi -outfile docs/m5nr.json
	definition2typedef -json docs/m5nr.json -typedef docs/m5nr.typedef -service M5NR
	compile_typespec --impl M5NR --js M5NR --py M5NR docs/m5nr.typedef lib
	@echo "done building typespec libs"

build-scripts:
	-mkdir scripts
	@echo "retrieving M5NR tools"
	-rm -rf tools
	git submodule init tools
	git submodule update tools
	cd tools; git pull origin master
	sed '1d' tools/tools/bin/m5nr-tools.pl > scripts/m5nr-tools.pl
	@echo "auto-generating M5NR scripts"
	generate_commandline -template $(TOP_DIR)/template/communities.template -config config/commandline.conf -outdir scripts
	@echo "done building command line scripts"

build-docs:
	api2html -url $(SERVICE_URL)/api.cgi -site_name M5NR -outfile docs/m5nr-api.html
	pod2html --infile=lib/M5NRClient.pm --outfile=docs/M5NR.html --title="M5NR Client"

deploy-docs: build-docs
	mkdir -p $(SERVICE_DIR)/webroot
	cp docs/*.html $(SERVICE_DIR)/webroot/.
	cp docs/*.html $(SERVICE_DIR)/api/.

### all targets below are not part of standard make && make deploy

deploy-dev: build-nr | config-solr load-solr
	@echo "Done deploying local M5NR data store"

build-nr:
	-mkdir -p $(SERVICE_STORE)
	cd dev; ./install-nr.sh $(SERVICE_STORE)

install-solr:
	cd dev; ./install-solr.sh $(DEPLOY_RUNTIME)

config-solr:
	cp -av $(DEPLOY_RUNTIME)/solr/example/solr/collection1 $(DEPLOY_RUNTIME)/solr/example/solr/$(SERVICE_NAME)_$(M5NR_VERSION)
	-rm -rf $(DEPLOY_RUNTIME)/solr/example/solr/$(SERVICE_NAME)_$(M5NR_VERSION)/data
	echo "name=$(SERVICE_NAME)_$(M5NR_VERSION)" > $(DEPLOY_RUNTIME)/solr/example/solr/$(SERVICE_NAME)_$(M5NR_VERSION)/core.properties
	cp config/schema.xml $(DEPLOY_RUNTIME)/solr/example/solr/$(SERVICE_NAME)_$(M5NR_VERSION)/conf/schema.xml
	$(TPAGE) $(TPAGE_SOLR_ARGS) config/solrconfig.xml.tt > $(DEPLOY_RUNTIME)/solr/example/solr/$(SERVICE_NAME)_$(M5NR_VERSION)/conf/solrconfig.xml
	$(TPAGE) $(TPAGE_SOLR_ARGS) config/solr.xml.tt > $(DEPLOY_RUNTIME)/solr/example/solr/solr.xml

load-solr:
	-mkdir -p $(SERVICE_STORE)
	/etc/init.d/solr stop || echo "Ignore"
	sleep 3
	-rm -rf $(SERVICE_DATA)
	/etc/init.d/solr start || echo "Ignore"
	sleep 5
	cd dev; ./load-solr.sh $(DEPLOY_RUNTIME)/solr $(SOLR_PORT) $(M5NR_VERSION) $(SERVICE_NAME)

load-cached-solr:
	/etc/init.d/solr stop || echo "Ignore" # just in case
	sleep 3
	if [ ! -d $(SERVICE_DATA)/index/ ] ; then \
		mkdir -p $(SERVICE_DATA)/index/ ; \
		#curl "http://shock.metagenomics.anl.gov/node/ee38de76-5908-41ca-97d0-e3841bf84d90?download" | tar xvz -C $(SERVICE_DATA)/index/ # solr-m5nr_v1_solr_v4.10.3.tgz ; \
		curl "http://shock.metagenomics.anl.gov/node/1d7fc046-8bab-4b44-a0da-c387ee972521?download" | tar xvz -C $(SERVICE_DATA)/index/ # solr-m5nr_v10_solr_v4.10.3.tgz ; \
	fi
	


### below is for non-kbase env
dependencies:
	sudo apt-get update
	sudo apt-get -y upgrade
	sudo apt-get -y install build-essential git curl emacs bc apache2 libjson-perl libwww-perl libtemplate-perl libconfig-tiny-perl liblist-moreutils-perl openjdk-7-jre

standalone-solr: | dependencies install-solr config-solr load-solr

# this will only deploy solr if directory $(SERVICE_DATA)/index/ does not exist
standalone-cached-solr: | dependencies install-solr config-solr load-cached-solr

standalone-m5nr: standalone-solr deploy-service
	-mkdir -p $(SERVICE_DIR)/bin
	cp support/src/Babel/bin/m5nr-tools.pl $(SERVICE_DIR)/bin/.
	chmod +x $(SERVICE_DIR)/bin/*
	@echo "done installing stand alone version"

-include $(TOOLS_DIR)/Makefile.common.rules
