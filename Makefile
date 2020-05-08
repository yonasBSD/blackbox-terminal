.PHONY: all export install run clean fclean update hard-update test-run ffclean

MODULE := terminal
APP_ID := com.raggesilver.Terminal
MANIFEST := $(APP_ID).json

APP_DIR := app
BUILD_DIR := app_build
REPO_DIR := repo

BUILD_COMMAND := meson --prefix=/app $(BUILD_DIR)
INSTALL_COMMAND := ninja -C $(BUILD_DIR) install

all: $(MODULE)

$(MODULE): $(BUILD_DIR) Makefile
	flatpak-builder --run $(APP_DIR) $(MANIFEST) $(INSTALL_COMMAND)

# app_build/
$(BUILD_DIR): $(APP_DIR) Makefile
	flatpak-builder --run $(APP_DIR) $(MANIFEST) $(BUILD_COMMAND)

# app/
$(APP_DIR):
	flatpak-builder --disable-updates --stop-at=$(MODULE) $@ $(MANIFEST)

# build (if necessary) and run $(MODULE)
run: $(MODULE)
	flatpak-builder --run $(APP_DIR) $(MANIFEST) $(MODULE)

# build (if necessary) and run $(MODULE) for 5 seconds
test-run: $(MODULE)
	flatpak-builder --run $(APP_DIR) $(MANIFEST) sh -c '$(MODULE) & sleep 3; kill `pgrep $(MODULE)`'

# update dependencies, use cache if unchanged
update:
	flatpak-builder --ccache --force-clean --stop-at=$(MODULE) $(APP_DIR) $(MANIFEST)

# update all dependencies without cache (will rebuild everything) even if there
# is nothing new
hard-update:
	flatpak-builder --disable-cache --force-clean --stop-at=$(MODULE) $(APP_DIR) $(MANIFEST)

# generate $(REPO_DIR) and $(MODULE).flatpak
export: $(MODULE)
	flatpak-builder --finish-only $(APP_DIR) $(MANIFEST)
	flatpak-builder --export-only --repo=$(REPO_DIR) $(APP_DIR) $(MANIFEST)
	flatpak build-bundle $(REPO_DIR) "$(MODULE).flatpak" $(APP_ID)

# install $(MODULE).flatpak
install: export
	flatpak install --user "$(MODULE).flatpak"

# remove $(BUILD_DIR), $(REPO_DIR) and $(MODULE).flatpak
clean:
	rm -rf $(BUILD_DIR)
	rm -rf $(REPO_DIR)
	rm -rf $(MODULE).flatpak

# remove $(BUILD_DIR), $(REPO_DIR), $(MODULE).flatpak and $(APP_DIR)
fclean: clean
	rm -rf $(APP_DIR)

# remove everything from fclean plus .flatpak-builder
ffclean: fclean
	rm -rf .flatpak-builder

# some tests for this file
# make ffclean test-run export && make ffclean export
# make ffclean hard-update export
# make test-run; make update export

# keep this as reference:
# https://docs.flatpak.org/en/latest/flatpak-builder-command-reference.html
