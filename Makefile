-include .env
export

ADDON          := AztarecHelper
VERSION        := $(shell grep "^\#\# Version:" $(ADDON).toc | awk '{print $$3}')
# last Interface token. Earlier ones are only there so the addon loads on
# current retail while developing. The release itself targets 12.1.
TOC_VERSION    := $(shell grep "^\#\# Interface:" $(ADDON).toc | awk '{print $$NF}')
TOC_DISPLAY    := $(shell echo $(TOC_VERSION) | awk '{printf "%d.%d.%d", substr($$0,1,2), substr($$0,3,2), substr($$0,5,2)}')
CURSE_PROJECT  := 1613242
WAGO_PROJECT   := $(shell grep "^\#\# X-Wago-ID:" $(ADDON).toc | awk '{print $$3}')
# Packaged files are derived from the .toc, never hand-listed, so the zip can
# never drift from what the game actually loads. Pull every .lua line the .toc
# references, drop CRLF and turn backslash paths into forward slashes (\134 is
# octal for backslash).
# DEV_FILES load locally since the .toc lists them, but they never ship. They
# get filtered out of the package and their .toc lines stripped from the copy.
DEV_FILES      := Dev/DevTools.lua
SRC_LUA        := $(filter-out $(DEV_FILES),$(shell grep -vE '^[[:space:]]*\#' $(ADDON).toc | grep -iE '\.lua[[:space:]]*$$' | tr -d '\r' | tr '\134' '/'))
# Bindings.xml loads by name convention so the .toc never mentions it
SRC_FILES      := $(SRC_LUA) $(ADDON).toc Bindings.xml LICENSE.txt Media/addonlogo.tga Media/arrow.tga Media/lock.tga Media/forward.mp3 Media/left.mp3 Media/right.mp3 Media/stay.mp3
DIST_FILES     := $(SRC_FILES)
RELEASE_TYPE   ?= alpha
CHANGELOG      ?= See project page for changes.

.PHONY: help lint format check package package-min release release-wago clean

help:
	@echo "make lint          run luacheck"
	@echo "make format        format all Lua files with stylua"
	@echo "make check         check formatting without writing (for CI)"
	@echo "make package       build $(ADDON)-$(VERSION).zip"
	@echo "make package-min   build $(ADDON)-$(VERSION)-min.zip (comments stripped)"
	@echo "make release       upload to CurseForge (requires CURSEFORGE_TOKEN env var)"
	@echo "make release-wago  upload to Wago (requires WAGO_API_TOKEN env var)"
	@echo "make clean         remove built zips"

