SHELL := /bin/bash
PREFIX ?=
SYSCONF ?= etc
INSTALL_DIR = usr/share

PYTHON_SITELIB ?= usr/lib/python2.7/site-packages
PYTHON_INST_DIR = $(PREFIX)/$(PYTHON_SITELIB)/subscription-manager

OS = $(shell lsb_release -i | awk '{ print $$3 }' | awk -F. '{ print $$1}')
OS_VERSION = $(shell lsb_release -r | awk '{ print $$2 }' | awk -F. '{ print $$1}')
OS_DIST ?= $(shell rpm --eval='%dist')

# Where various bits of code live in the git repo
SRC_DIR := src/subscription_manager
RCT_SRC_DIR := src/rct
RHSM_ICON_SRC_DIR := src/rhsm_icon
DAEMONS_SRC_DIR := src/daemons
CONTENT_PLUGINS_SRC_DIR := src/content_plugins/

ANACONDA_ADDON_NAME = com_redhat_subscription_manager
ANACONDA_ADDON_MODULE_SRC_DIR := src/initial-setup/$(ANACONDA_ADDON_NAME)

# dirs we install to
SYSTEMD_INST_DIR := $(PREFIX)/usr/lib/systemd/system
RHSM_PLUGIN_DIR := $(PREFIX)/usr/share/rhsm-plugins/
RHSM_PLUGIN_CONF_DIR := $(PREFIX)/etc/rhsm/pluginconf.d/
ANACONDA_ADDON_INST_DIR := $(PREFIX)/usr/share/anaconda/addons
INITIAL_SETUP_INST_DIR := $(ANACONDA_ADDON_INST_DIR)/$(ANACONDA_ADDON_NAME)

# If we skip install ostree plugin, unset by default
# override from spec file for rhel6
INSTALL_OSTREE_PLUGIN ?= true

# Default differences between el6 and el7
ifeq ($(OS_DIST),.el6)
   GTK_VERSION?=2
   FIRSTBOOT_MODULES_DIR?=$(PREFIX)/usr/share/rhn/up2date_client/firstboot
   INSTALL_FIRSTBOOT?=true
   INSTALL_INITIAL_SETUP?=false
else
   GTK_VERSION?=3
   FIRSTBOOT_MODULES_DIR?=$(PREFIX)/usr/share/firstboot/modules
   INSTALL_FIRSTBOOT?=true
   INSTALL_INITIAL_SETUP?=true
endif

# always true until fedora is just dnf
INSTALL_YUM_PLUGINS ?= true
YUM_PLUGINS_SRC_DIR := src/plugins

# for fc22 or newer
INSTALL_DNF_PLUGINS ?= false
DNF_PLUGINS_SRC_DIR := src/plugins

# sets a version that is more or less latest tag plus commit sha
VERSION ?= $(shell git describe | awk ' { sub(/subscription-manager-/,"")};1' )

# inherit from env if set so rpm can override
CFLAGS ?= -g -Wall
LDFLAGS ?=

RHSMCERTD_FLAGS = `pkg-config --cflags --libs glib-2.0`
ICON_FLAGS=`pkg-config --cflags --libs "gtk+-$(GTK_VERSION).0 libnotify gconf-2.0 dbus-glib-1"`

PYFILES := `find src/ test/ -name "*.py"`
BIN_FILES := bin/subscription-manager bin/subscription-manager-gui \
			 bin/rhn-migrate-classic-to-rhsm \
			 bin/rct \
			 bin/rhsm-debug
STYLEFILES=$(PYFILES) $(BIN_FILES)

# we never "remake" this makefile, so add a target so
# we stop searching for implicit rules on how to remake it
Makefile: ;

build: set-versions rhsmcertd rhsm-icon
	./setup.py build

.PHONY: clean-versions
clean-versions:
	rm -rf $(SRC_DIR)/version.py
	rm -rf $(RCT_SRC_DIR)/version.py

.PHONY: clean
clean: clean-versions
	rm -f *.pyc *.pyo *~ *.bak *.tar.gz
	rm -f bin/rhsmcertd
	rm -f bin/rhsm-icon
	./setup.py clean --all

rhsmcertd: $(DAEMONS_SRC_DIR)/rhsmcertd.c
	$(CC) $(CFLAGS) $(LDFLAGS) $(RHSMCERTD_FLAGS) $(DAEMONS_SRC_DIR)/rhsmcertd.c -o bin/rhsmcertd

rhsm-icon: $(RHSM_ICON_SRC_DIR)/rhsm_icon.c
	$(CC) $(CFLAGS) $(LDFLAGS) $(ICON_FLAGS) $(RHSM_ICON_SRC_DIR)/rhsm_icon.c -o bin/rhsm-icon

