VENV = venv
PYTHON = $(VENV)/bin/python
PIP = $(VENV)/bin/pip

COUNTRY ?= asia/thailand
COUNTRY_NAME = $(notdir $(COUNTRY))
OUTPUT_DIR = output

COUNTRY_OSM_URL = https://download.geofabrik.de/$(COUNTRY)-latest.osm.pbf
COUNTRY_POLY_URL = https://download.geofabrik.de/$(COUNTRY).poly

OSM_DIR = osm
COUNTRY_OSM_PATH = $(OSM_DIR)/$(COUNTRY_NAME)-latest.osm.pbf
COUNTRY_POLY_PATH = $(OSM_DIR)/$(COUNTRY_NAME).poly

TMP_SG_STREETS_FILE = /tmp/$(COUNTRY_NAME)-streets.txt
SG_STREETS_FILE = data/$(COUNTRY_NAME)-streets.txt

# STREET_PATTERN = (avenue$$|boulevard$$|central$$|circle$$|close$$|crescent$$|drive$$|expressway$$|farmway$$|gardens$$|green$$|grove$$|heights$$|hill$$|lane$$|link$$|loop$$|parkway$$|ring$$|rise$$|road$$|square$$|street$$|terrace$$|walk$$|way$$|jalan|lorong)
STREET_PATTERN = (avenue$$|ave$$|blvd$$|boulevard$$|central$$|circle$$|close$$|crescent$$|cres$$|drive$$|expressway$$|farmway$$|gardens$$|green$$|grove$$|heights$$|hill$$|lane$$|link$$|loop$$|parkway$$|ring$$|rise$$|road$$|rd$$|street$$|st$$|walk$$|way$$|place$$|pl$$|square$$|court$$|ct$$|terrace$$|parade$$|highway$$|hwy$$|alley$$|arcade$$|quay$$|\
jalan$$|lorong$$|persiaran$$|taman$$|lebuhraya$$|lebuh$$|kampung$$|bandar$$|daerah$$|\
soi$$|thanon$$)


venv:
	python3 -m venv $(VENV)
	$(PIP) install --upgrade pip
	$(PIP) install -r requirements.txt

osm:
	wget $(COUNTRY_OSM_URL) -O $(COUNTRY_OSM_PATH)
	wget $(COUNTRY_POLY_URL) -O $(COUNTRY_POLY_PATH)

city:
	osmconvert $(COUNTRY_OSM_PATH) -B=$(COUNTRY_POLY_PATH) -o=$(OSM_DIR)/$(COUNTRY_NAME).osm.pbf
	osmosis --read-pbf $(OSM_DIR)/$(COUNTRY_NAME).osm.pbf --write-xml $(OSM_DIR)/$(COUNTRY_NAME).osm

streets:
	$(PYTHON) scripts/extract_streets.py $(OSM_DIR)/$(COUNTRY_NAME).osm data/$(COUNTRY_NAME)-streets.csv
	$(PYTHON) -c "import csv; [print(row[0]) for row in csv.reader(open('data/$(COUNTRY_NAME)-streets.csv'))][1:]" | sort | uniq > $(SG_STREETS_FILE) 

clean:
	mkdir -p $(OUTPUT_DIR)
	cat data/$(COUNTRY_NAME)-streets.txt | \
	$(PYTHON) scripts/format-address.py | \
	$(PYTHON) scripts/invalid-address.py | \
	$(PYTHON) scripts/street-names.py | \
	sort | uniq > $(OUTPUT_DIR)/$(COUNTRY_NAME)-streets.txt

categorize:
	@mkdir -p $(OUTPUT_DIR)
	@rm -f street_categories.md chunks/*.txt chunks/*.md 2>/dev/null || true
	@mkdir -p chunks
	@split -l 500 $(OUTPUT_DIR)/$(COUNTRY_NAME)-streets.txt chunks/streets_chunk_
	@for chunk in chunks/streets_chunk_*; do \
		echo "Processing $$chunk..."; \
		if ollama run mistral-nemo:latest "Analyze these $(COUNTRY_NAME) street names and categorize them by: 1) Linguistic Origin ($(COUNTRY_NAME), Pali, Malay, English/British, Chinese, Tamil, etc.) 2) Historical Themes (colonial figures, local heroes, royalty) 3) Nature & Geography (trees, flowers, animals, places) 4) Cultural & Religious (pagoda, stupa, temples, festivals, concepts) 5) Occupational (trades, professions) 6) Descriptive (colors, directions, shapes) 7) Modern Development. List street names under each category with brief explanations. Format as markdown with clear headings:" < $$chunk > chunks/category_$$(basename $$chunk).md; then \
			echo "✓ Completed $$chunk"; \
		else \
			echo "✗ Failed processing $$chunk"; \
			exit 1; \
		fi; \
	done
	@echo "Consolidating results into common headings..."
	@cat chunks/category_*.md > chunks/all_categories.md
	@if ollama run mistral-nemo:latest "Please consolidate this fragmented categorization of $(COUNTRY_NAME) street names into a single, well-organized markdown document. Merge duplicate categories, combine street names under common headings, remove redundancy, and create a comprehensive final categorization. Maintain the 7 main categories: 1) Linguistic Origin 2) Historical Themes 3) Nature & Geography 4) Cultural & Religious 5) Occupational 6) Descriptive 7) Modern Development. Format with clear headings and bullet points:" < chunks/all_categories.md > $(OUTPUT_DIR)/$(COUNTRY_NAME)_street_categories.md; then \
		echo "✓ Consolidation completed"; \
	else \
		echo "✗ Consolidation failed"; \
		exit 1; \
	fi
	@rm -rf chunks
	@echo "Cleaned up temporary chunk files"

all: osm city streets clean

.PHONY: venv osm city streets clean categorize

# -----------------------
# Docker helpers
# -----------------------
DOCKER_IMAGE ?= country-streets:latest

.PHONY: docker-build docker-run docker-shell compose-up

docker-build:
	docker build -t $(DOCKER_IMAGE) .

# Run the full pipeline inside Docker with bind mounts for outputs
docker-run: docker-build
	docker run --rm \
	  -e COUNTRY=$(COUNTRY) \
	  -v $(PWD)/osm:/app/osm \
	  -v $(PWD)/data:/app/data \
	  -v $(PWD)/output:/app/output \
	  -v $(PWD)/filtered:/app/filtered \
	  $(DOCKER_IMAGE) make all

# Interactive shell for debugging in the image
docker-shell: docker-build
	docker run --rm -it \
	  -e COUNTRY=$(COUNTRY) \
	  -v $(PWD)/osm:/app/osm \
	  -v $(PWD)/data:/app/data \
	  -v $(PWD)/output:/app/output \
	  -v $(PWD)/filtered:/app/filtered \
	  $(DOCKER_IMAGE) bash

# Compose convenience
compose-up:
	COUNTRY=$(COUNTRY) docker compose up --build
