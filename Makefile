# Define variables
RULESET_NAME = Chaos
CONFIG_JSON = game.json
FILTERS = filters.py
TESTS = tests.py
J2_DEPS = $(CONFIG_JSON) $(FILTERS) $(TESTS)
J2CLI = chmod -f 664 $@; \
	j2 $< $(CONFIG_JSON) \
		--filters $(FILTERS) \
		--tests $(TESTS) \
		--import-env= \
		-o $@; \
	chmod 444 $@

SRC_DIR = src
DEST_DIR = $(RULESET_NAME)

# Generate list of destination files from sources
SRC_FILES = $(shell find $(SRC_DIR)/ -mindepth 1 -maxdepth 1 -type f)
SRC_NAMES = $(notdir $(SRC_FILES))
DEST_NAMES = $(subst .j2,,$(SRC_NAMES))
DEST_FILES = $(addprefix $(DEST_DIR)/,$(DEST_NAMES))

# Define the target for all files
all: $(DEST_DIR) $(DEST_FILES)

# Clean out the destination directory for a full rebuild
clean: $(DEST_DIR) $(TEST_DEST_DIR)
	rm --verbose --recursive --force $(DEST_DIR) $(TEST_DEST_DIR)
	@if [ -f $(SERV_TEMPLATE) ]; then rm --verbose --force $(SERV_FILE); fi

# Rules to ensure the destination directories exist
$(DEST_DIR):
	mkdir --verbose --parents $(DEST_DIR)

# Pattern rules for processing .j2 files
SCRIPTS = $(shell find $(SRC_DIR)/scripts/ -mindepth 1 -type f)
$(DEST_DIR)/script.lua: $(SRC_DIR)/script.lua.j2 $(DEST_DIR) $(J2_DEPS) $(SCRIPTS)
	$(J2CLI)

EFFECTS = $(shell find $(SRC_DIR)/effects/ -mindepth 1 -type f)
$(DEST_DIR)/effects.ruleset: $(SRC_DIR)/effects.ruleset.j2 $(DEST_DIR) $(J2_DEPS) $(EFFECTS)
	$(J2CLI)

$(DEST_DIR)/%: $(SRC_DIR)/%.j2 $(DEST_DIR) $(J2_DEPS)
	$(J2CLI)

# Rule for static files
$(DEST_DIR)/%:: $(SRC_DIR)/% $(DEST_DIR)
	cp --verbose --force $< $@

# Mark targets that are not files
.PHONY: all clean

