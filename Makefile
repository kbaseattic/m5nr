TOP_DIR = ../..
TOOLS_DIR = $(TOP_DIR)/tools
DEPLOY_RUNTIME ?= /kb/runtime
TARGET ?= /kb/deployment
include $(TOOLS_DIR)/Makefile.common

M5NR_VERSION = 7
SERVICE_NAME = m5nr
SERVICE_PORT = 8983
SERVICE_URL  = localhost:$(SERVICE_PORT)
SERVICE_DIR  = $(TARGET)/services/$(SERVICE_NAME)
SERVICE_STORE = /mnt/$(SERVICE_NAME)
SERVICE_DATA  = $(SERVICE_STORE)/data
TPAGE_CGI_ARGS = --define perl_path=$(DEPLOY_RUNTIME)/bin/perl --define perl_lib=$(SERVICE_DIR)/api
TPAGE_LIB_ARGS = --define m5nr_collect=$(SERVICE_NAME) --define m5nr_solr=$(SERVICE_URL)/solr --define m5nr_fasta=$(SERVICE_STORE)/md5nr
TPAGE_DEV_ARGS = --define core_name=$(SERVICE_NAME) --define host_port=$(SERVICE_PORT) --define data_dir=$(SERVICE_DATA)

# Default make target
default:
	@echo "Do nothing by default"

# Test Section
test: test-service test-client test-scripts

test-client:
	@echo "testing client (m5nr API) ..."
	test/test_web.sh localhost/m5nr.cgi client
	test/test_web.sh localhost/m5nr.cgi/m5nr m5nr

test-scripts:
	@echo "testing scripts (m5tools) ..."
	# do stuff here

test-service:
	@echo "testing service (solr API) ..."
	test/test_web.sh $(SERVICE_URL)/solr/$(SERVICE_NAME)/select service

# Deployment
all: deploy

deploy: deploy-client deploy-service

deploy-client: deploy-scripts
	@echo "Client tools deployed"

# to wrap scripts and deploy them to $(TARGET)/bin using tools in
# the dev_container. right now, these vars are defined in
# Makefile.common, so it's redundant here.
WRAP_PERL_SCRIPT = bash $(TOOLS_DIR)/$(WRAP_PERL_TOOL).sh
SRC_PERL = $(wildcard scripts/*.pl)

deploy-scripts:
	export KB_TOP=$(TARGET); \
	export KB_RUNTIME=$(DEPLOY_RUNTIME); \
	export KB_PERL_PATH=$(TARGET)/lib bash ; \
	for src in $(SRC_PERL) ; do \
		basefile=`basename $$src`; \
		base=`basename $$src .pl`; \
		echo install $$src $$base ; \
		cp $$src $(TARGET)/plbin ; \
		$(WRAP_PERL_SCRIPT) "$(TARGET)/plbin/$$basefile" $(TARGET)/bin/$$base ; \
	done

deploy-service:
	-mkdir -p $(SERVICE_DIR)
	-mkdir -p $(SERVICE_DIR)/api
	cp api/m5nr.pm $(SERVICE_DIR)/api/m5nr.pm
	$(TPAGE) $(TPAGE_LIB_ARGS) api/M5NR_Conf.pm > $(SERVICE_DIR)/api/M5NR_Conf.pm
	$(TPAGE) $(TPAGE_CGI_ARGS) api/m5nr.cgi > $(SERVICE_DIR)/api/m5nr.cgi
	$(TPAGE) --define m5nr_dir=$(SERVICE_DIR)/api conf/apache.conf.tt > /etc/apache2/sites-available/default
	chmod +x $(SERVICE_DIR)/api/m5nr.cgi
	echo "restarting apache ..."
	/etc/init.d/nginx stop
	/etc/init.d/apache2 restart
	@echo "done executing deploy-service target"

deploy-dev: build-solr load-solr build-nr
	@echo "Done deploying local M5NR data store"

build-nr:
	-mkdir -p $(SERVICE_STORE)
	cd dev; ./install-nr.sh $(SERVICE_STORE)

build-solr:
	-mkdir -p $(SERVICE_DATA)
	cd dev; ./install-solr.sh $(DEPLOY_RUNTIME)
	mv $(DEPLOY_RUNTIME)/solr/example/solr/collection1 $(DEPLOY_RUNTIME)/solr/example/solr/$(SERVICE_NAME)
	cp conf/schema.xml $(DEPLOY_RUNTIME)/solr/example/solr/$(SERVICE_NAME)/conf/schema.xml
	$(TPAGE) $(TPAGE_DEV_ARGS) conf/solrconfig.xml.tt > $(DEPLOY_RUNTIME)/solr/example/solr/$(SERVICE_NAME)/conf/solrconfig.xml
	$(TPAGE) $(TPAGE_DEV_ARGS) conf/solr.xml.tt > $(DEPLOY_RUNTIME)/solr/example/solr/solr.xml

load-solr:
	cd dev; ./load-solr.sh $(DEPLOY_RUNTIME)/solr $(M5NR_VERSION)

include $(TOOLS_DIR)/Makefile.common.rules
