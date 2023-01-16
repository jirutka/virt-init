PROJNAME     := virt-init

# These paths are currently not changeable.
INITD_DIR    := /etc/init.d
CONFD_DIR    := /etc/conf.d
DATA_DIR     := /usr/share/$(PROJNAME)

GIT          := git
INSTALL      := install
SED          := sed

MAKEFILE_PATH = $(lastword $(MAKEFILE_LIST))

#: Print list of targets.
help:
	@printf '%s\n\n' 'List of targets:'
	@$(SED) -En '/^#:.*/{ N; s/^#: (.*)\n([A-Za-z0-9_-]+).*/\2 \1/p }' $(MAKEFILE_PATH) \
		| while read label desc; do printf '%-17s %s\n' "$$label" "$$desc"; done

#: Check shell scripts for syntax errors.
check:
	@rc=0; for f in lib/utils.sh lib/platforms/* lib/scripts/*; do \
		if $(SHELL) -n $$f; then \
			printf "%-33s PASS\n" $$f; \
		else \
			rc=1; \
		fi; \
	done; \
	exit $$rc

#: Install files to ${DESTDIR}.
install:
	@$(INSTALL) -Dv -m 644 lib/utils.sh -t $(DESTDIR)$(DATA_DIR)/
	@$(INSTALL) -Dv -m 755 lib/platforms/* -t $(DESTDIR)$(DATA_DIR)/platforms/
	@$(INSTALL) -Dv -m 755 lib/scripts/* -t $(DESTDIR)$(DATA_DIR)/scripts/
	@$(INSTALL) -Dv -m 755 etc/init.d/$(PROJNAME) -t $(DESTDIR)$(INITD_DIR)/
	@$(INSTALL) -Dv -m 644 etc/conf.d/$(PROJNAME) -t $(DESTDIR)$(CONFD_DIR)/

#: Remove files previously installed to ${DESTDIR}.
uninstall:
	@rm -rfv "$(DESTDIR)$(DATA_DIR)"
	@rm -v $(DESTDIR)$(INITD_DIR)/$(PROJNAME)
	@rm -v $(DESTDIR)$(CONFD_DIR)/$(PROJNAME)

#: Update version in lib/VERSION to $VERSION.
bump-version:
	test -n "$(VERSION)"  # $$VERSION
	echo "$(VERSION)" > lib/VERSION

#: Bump version to $VERSION, create release commit and tag.
release: .check-git-clean | bump-version
	test -n "$(VERSION)"  # $$VERSION
	$(GIT) add .
	$(GIT) commit --allow-empty -m "Release version $(VERSION)"
	$(GIT) tag -s v$(VERSION) -m v$(VERSION)

.PHONY: help check install uninstall bump-version release


.check-git-clean:
	@test -z "$(shell $(GIT) status --porcelain)" \
		|| { echo 'You have uncommitted changes!' >&2; exit 1; }

.PHONY: .check-distro .check-git-clean
