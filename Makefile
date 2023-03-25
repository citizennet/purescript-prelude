# There are a couple of conventions we use so make works a little better.
#
# We sometimes want to build an entire directory of files based on one file.
# We do this for dependencies. E.g.: package.json -> node_modules.
# For these cases, we track an empty `.stamp` file in the directory.
# This allows us to keep up with make's dependency model.
#
# We also want some place to store all the excess build artifacts.
# This might be test outputs, or it could be some intermediate artifacts.
# For this, we use the `$(PRELUDE_BUILD_DIR)` directory.
# Assuming the different tools allow us to put their artifacts in here,
# we can clean up builds really easily: delete this directory.
#
# We use some make syntax that might be unfamiliar, a quick refresher:
# make is based on a set of rules
#
# <targets>: <prerequisites> | <order-only-prerequisites>
# 	<recipe>
#
# `<targets>` are the things we want to make. This is usually a single file,
# but it can be multiple things separated by spaces.
#
# `<prerequisites>` are the things that decide when `<targets>` is out of date.
# These are also usually files. They are separated by spaces.
# If any of the `<prerequisites>` are newer than the `<targets>`,
# the recipe is run to bring the `<targets>` up to date.
#
# `<recipe>` are the commands to run to bring the `<targets>` up to date.
# These are commands like we write on a terminal.
#
# See: https://www.gnu.org/software/make/manual/make.html#Rule-Syntax
#
# `<order-only-prerequisites>` are similar to normal `<prerequisites>`
# but they don't cause a target to be rebuilt if they're out of date.
# This is mostly useful for creating directories and whatnot.
#
# See: https://www.gnu.org/software/make/manual/make.html#Prerequisite-Types
#
# And a quick refresher on some make variables:
#
# $@ - Expands to the target we're building.
# $< - Expands to the first prerequisite of the recipe.
#
# See: https://www.gnu.org/software/make/manual/make.html#Automatic-Variables
#
# `.DEFAULT_GOAL` is the goal to use if no other goals are specified.
# Normally, the first goal in the file is used if no other goals are specified.
# Setting this allows us to override that behavior.
#
# See: https://www.gnu.org/software/make/manual/make.html#index-_002eDEFAULT_005fGOAL-_0028define-default-goal_0029
#
# `.PHONY` forces a recipe to always run. This is useful for things that are
# more like commands than targets. For instance, we might want to clean up
# all artifacts. Since there's no useful target, we can mark `clean` with
# `.PHONY` and make will run the task every time we ask it to.
#
# See: https://www.gnu.org/software/make/manual/make.html#Phony-Targets
# See: https://www.gnu.org/software/make/manual/make.html#index-_002ePHONY-1

# Absolute path to either this project, or the root project if called
# from parent Makefile
ROOT_DIR ?= $(shell pwd)

# Relative path to this directory from $ROOT_DIR
# If called from a parent Makefile, will resolve to something like `lib/prelude`
PRELUDE_DIR ?= .

# Library-specific constants
PRELUDE_BUILD_DIR := $(PRELUDE_DIR)/.build
PRELUDE_FORMAT_PURS_TIDY_STAMP := $(PRELUDE_BUILD_DIR)/.format-prelude-purs-tidy-stamp
PRELUDE_PURS := $(shell find $(PRELUDE_DIR) -name '*.purs' -type f)
PRELUDE_SPAGO_CONFIG := $(PRELUDE_DIR)/spago.dhall
PRELUDE_SRCS := $(shell find $(PRELUDE_DIR) \( -name '*.purs' -o -name '*.js' \) -type f)
ROOT_DIR_RELATIVE := $(shell echo '$(PRELUDE_DIR)' | sed 's \([^./]\+\) .. g')

# Variables we want to inherit from a parent Makefile if it exists
OUTPUT_DIR ?= $(ROOT_DIR)/output
SPAGO_DIR ?= $(ROOT_DIR)/.spago
SPAGO_PACKAGES_CONFIG ?= $(PRELUDE_DIR)/packages.dhall
SPAGO_STAMP ?= $(SPAGO_DIR)/.stamp

# Commands and variables
PSA ?= psa
PSA_ARGS ?= --censor-lib --stash=$(PRELUDE_BUILD_DIR)/.psa_stash --strict --is-lib=$(SPAGO_DIR) --censor-codes=HiddenConstructors
PURS_TIDY ?= purs-tidy
PURS_TIDY_CMD ?= check
RTS_ARGS ?= +RTS -N2 -A800m -RTS
SPAGO ?= spago
SPAGO_BUILD_DEPENDENCIES ?= $(SPAGO_STAMP)