.PHONY: check-syntax
check-syntax:
	$(CC) -fsyntax-only $(CFLAGS) $(LDFLAGS) $(ICON_FLAGS) `find -name '*.c'`

.PHONY: dbus-service-install
dbus-service-install:
	install -d $(PREFIX)/etc/dbus-1/system.d
	install -d $(PREFIX)/$(INSTALL_DIR)/dbus-1/system-services
	install -d $(PREFIX)/usr/libexec
	install -m 644 etc-conf/com.redhat.SubscriptionManager.conf \
		$(PREFIX)/etc/dbus-1/system.d
	install -m 644 etc-conf/com.redhat.SubscriptionManager.service \
		$(PREFIX)/$(INSTALL_DIR)/dbus-1/system-services
	install -m 744 $(DAEMONS_SRC_DIR)/rhsm_d.py \
		$(PREFIX)/usr/libexec/rhsmd

.PHONY: install-conf
install-conf:
	install -d $(PREFIX)/etc/{cron.daily,logrotate.d,pam.d,bash_completion.d,rhsm}
	install -d $(PREFIX)/etc/rc.d/init.d
	install -d $(PREFIX)/etc/rhsm/facts
	install -d $(PREFIX)/etc/security/console.apps
	install -m 644 etc-conf/rhsm.conf $(PREFIX)/etc/rhsm/
	install -m 644 etc-conf/logrotate.conf $(PREFIX)/etc/logrotate.d/subscription-manager
	install -m 644 etc-conf/logging.conf $(PREFIX)/etc/rhsm/logging.conf
	install -m 644 etc-conf/subscription-manager.completion.sh $(PREFIX)/etc/bash_completion.d/subscription-manager
	install -m 644 etc-conf/rct.completion.sh $(PREFIX)/etc/bash_completion.d/rct
	install -m 644 etc-conf/rhsm-debug.completion.sh $(PREFIX)/etc/bash_completion.d/rhsm-debug
	install -m 644 etc-conf/rhn-migrate-classic-to-rhsm.completion.sh $(PREFIX)/etc/bash_completion.d/rhn-migrate-classic-to-rhsm
	install -m 644 etc-conf/subscription-manager-gui.completion.sh $(PREFIX)/etc/bash_completion.d/subscription-manager-gui
	install -m 644 etc-conf/rhsm-icon.completion.sh $(PREFIX)/etc/bash_completion.d/rhsm-icon
	install -m 644 etc-conf/rhsmcertd.completion.sh $(PREFIX)/etc/bash_completion.d/rhsmcertd
	install -d $(PREFIX)/usr/share/appdata
	install -m 644 etc-conf/subscription-manager-gui.appdata.xml $(PREFIX)/$(INSTALL_DIR)/appdata/subscription-manager-gui.appdata.xml

.PHONY: install-plugins
install-plugins:
	install -d $(RHSM_PLUGIN_DIR)
	install -d $(RHSM_PLUGIN_CONF_DIR)
	install -d $(PREFIX)/etc/rhsm/ca
	install -m 644 -p etc-conf/redhat-entitlement-authority.pem $(PREFIX)/etc/rhsm/ca/redhat-entitlement-authority.pem

	# ostree stuff
	if [ "$(INSTALL_OSTREE_PLUGIN)" = "true" ] ; then \
		install -m 644 -p \
		$(CONTENT_PLUGINS_SRC_DIR)/ostree_content.OstreeContentPlugin.conf \
		$(RHSM_PLUGIN_CONF_DIR) ; \
		install -m 644 $(CONTENT_PLUGINS_SRC_DIR)/ostree_content.py $(RHSM_PLUGIN_DIR) ; \
	fi;
	# container stuff
	install -m 644 -p \
		$(CONTENT_PLUGINS_SRC_DIR)/container_content.ContainerContentPlugin.conf \
		$(RHSM_PLUGIN_CONF_DIR)
	install -m 644 $(CONTENT_PLUGINS_SRC_DIR)/container_content.py $(RHSM_PLUGIN_DIR)

