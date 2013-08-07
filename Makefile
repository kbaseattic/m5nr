TOP_DIR = ../..
DEPLOY_RUNTIME ?= /kb/runtime
TARGET ?= /kb/deployment
include $(TOP_DIR)/tools/Makefile.common

M5NR_VERSION = 7
SERVICE_NAME = m5nr
SERVICE_PORT = 8983
SERVICE_DIR  = $(TARGET)/services/$(SERVICE_NAME)
SERVICE_DATA = /mnt/$(SERVICE_NAME)/data

TPAGE_DEV_ARGS = --define core_name=$(SERVICE_NAME) --define host_port=$(SERVICE_PORT) --define data_dir=$(SERVICE_DATA)
TPAGE_ARGS = --define kb_top=$(TARGET) --define kb_runtime=$(DEPLOY_RUNTIME) --define kb_service_name=$(SERVICE_NAME) --define kb_service_dir=$(SERVICE_DIR) --define kb_service_port=$(SERVICE_PORT)

# Default make target

default:
	@echo "Do nothing by default"

# Test Section
TESTS = $(wildcard test/*.t)

test: test-client test-scripts test-service
	@echo "running client and script tests"

# test-all is deprecated. 
# test-all: test-client test-scripts test-service
#
# test-client: This is a test of a client library. If it is a
# client-server module, then it should be run against a running
# server. You can say that this also tests the server, and I
# agree. You can add a test-service dependancy to the test-client
# target if it makes sense to you. This test example assumes there is
# already a tested running server.
test-client:
	# run each test
	for t in $(CLIENT_TESTS) ; do \
		if [ -f $$t ] ; then \
			$(DEPLOY_RUNTIME)/bin/perl $$t ; \
			if [ $$? -ne 0 ] ; then \
				exit 1 ; \
			fi \
		fi \
	done

# test-scripts: A script test should test the command line scripts. If
# the script is a client in a client-server architecture, then there
# should be tests against a running server. You can add a test-service
# dependency to the test-client target. You could also add a
# deploy-service and start-server dependancy to the test-scripts
# target if it makes sense to you. Future versions of the makefiles
# for services will move in this direction.
test-scripts:
	# run each test
	for t in $(SCRIPT_TESTS) ; do \
		if [ -f $$t ] ; then \
			$(DEPLOY_RUNTIME)/bin/perl $$t ; \
			if [ $$? -ne 0 ] ; then \
				exit 1 ; \
			fi \
		fi \
	done

# test-service: A server test should not rely on the client libraries
# or scripts--you should not have a test-service target that depends
# on the test-client or test-scripts targets. Otherwise, a circular
# dependency graph could result.
test-service:
	# run each test
	for t in $(SERVER_TESTS) ; do \
		if [ -f $$t ] ; then \
			$(DEPLOY_RUNTIME)/bin/perl $$t ; \
			if [ $$? -ne 0 ] ; then \
				exit 1 ; \
			fi \
		fi \
	done

# Deployment:
# 
# We are assuming our primary products to the community are
# client side application programming interface libraries and a
# command line interface (scripts). The deployment of client
# artifacts should not be dependent on deployment of a server,
# although we recommend deploying the server code with the
# client code when the deploy target is executed. If you have
# good reason not to deploy the server at the same time as the
# client, just delete the dependancy on deploy-service. It is
# important to note that you must have a deploy-service target
# even if there is no server side code to deploy.

all: deploy

deploy: deploy-client deploy-service

# deploy-client should deploy the client artifacts, mainly
# the application programming interface libraries, command
# line scripts, and associated reference documentation.

deploy-client: deploy-libs deploy-scripts deploy-docs

# The deploy-libs and deploy-scripts targets are used to recognize
# and delineate the client types, mainly a set of libraries that
# implement an application programming interface and a set of 
# command line scripts that provide command-based execution of
# individual API functions and aggregated sets of API functions.

deploy-libs: build-libs
	rsync --exclude '*.bak*' -arv lib/. $(TARGET)/lib/.

# Deploying scripts needs some special care. They need to run
# in a certain runtime environment. Users should not have
# to modify their user environments to run kbase scripts, other
# than just sourcing a single user-env script. The creation
# of this user-env script is the responsibility of the code
# that builds all the kbase modules. In the code below, we
# run a script in the dev_container tools directory that 
# wraps perl scripts. The name of the perl wrapper script is
# kept in the WRAP_PERL_SCRIPT make variable. This script
# requires some information that is passed to it by way
# of exported environment variables in the bash script below.
#
# What does it mean to wrap a perl script? To wrap a perl
# script means that a bash script is created that sets
# all required environment variables and then calls the perl
# script using the perl interperter in the kbase runtime.
# For this to work, both the actual script and the newly 
# created shell script have to be deployed. When a perl
# script is wrapped, it is first copied to TARGET/plbin.
# The shell script can now be created because the necessary
# environment variables are known and the location of the
# script is known. 

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

# Deploying a service refers to to deploying the capability
# to run a service. Becuase service code is often deployed 
# as part of the libs, meaning service code gets deployed
# when deploy-libs is called, the deploy-service target is
# generally concerned with the service start and stop scripts.
# The deploy-cfg target is defined in the common rules file
# located at $TOP_DIR/tools/Makefile.common.rules and included
# at the end of this file.

deploy-service:
	-mkdir -p $(SERVICE_DIR)
	-mkdir -p $(SERVICE_DIR)/api
	cp api/* $(SERVICE_DIR)/api/.
	$(TPAGE) --define m5nr_dir=$(SERVICE_DIR)/api conf/nginx.conf.tt > /etc/nginx/sites-available/default
	echo "restarting nginx ..."
	/etc/init.d/nginx restart
	/etc/init.d/nginx force-reload
	echo "done executing deploy-service target"

deploy-dev:
	-mkdir -p $(SERVICE_DATA)
	cd dev; ./install-solr.sh $(DEPLOY_RUNTIME)
	mv $(DEPLOY_RUNTIME)/solr/example/solr/collection1 $(DEPLOY_RUNTIME)/solr/example/solr/$(SERVICE_NAME)
	cp conf/schema.xml $(DEPLOY_RUNTIME)/solr/example/solr/$(SERVICE_NAME)/conf/schema.xml
	$(TPAGE) $(TPAGE_DEV_ARGS) conf/solrconfig.xml.tt > $(DEPLOY_RUNTIME)/solr/example/solr/$(SERVICE_NAME)/conf/solrconfig.xml
	$(TPAGE) $(TPAGE_DEV_ARGS) conf/solr.xml.tt > $(DEPLOY_RUNTIME)/solr/example/solr/solr.xml
	cd dev; ./load-m5nr.sh $(DEPLOY_RUNTIME)/solr $(SERVICE_DATA) $(M5NR_VERSION)

# Deploying docs here refers to the deployment of documentation
# of the API. We'll include a description of deploying documentation
# of command line interface scripts when we have a better understanding of
# how to standardize and automate CLI documentation.

deploy-docs: build-docs
	-mkdir -p $(TARGET)/services/$(SERVICE_DIR)/webroot/.
	cp docs/*.html $(TARGET)/services/$(SERVICE_DIR)/webroot/.

# The location of the Client.pm file depends on the --client param
# that is provided to the compile_typespec command. The
# compile_typespec command is called in the build-libs target.

build-docs: compile-docs
	pod2html --infile=lib/Bio/KBase/$(SERVICE_NAME)/Client.pm --outfile=docs/$(SERVICE_NAME).html

# Use the compile-docs target if you want to unlink the generation of
# the docs from the generation of the libs. Not recommended, but there
# could be a reason for it that I'm not seeing.
# The compile-docs target should depend on build-libs so that we are
# assured of having a set of documentation that is based on the latest
# type spec.

compile-docs: build-libs

# build-libs should be dependent on the type specification and the
# type compiler. Building the libs in this way means that you don't
# need to put automatically generated code in a source code version
# control repository (e.g., cvs, git). It also ensures that you always
# have the most up-to-date libs and documentation if your compile-docs
# target depends on the compiled libs.

build-libs:
	compile_typespec \
		--psgi $(SERVICE_PSGI)  \
		--impl Bio::KBase::$(SERVICE_NAME)::$(SERVICE_NAME)Impl \
		--service Bio::KBase::$(SERVICE_NAME)::Service \
		--client Bio::KBase::$(SERVICE_NAME)::Client \
		--py biokbase/$(SERVICE_NAME)/Client \
		--js javascript/$(SERVICE_NAME)/Client \
		$(SERVICE_SPEC) lib

# the Makefile.common.rules contains a set of rules that can be used
# in this setup. Because it is included last, it has the effect of
# shadowing any targets defined above. So lease be aware of the
# set of targets in the common rules file.
include $(TOP_DIR)/tools/Makefile.common.rules