# Colors for printing
CYAN ?= \033[0;36m
RESET ?= \033[0;0m

# Variables we add to
ALL_SRCS += $(PRELUDE_SRCS)
CLEAN_DEPENDENCIES += clean-prelude
FORMAT_DEPENDENCIES += $(PRELUDE_FORMAT_PURS_TIDY_STAMP)
SPAGO_CONFIGS += $(PRELUDE_SPAGO_CONFIG)

.DEFAULT_GOAL := build-prelude

$(PRELUDE_BUILD_DIR) $(OUTPUT_DIR):
	mkdir -p $@

$(PRELUDE_BUILD_DIR)/help-unsorted: $(MAKEFILE_LIST) | $(PRELUDE_BUILD_DIR)
	@grep \
		--extended-regexp '^[A-Za-z_-]+:.*?## .*$$' \
		--no-filename \
		$(MAKEFILE_LIST) \
		> $@

$(PRELUDE_BUILD_DIR)/help: $(PRELUDE_BUILD_DIR)/help-unsorted | $(PRELUDE_BUILD_DIR)
	@sort $< > $@

$(PRELUDE_FORMAT_PURS_TIDY_STAMP): $(PRELUDE_PURS) | $(PRELUDE_BUILD_DIR)
	$(PURS_TIDY) $(PURS_TIDY_CMD) $(PRELUDE_DIR)/src
	@touch $@

$(PRELUDE_SPAGO_CONFIG): gen-spago-config-prelude $(PRELUDE_DIR)/spago.template.dhall

$(SPAGO_STAMP): $(SPAGO_PACKAGES_CONFIG) $(SPAGO_CONFIGS)
	# `spago` doesn't clean up after itself if different versions are installed, so we do it ourselves.
	rm -fr $(SPAGO_DIR)
	$(SPAGO) install $(RTS_ARGS)
	touch $@

.PHONY: build-prelude
build-prelude: $(PRELUDE_SPAGO_CONFIG) $(SPAGO_BUILD_DEPENDENCIES) | $(PRELUDE_BUILD_DIR) ## Build the `prelude` package
	$(SPAGO) --config $(PRELUDE_SPAGO_CONFIG) build --purs-args '$(PSA_ARGS) $(RTS_ARGS)'

.PHONY: check-format-prelude
check-format-prelude: PURS_TIDY_CMD=check
check-format-prelude: $(PRELUDE_FORMAT_PURS_TIDY_STAMP) ## Validate formatting of the `prelude` directory

# Since some of these variables are shared with the root Makefile.
# Running `clean-prelude` from root might have the unintended consequence
# of cleaning more than intended. Specifically, it will remove the
# root $OUTPUT_DIR, and $SPAGO_DIR.
.PHONY: clean-prelude
clean-prelude: clean-spago-config-prelude
	rm -fr \
		$(PRELUDE_BUILD_DIR) \
		$(OUTPUT_DIR) \
		$(SPAGO_DIR)

.PHONY: clean-spago-config-prelude
clean-spago-config-prelude:
	rm -f $(PRELUDE_SPAGO_CONFIG)

.PHONY: format-prelude
format-prelude: PURS_TIDY_CMD=format-in-place
format-prelude: $(PRELUDE_FORMAT_PURS_TIDY_STAMP) ## Format the `prelude` directory

.PHONY: gen-spago-config-prelude
gen-spago-config-prelude: $(PRELUDE_DIR)/spago.template.dhall | $(PRELUDE_BUILD_DIR)
	@sed \
		's+{{PACKAGES_DIR}}+$(ROOT_DIR_RELATIVE)+g; s+{{SOURCES_DIR}}+$(PRELUDE_DIR)+g; s+{{GENERATED_DOC}}+This config is auto-generated by make.\nIf the paths are wrong, try deleting it and running make again.+g' \
		$(PRELUDE_DIR)/spago.template.dhall > $(PRELUDE_BUILD_DIR)/spago.dhall
	@if cmp -s -- '$(PRELUDE_BUILD_DIR)/spago.dhall' '$(PRELUDE_SPAGO_CONFIG)'; then \
		echo 'Nothing to do for $(PRELUDE_SPAGO_CONFIG)'; \
	else \
		echo 'Generating new $(PRELUDE_SPAGO_CONFIG)'; \
		cp $(PRELUDE_BUILD_DIR)/spago.dhall $(PRELUDE_SPAGO_CONFIG); \
	fi

.PHONY: help
help: $(PRELUDE_BUILD_DIR)/help ## Display this help message
	@awk 'BEGIN {FS = ":.*?## "}; {printf "$(CYAN)%-30s$(RESET) %s\n", $$1, $$2}' $<

.PHONY: variable-%
variable-%: ## Display the value of a variable; e.g. `make variable-PRELUDE_BUILD_DIR`
	@echo '$*=$($*)'