lint:
	luacheck Core/*.lua UI/*.lua Dev/*.lua

format:
	stylua Core/*.lua UI/*.lua Dev/*.lua

check:
	stylua --check Core/*.lua UI/*.lua Dev/*.lua

package: clean
	@echo "Packaging $(ADDON) v$(VERSION)..."
	@mkdir -p dist/$(ADDON)
	@cp --parents $(SRC_FILES) dist/$(ADDON)/
	@sed -i '/^Dev[\\]DevTools\.lua/d;/^\# dev-only/d' dist/$(ADDON)/$(ADDON).toc
	@pwsh -NoProfile -Command "Compress-Archive -Path 'dist/$(ADDON)' -DestinationPath '$(ADDON)-$(VERSION).zip'"
	@rm -rf dist
	@echo "Built $(ADDON)-$(VERSION).zip"

package-min: clean
	@echo "Packaging $(ADDON) v$(VERSION) (minified)..."
	@mkdir -p dist/$(ADDON)
	@python Dev/minify.py dist/$(ADDON) $(DIST_FILES)
	@sed -i '/^Dev[\\]DevTools\.lua/d;/^\# dev-only/d' dist/$(ADDON)/$(ADDON).toc
	@pwsh -NoProfile -Command "Compress-Archive -Path 'dist/$(ADDON)' -DestinationPath '$(ADDON)-$(VERSION)-min.zip'"
	@rm -rf dist
	@echo "Built $(ADDON)-$(VERSION)-min.zip"

release: package
	@test -n "$(CURSEFORGE_TOKEN)" || { echo "Error: CURSEFORGE_TOKEN not set"; exit 1; }
	@test "$(CURSE_PROJECT)" != "0" || { echo "Error: set CURSE_PROJECT in Makefile first"; exit 1; }
	@echo "Uploading $(ADDON)-$(VERSION).zip (WoW $(TOC_DISPLAY)) to CurseForge..."
	@GAME_VER_ID=$$(curl -sf \
	  -H "X-Api-Token: $(CURSEFORGE_TOKEN)" \
	  "https://wow.curseforge.com/api/game/versions" | \
	  python -c "import json,sys; v='$(TOC_DISPLAY)'; d=json.load(sys.stdin); print(next((x['id'] for x in d if x['name']==v),''))"); \
	test -n "$$GAME_VER_ID" || { echo "Error: WoW $(TOC_DISPLAY) not found in CurseForge API"; exit 1; }; \
	python -c "import json; open('.release_meta.json','w').write(json.dumps({'gameVersions':[int('$$GAME_VER_ID')],'releaseType':'$(RELEASE_TYPE)','changelog':open('CHANGELOG.md').read(),'changelogType':'markdown'}))" && \
	curl -sf \
	  -H "X-Api-Token: $(CURSEFORGE_TOKEN)" \
	  -F "metadata=<.release_meta.json;type=application/json" \
	  -F "file=@$(ADDON)-$(VERSION).zip" \
	  "https://wow.curseforge.com/api/projects/$(CURSE_PROJECT)/upload-file" && \
	rm -f .release_meta.json && \
	echo "Released $(ADDON)-$(VERSION).zip as '$(RELEASE_TYPE)'."

# Wago calls a stable build "stable" where CurseForge calls it "release".
release-wago: package
	@test -n "$(WAGO_API_TOKEN)" || { echo "Error: WAGO_API_TOKEN not set"; exit 1; }
	@test -n "$(WAGO_PROJECT)" || { echo "Error: X-Wago-ID not set in $(ADDON).toc"; exit 1; }
	@echo "Uploading $(ADDON)-$(VERSION).zip to Wago..."
	@STAB=$$(test "$(RELEASE_TYPE)" = "release" && echo stable || echo "$(RELEASE_TYPE)"); \
	python -c "import json; open('.wago_meta.json','w').write(json.dumps({'label':'$(VERSION)','stability':'$$STAB','changelog':open('CHANGELOG.md',encoding='utf-8').read(),'supported_retail_patch':'$(TOC_DISPLAY)'}))" && \
	curl -sf \
	  -H "Authorization: Bearer $(WAGO_API_TOKEN)" \
	  -H "Accept: application/json" \
	  -F "metadata=<.wago_meta.json" \
	  -F "file=@$(ADDON)-$(VERSION).zip" \
	  "https://addons.wago.io/api/projects/$(WAGO_PROJECT)/version" && \
	rm -f .wago_meta.json && \
	echo "Released $(ADDON)-$(VERSION).zip to Wago as '$$STAB'."

debug-release: package
	@test -n "$(CURSEFORGE_TOKEN)" || { echo "Error: CURSEFORGE_TOKEN not set"; exit 1; }
	@echo "Fetching game version ID for WoW $(TOC_DISPLAY)..."
	@GAME_VER_ID=$$(curl -sf \
	  -H "X-Api-Token: $(CURSEFORGE_TOKEN)" \
	  "https://wow.curseforge.com/api/game/versions" | \
	  python -c "import json,sys; v='$(TOC_DISPLAY)'; d=json.load(sys.stdin); print(next((x['id'] for x in d if x['name']==v),''))"); \
	test -n "$$GAME_VER_ID" || { echo "Error: WoW $(TOC_DISPLAY) not found"; exit 1; }; \
	echo "Game version ID: $$GAME_VER_ID"; \
	python -c "import json; open('.release_meta.json','w').write(json.dumps({'gameVersions':[int('$$GAME_VER_ID')],'releaseType':'$(RELEASE_TYPE)','changelog':open('CHANGELOG.md').read(),'changelogType':'markdown'}))" && \
	echo "Metadata:" && cat .release_meta.json && echo "" && \
	curl -v \
	  -H "X-Api-Token: $(CURSEFORGE_TOKEN)" \
	  -F "metadata=<.release_meta.json;type=application/json" \
	  -F "file=@$(ADDON)-$(VERSION).zip" \
	  "https://wow.curseforge.com/api/projects/$(CURSE_PROJECT)/upload-file"; \
	rm -f .release_meta.json

clean:
	@rm -f $(ADDON)-*.zip .wago_meta.json
	@rm -rf dist
