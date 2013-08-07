TOP_DIR = ../..
TOOLS_DIR = $(TOP_DIR)/tools
DEPLOY_RUNTIME ?= /kb/runtime
TARGET ?= /kb/deployment
include $(TOOLS_DIR)/Makefile.common

M5NR_VERSION = 7
SERVICE_NAME = m5nr
SERVICE_PORT = 8983
SERVICE_DIR  = $(TARGET)/services/$(SERVICE_NAME)
SERVICE_DATA = /mnt/$(SERVICE_NAME)/data
TPAGE_DEV_ARGS = --define core_name=$(SERVICE_NAME) --define host_port=$(SERVICE_PORT) --define data_dir=$(SERVICE_DATA)

# Default make target
default:
	@echo "Do nothing by default"

# Test Section
TESTS = $(wildcard test/*.t)

test:
	# run each test
	for t in $(TESTS) ; do \
		if [ -f $$t ] ; then \
			$(DEPLOY_RUNTIME)/bin/perl $$t ; \
			if [ $$? -ne 0 ] ; then \
				exit 1 ; \
			fi \
		fi \
	done

# Deployment
all: deploy

deploy: deploy-client deploy-service

deploy-client: deploy-scripts
	@echo "Client tool deployed"

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
	cp api/* $(SERVICE_DIR)/api/.
	$(TPAGE) --define m5nr_dir=$(SERVICE_DIR)/api conf/nginx.conf.tt > /etc/nginx/sites-available/default
	echo "restarting nginx ..."
	/etc/init.d/nginx restart
	/etc/init.d/nginx force-reload
	echo "done executing deploy-service target"

deploy-dev: install-solr load-m5nr

install-solr:
	-mkdir -p $(SERVICE_DATA)
	cd dev; ./install-solr.sh $(DEPLOY_RUNTIME)
	mv $(DEPLOY_RUNTIME)/solr/example/solr/collection1 $(DEPLOY_RUNTIME)/solr/example/solr/$(SERVICE_NAME)
	cp conf/schema.xml $(DEPLOY_RUNTIME)/solr/example/solr/$(SERVICE_NAME)/conf/schema.xml
	$(TPAGE) $(TPAGE_DEV_ARGS) conf/solrconfig.xml.tt > $(DEPLOY_RUNTIME)/solr/example/solr/$(SERVICE_NAME)/conf/solrconfig.xml
	$(TPAGE) $(TPAGE_DEV_ARGS) conf/solr.xml.tt > $(DEPLOY_RUNTIME)/solr/example/solr/solr.xml

load-m5nr:
	cd dev; ./load-m5nr.sh $(DEPLOY_RUNTIME)/solr $(SERVICE_DATA) $(M5NR_VERSION)

include $(TOOLS_DIR)/Makefile.common.rules
