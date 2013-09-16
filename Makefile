TOP_DIR = ../..
TOOLS_DIR = $(TOP_DIR)/tools
DEPLOY_RUNTIME ?= /kb/runtime
TARGET ?= /kb/deployment
-include $(TOOLS_DIR)/Makefile.common

SOLR_PORT = 8983
SOLR_URL  = http://localhost:$(SOLR_PORT)
PERL_PATH = $(DEPLOY_RUNTIME)/bin/perl
M5NR_VERSION = 9
SERVICE_NAME = m5nr
SERVICE_PORT = 7103
SERVICE_DIR  = $(TARGET)/services/$(SERVICE_NAME)
SERVICE_STORE = /mnt/$(SERVICE_NAME)_$(M5NR_VERSION)
SERVICE_DATA  = $(SERVICE_STORE)/data
TPAGE_CGI_ARGS = --define perl_path=$(PERL_PATH) --define perl_lib=$(SERVICE_DIR)/api
TPAGE_LIB_ARGS = --define m5nr_name=$(SERVICE_NAME) \
--define m5nr_version=$(M5NR_VERSION) \
--define m5nr_solr=$(SOLR_URL)/solr \
--define m5nr_fasta=$(SERVICE_STORE)/md5nr \
--define api_dir=$(SERVICE_DIR)/api
TPAGE_SOLR_ARGS = --define host_port=$(SOLR_PORT) --define data_dir=$(SERVICE_DATA)
TPAGE := $(shell which tpage)

# to run local solr in kbase env
# 	make deploy-dev
# to run outside of kbase env
# 	make standalone-m5nr PERL_PATH=<perl bin> SERVICE_STORE=<dir for large data> DEPLOY_RUNTIME=<dir to place solr> M5NR_VERSION=<m5nr version #>
# to just install and load solr
# 	make standalone-solr SERVICE_STORE=<dir to place solr data> DEPLOY_RUNTIME=<dir to place solr> M5NR_VERSION=<m5nr version #>

### Default make target
default:
	@echo "Do nothing by default"

### Test Section
TESTS = $(wildcard test/scripts/test_*.t)

test: test-service test-client test-scripts

test-service:
	@echo "testing service (solr API) ..."
	test/test_web.sh $(SOLR_URL)/solr/$(SERVICE_NAME)_$(M5NR_VERSION)/select service

test-client:
	@echo "testing client (m5nr API) ..."
	test/test_web.sh http://localhost:$(SERVICE_PORT)/api.cgi client
	test/test_web.sh http://localhost:$(SERVICE_PORT)/api.cgi/m5nr m5nr

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
	apachectl stop

deploy-service: build-service
	-mkdir -p $(SERVICE_DIR)
	cp -vR api $(SERVICE_DIR)/.
	cp service/start_service $(SERVICE_DIR)/start_service
	cp service/stop_service $(SERVICE_DIR)/stop_service
	chmod +x $(SERVICE_DIR)/start_service
	chmod +x $(SERVICE_DIR)/stop_service
	$(TPAGE) --define m5nr_dir=$(SERVICE_DIR)/api --define m5nr_api_port=$(SERVICE_PORT) config/apache.conf.tt > /etc/apache2/sites-available/default
	@echo "restarting apache ..."
	apachectl restart
	@echo "done executing deploy-service target"

build-service:
	-rm -rf support
	git clone https://github.com/MG-RAST/MG-RAST.git support
	-mkdir -p api/resources
	cp support/src/MGRAST/lib/resources/resource.pm api/resources/resource.pm
	cp support/src/MGRAST/lib/resources/m5nr.pm api/resources/m5nr.pm
	cp support/src/MGRAST/lib/GoogleAnalytics.pm api/GoogleAnalytics.pm
	$(TPAGE) $(TPAGE_LIB_ARGS) config/Conf.pm.tt > api/Conf.pm
	sed '1d' support/src/MGRAST/cgi/api.cgi | cat config/header.tt - | $(TPAGE) $(TPAGE_CGI_ARGS) > api/api.cgi
	chmod +x api/api.cgi

deploy-client: | build-libs deploy-libs build-scripts deploy-scripts
	@echo "Client tools deployed"

build-libs:
	-mkdir lib
	-mkdir docs
	api2js -url http://localhost:$(SERVICE_PORT)/api.cgi -outfile docs/m5nr.json
	definition2typedef -json docs/m5nr.json -typedef docs/m5nr.typedef -service M5NR
	compile_typespec --impl M5NR --js M5NR --py M5NR docs/m5nr.typedef lib
	@echo "Done building typespec libs"

build-scripts:
	-mkdir scripts
	sed '1d' support/src/Babel/bin/m5tools.pl > scripts/nr-m5tools.pl
	generate_commandline -template $(TOP_DIR)/template/communities.template -config config/commandline.conf -outdir scripts

build-docs:
	api2html -url http://localhost:$(SERVICE_PORT)/api.cgi -site_name M5NR -outfile docs/m5nr-api.html
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
	cp config/schema.xml $(DEPLOY_RUNTIME)/solr/example/solr/$(SERVICE_NAME)_$(M5NR_VERSION)/conf/schema.xml
	$(TPAGE) $(TPAGE_SOLR_ARGS) config/solrconfig.xml.tt > $(DEPLOY_RUNTIME)/solr/example/solr/$(SERVICE_NAME)_$(M5NR_VERSION)/conf/solrconfig.xml
	$(TPAGE) $(TPAGE_SOLR_ARGS) config/solr.xml.tt > $(DEPLOY_RUNTIME)/solr/example/solr/solr.xml

load-solr:
	-mkdir -p $(SERVICE_STORE)
	/etc/init.d/solr stop
	-rm -rf $(SERVICE_DATA)
	/etc/init.d/solr start
	sleep 5
	cd dev; ./load-solr.sh $(DEPLOY_RUNTIME)/solr $(SOLR_PORT) $(M5NR_VERSION) $(SERVICE_NAME)

### below is for non-kbase env
dependencies:
	sudo apt-get update
	sudo apt-get -y upgrade
	sudo apt-get -y install build-essential git curl emacs bc apache2 libjson-perl libwww-perl libtemplate-perl openjdk-7-jre

standalone-solr: | dependencies install-solr config-solr load-solr

standalone-m5nr: standalone-solr build-nr deploy-service
	-mkdir -p $(HOME)/bin
	cp support/src/Babel/bin/m5tools.pl $(HOME)/bin/.
	chmod +x $(HOME)/bin/*
	@echo "done installing stand alone version"

-include $(TOOLS_DIR)/Makefile.common.rules