.PHONY: install-ga
ifeq ($(GTK_VERSION),2)
install-ga:
	@echo "USING $(GTK_VERSION)"
	install -d $(PYTHON_INST_DIR)/ga_impls/ga_gtk2
	install -m 644 -p $(SRC_DIR)/ga_impls/__init__.py* $(PYTHON_INST_DIR)/ga_impls
	install -m 644 -p $(SRC_DIR)/ga_impls/ga_gtk2/*.py $(PYTHON_INST_DIR)/ga_impls/ga_gtk2
else
install-ga:
	@echo "USING $(GTK_VERSION)"
	install -d $(PYTHON_INST_DIR)/ga_impls
	install -m 644 -p $(SRC_DIR)/ga_impls/__init__.py* $(PYTHON_INST_DIR)/ga_impls
	install -m 644 -p $(SRC_DIR)/ga_impls/ga_gtk3.py* $(PYTHON_INST_DIR)/ga_impls
endif

.PHONY: install-example-plugins
install-example-plugins: install-plugins
	install -m 644 -p example-plugins/*.py $(RHSM_PLUGIN_DIR)
	install -m 644 -p example-plugins/*.conf $(RHSM_PLUGIN_CONF_DIR)

.PHONY: install-firstboot
ifeq ($(INSTALL_FIRSTBOOT),true)
install-firstboot:
	@echo "Installing firstboot to $(FIRSTBOOT_MODULES_DIR)"
	install -d $(FIRSTBOOT_MODULES_DIR)
	install -m644 $(SRC_DIR)/gui/firstboot/*.py* $(FIRSTBOOT_MODULES_DIR)
else
install-firstboot:
	# Override INSTALL_FIRSTBOOT variable on command line if needed
	@echo "firstboot is not configured to be install"
endif

# initial-setup, as in the 'initial-setup' rpm that runs at first boot.
.PHONY: install-initial-setup
ifeq ($(INSTALL_INITIAL_SETUP),true)
install-initial-setup:
	@echo "Installing initial-setup to $(INITIAL_SETUP_INST_DIR)"
	install -m 644 $(CONTENT_PLUGINS_SRC_DIR)/ostree_content.py $(RHSM_PLUGIN_DIR)
	install -d $(ANACONDA_ADDON_INST_DIR)
	install -d $(INITIAL_SETUP_INST_DIR)/gui/spokes
	install -d $(INITIAL_SETUP_INST_DIR)/{categories,ks}
	install -m 644 -p $(ANACONDA_ADDON_MODULE_SRC_DIR)/*.py $(INITIAL_SETUP_INST_DIR)/
	install -m 644 -p $(ANACONDA_ADDON_MODULE_SRC_DIR)/gui/*.py $(INITIAL_SETUP_INST_DIR)/gui/
	install -m 644 -p $(ANACONDA_ADDON_MODULE_SRC_DIR)/categories/*.py $(INITIAL_SETUP_INST_DIR)/categories/
	install -m 644 -p $(ANACONDA_ADDON_MODULE_SRC_DIR)/gui/spokes/{*.py,*.ui} $(INITIAL_SETUP_INST_DIR)/gui/spokes/
	install -m 644 -p $(ANACONDA_ADDON_MODULE_SRC_DIR)/ks/*.py $(INITIAL_SETUP_INST_DIR)/ks/
else
install-initial-setup:
	# Set INSTALL_INITIAL_SETUP variable on command line if needed.
	@echo "initial-setup is not configured to be installed."
endif

.PHONY: install-post-boot
install-post-boot: install-firstboot install-initial-setup

.PHONY: install-via-setup
install-via-setup:
	./setup.py install --root $(PREFIX)

.PHONY: install
install: install-via-setup rhsmcertd rhsm-icon install-files

.PHONY: set-versions
set-versions:
	sed -e 's/RPM_VERSION/$(VERSION)/g' -e 's/GTK_VERSION/$(GTK_VERSION)/g' $(SRC_DIR)/version.py.in > $(SRC_DIR)/version.py
	sed -e 's/RPM_VERSION/$(VERSION)/g' $(RCT_SRC_DIR)/version.py.in > $(RCT_SRC_DIR)/version.py

.PHONY: install-files
install-files: set-versions dbus-service-install install-conf install-plugins install-post-boot install-ga
	install -d $(PYTHON_INST_DIR)/plugin/ostree
	install -d $(PYTHON_INST_DIR)/firstboot
	install -d $(PREFIX)/var/log/rhsm
	install -d $(PREFIX)/var/spool/rhsm/debug
	install -d $(PREFIX)/var/run/rhsm
	install -d $(PREFIX)/var/lib/rhsm/{cache,facts,packages}

	if [ "$(INSTALL_OSTREE_PLUGIN)" = "true" ] ; then \
		install -m 644 -p $(SRC_DIR)/plugin/ostree/*.py $(PYTHON_INST_DIR)/plugin/ostree ; \
	fi
	if [ "$(INSTALL_YUM_PLUGINS)" = "true" ] ; then \
		@echo "Installing Yum plugins" ; \
		install -d $(PREFIX)/etc/yum/pluginconf.d/ ; \
		install -d $(PREFIX)/usr/lib/yum-plugins/ ; \
		install -m 644 -p src/plugins/*.py $(PREFIX)/usr/lib/yum-plugins/ ; \
		install -m 644 etc-conf/plugin/*.conf $(PREFIX)/etc/yum/pluginconf.d/ ; \
	fi ; \
	if [ "$(INSTALL_DNF_PLUGINS)" = "true" ] ; then \
		@echo "Installing DNF plugins" ; \
		install -d $(PREFIX)/$(PYTHON_SITELIB)/dnf-plugins/ ; \
		install -m 644 -p src/dnf-plugins/*.py $(PREFIX)/$(PYTHON_SITELIB)/dnf-plugins/ ; \
	fi ; \

	# Set up rhsmcertd daemon. If installing on Fedora or RHEL 7+
	# we prefer systemd over sysv as this is the new trend.
	if [ $(OS) = Fedora ] ; then \
		install -d $(SYSTEMD_INST_DIR); \
		install -d $(PREFIX)/usr/lib/tmpfiles.d; \
		install etc-conf/rhsmcertd.service $(SYSTEMD_INST_DIR); \
		install etc-conf/subscription-manager.conf.tmpfiles \
			$(PREFIX)/usr/lib/tmpfiles.d/subscription-manager.conf; \
	else \
		if [ $(OS_VERSION) -lt 7 ]; then \
			install etc-conf/rhsmcertd.init.d \
				$(PREFIX)/etc/rc.d/init.d/rhsmcertd; \
		else \
			install -d $(SYSTEMD_INST_DIR); \
			install -d $(PREFIX)/usr/lib/tmpfiles.d; \
			install etc-conf/rhsmcertd.service $(SYSTEMD_INST_DIR); \
			install etc-conf/subscription-manager.conf.tmpfiles \
				$(PREFIX)/usr/lib/tmpfiles.d/subscription-manager.conf; \
		fi; \
	fi; \

	install -m 700 etc-conf/rhsmd.cron $(PREFIX)/etc/cron.daily/rhsmd

	ln -sf /usr/bin/consolehelper $(PREFIX)/usr/bin/subscription-manager-gui
	ln -sf /usr/bin/consolehelper $(PREFIX)/usr/bin/subscription-manager

	install -m 644 etc-conf/subscription-manager-gui.pam $(PREFIX)/etc/pam.d/subscription-manager-gui
	install -m 644 etc-conf/subscription-manager.pam $(PREFIX)/etc/pam.d/subscription-manager

	install -m 644 etc-conf/subscription-manager-gui.console $(PREFIX)/etc/security/console.apps/subscription-manager-gui
	install -m 644 etc-conf/subscription-manager.console $(PREFIX)/etc/security/console.apps/subscription-manager

	install -m 755 bin/rhsm-icon $(PREFIX)/usr/bin/rhsm-icon
	install -m 755 bin/rhsmcertd $(PREFIX)/usr/bin/rhsmcertd

.PHONY: check
check:
	python setup.py -q nosetests -c playpen/noserc.dev

.PHONY: coverage
coverage:
	./setup.py -q nosetests -c playpen/noserc.ci

.PHONY: gettext
gettext:
	# Extract strings from our source files. any comments on the line above
	# the string marked for translation beginning with "translators" will be
	# included in the pot file.
	./setup.py gettext

.PHONY: update-po
update-po:
	./setup.py update_trans

.PHONY: uniq-po
uniq-po:
	./setup.py uniq_trans

# just run a check to make sure these compile
.PHONY: polint
polint:
	./setup.py gettext --lint

.PHONY: just-strings
just-strings:
	-@ scripts/just_strings.py po/keys.pot

.PHONY: zanata-pull
zanata-pull:
	pushd po && zanata pull --transdir . && popd

.PHONY: zanata-push
zanata-push:
	pushd po; \
	ls -al; \
	if [ -z $(shell find -name "*.pot" | grep -v keys.pot) ] ; then \
		zanata push ; \
	else 	\
		echo "po/ has more than one *.pot file, please clean up" ; \
	fi; \
	popd

# do all the zanata bits
.PHONY: zanata
zanata: gettext zanata-push zanata-pull update-po
	echo "# pofiles should be ready to commit and push"

# generate a en_US.po with long strings for testing
gen-test-long-po:
	-@ scripts/gen_test_en_po.py --long po/en_US.po

.PHONY: lint
lint:
	./setup.py lint

.PHONY: flake8
flake8:
	./setup.py flake8

.PHONY: rpmlint
rpmlint:
	./setup.py lint_rpm

# We target python 2.6, hence -m 2.7 is the earliest python features to warn about use of.
# See https://github.com/alikins/pyqver for pyqver.
# Since plugin/ostree is for python 2.7+ systems only, we can ignore the warning there.
.PHONY: versionlint
versionlint:
	@TMPFILE=`mktemp` || exit 1; \
	pyqver2.py -m 2.7 -l $(STYLEFILES) | grep -v hashlib | grep -v plugin/ostree.*check_output | tee $$TMPFILE; \
	! test -s $$TMPFILE

.PHONY: stylish
stylish: lint versionlint

.PHONY: install-pip-requirements
install-pip-requirements:
	@pip install -r test-requirements.txt

.PHONY: jenkins
jenkins: install-pip-requirements build stylish coverage
