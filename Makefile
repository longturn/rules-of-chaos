# Define variables
SRC_DIR = src
DEST_DIR = Chaos

# Generate list of destination files from sources
SRC_FILES = $(wildcard $(SRC_DIR)/*)
SRC_NAMES = $(notdir $(SRC_FILES))
DEST_NAMES = $(subst .j2,,$(SRC_NAMES))
DEST_FILES = $(addprefix $(DEST_DIR)/,$(DEST_NAMES))

# Define the target for all files
all: $(DEST_DIR) $(DEST_FILES)

# Clean out the destination directory for a full rebuild
clean: $(DEST_DIR)
	rm --verbose --recursive --force $(DEST_DIR)

# Rule to ensure the destination directory exists
$(DEST_DIR):
	mkdir --verbose --parents $(DEST_DIR)

# Pattern rule for processing .j2 files
$(DEST_DIR)/%: $(SRC_DIR)/%.j2 $(DEST_DIR)
	j2 $< game.json --import-env= -o $@

# Rule for static files
$(DEST_DIR)/%:: $(SRC_DIR)/% $(DEST_DIR)
	cp --verbose --force $< $@

# Mark targets that are not files
.PHONY: all clean

