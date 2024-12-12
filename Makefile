# Define variables
RULESET_NAME = Chaos
J2CLI = j2 $< game.json --filters filters.py --tests tests.py --import-env= -o $@

SRC_DIR = src
DEST_DIR = $(RULESET_NAME)
CACHE_DIR = cache

# Generate list of destination files from sources
SRC_FILES = $(wildcard $(SRC_DIR)/*)
SRC_NAMES = $(notdir $(SRC_FILES))
DEST_NAMES = $(subst .j2,,$(SRC_NAMES))
DEST_FILES = $(addprefix $(DEST_DIR)/,$(DEST_NAMES))
# FIXME: This is a hack to make it rebuild files when dependencies change, but 
# it's inefficient as it rebuilds unrelated files too
DEPENDENCIES = $(shell find $(SRC_DIR) -mindepth 2 -type f)

# Handle server files
SERV_TEMPLATE = $(RULESET_NAME).serv.j2
SERV_FILE = $(RULESET_NAME).serv

# Define the target for all files
all: $(DEST_DIR) $(DEST_FILES) $(SERV_FILE)

# Clean out the destination directory for a full rebuild
clean: $(DEST_DIR) $(TEST_DEST_DIR)
	rm --verbose --recursive --force $(DEST_DIR) $(TEST_DEST_DIR)
	@if [ -f $(SERV_TEMPLATE) ]; then rm --verbose --force $(SERV_FILE); fi

# Rules to ensure the destination directories exist
$(DEST_DIR):
	mkdir --verbose --parents $(DEST_DIR)

# Pattern rules for processing .j2 files
$(DEST_DIR)/%: $(SRC_DIR)/%.j2 $(DEST_DIR) $(DEPENDENCIES)
	$(J2CLI)

$(SERV_FILE): $(SERV_TEMPLATE) $(DEPENDENCIES)
	$(J2CLI)

# Rule for static files
$(DEST_DIR)/%:: $(SRC_DIR)/% $(DEST_DIR)
	cp --recursive --verbose --force $< $@

# Mark targets that are not files
.PHONY: all clean

