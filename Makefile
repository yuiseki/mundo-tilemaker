include .env

region_pbf = tmp/osm/$(REGION_NAME)-latest.osm.pbf
admin_osmjson = tmp/$(ADMIN_NAME).osm.json
admin_geojson = tmp/$(ADMIN_NAME).geojson
admin_poly = tmp/$(ADMIN_NAME).poly
admin_pbf = tmp/$(ADMIN_NAME).pbf
mbtiles = tmp/region.mbtiles
pmtiles = tmp/region.pmtiles
tilejson = docs/tiles.json
stylejson = docs/style.json
zxy_metadata = docs/zxy/metadata.json

targets = \
	docs/openmaptiles/fonts/Open\ Sans\ Bold/0-255.pbf \
	docs/openmaptiles/fonts/Open\ Sans\ Italic/0-255.pbf \
	docs/openmaptiles/fonts/Open\ Sans\ Regular/0-255.pbf \
	$(region_pbf) \
	$(admin_osmjson) \
	$(admin_geojson) \
	$(admin_poly) \
	$(admin_pbf) \
	$(mbtiles) \
	$(tilejson) \
	$(zxy_metadata) \
	$(stylejson)


all: $(targets)

clean:
	sudo chmod 777 -R tmp
	rm -rf docs/zxy/*
	rm -f docs/style.json
	rm -f docs/tiles.json

clean-all:
	sudo chmod 777 -R tmp
	rm -f $(admin_osmjson)
	rm -f $(admin_geojson)
	rm -f $(admin_poly)
	rm -f $(admin_pbf)
	rm -f $(mbtiles)
	rm -f $(tilejson)
	rm -f $(stylejson)
	rm -rf tmp/zxy/*
	rm -rf docs/zxy/*
	rm -rf docs/openmaptiles/fonts/Open\ Sans\ Bold
	rm -rf docs/openmaptiles/fonts/Open\ Sans\ Italic
	rm -rf docs/openmaptiles/fonts/Open\ Sans\ Regular

setup:
	npm install -g osmtogeojson
	npm install -g geojson2poly
	npm install -g mbtiles2tilejson
	npm install -g @unvt/charites
	npm install -g http-server

setup-tippecanoe:
	sudo echo "sudo OK" && \
	mkdir -p /tmp/src && \
	cd /tmp/src && \
	rm -rf tippecanoe && \
	git clone --depth 1 https://github.com/felt/tippecanoe.git && \
	cd /tmp/src/tippecanoe && \
	make -j && \
	sudo make install

setup-tilemaker:
	sudo echo "sudo OK" && \
	DEBIAN_FRONTEND=noninteractive sudo apt-get update && \
	DEBIAN_FRONTEND=noninteractive sudo apt-get install -y \
		libboost-dev \
		libboost-filesystem-dev \
		libboost-iostreams-dev \
		libboost-program-options-dev \
		libboost-system-dev \
		liblua5.1-0-dev \
		libprotobuf-dev \
		libshp-dev \
		protobuf-compiler \
		rapidjson-dev && \
	mkdir -p /tmp/src && \
	cd /tmp/src && \
	rm -rf tilemaker && \
	git clone --depth 1 https://github.com/systemed/tilemaker.git && \
	cd /tmp/src/tilemaker && \
	make -j && \
	sudo make install && \
	cp config.json $(CURDIR) && \
	cp process.lut $(CURDIR)

# Download OpenStreetMap data as Protocolbuffer Binary format file (OSM PBF)
$(region_pbf):
	mkdir -p $(@D)
	curl \
		--continue-at - \
		--output $(region_pbf) \
		https://download.geofabrik.de/$(REGION_NAME)-latest.osm.pbf

# Get boundary of the admin area as OpenStreetMap JSON (OSM JSON)
QUERY = data=[out:json][timeout:30000]; relation($(ADMIN_ID))["type"="boundary"]["boundary"="administrative"]["name"]; out geom;
$(admin_osmjson):
	curl 'https://overpass-api.de/api/interpreter' \
		--data-urlencode '$(QUERY)' > $(admin_osmjson)

# Convert Overpass OSM JSON to GeoJSON
$(admin_geojson):
	osmtogeojson $(CURDIR)/$(admin_osmjson) > $(CURDIR)/$(admin_geojson)\

# Convert GeoJSON to Poly file
$(admin_poly):
	geojson2poly $(CURDIR)/$(admin_geojson) $(CURDIR)/$(admin_poly)

# Extract only admin area OSM PBF from region OSM PBF
$(admin_pbf):
	osmconvert $(CURDIR)/$(region_pbf) -B="$(CURDIR)/$(admin_poly)" --complete-ways -o=$(CURDIR)/$(admin_pbf)


# Convert OSM PBF to MBTiles format file
$(mbtiles):
	tilemaker \
		--threads 3 \
		--skip-integrity \
		--input $(CURDIR)/$(admin_pbf) \
		--output $(CURDIR)/$(mbtiles)

# Generate TileJSON format file from MBTiles format file
$(tilejson):
	mbtiles2tilejson \
		$(CURDIR)/tmp/region.mbtiles \
		--url $(TILES_URL) > $(CURDIR)/docs/tiles.json
	sed "s|http://localhost:5000/|$(BASE_PATH)|g" -i $(CURDIR)/docs/tiles.json

# Split MBTiles format file to zxy orderd Protocolbuffer Binary format files
$(zxy_metadata):
	mkdir -p $(@D)
	tile-join \
		--force \
		--no-tile-compression \
		--no-tile-size-limit \
		--no-tile-stats \
		--output-to-directory=$(CURDIR)/tmp/zxy \
		$(CURDIR)/$(mbtiles)
	cp -r tmp/zxy docs/

# Generate style.json from style.yml
$(stylejson):
	charites build $(CURDIR)/style.yml $(CURDIR)/docs/style.json
	sed "s|http://localhost:5000/|$(BASE_PATH)|g" -i $(CURDIR)/docs/style.json

docs/openmaptiles/fonts/Open\ Sans\ Bold/0-255.pbf:
	cd docs/openmaptiles/fonts && unzip Open\ Sans\ Bold.zip
	chmod 777 -R docs/openmaptiles/fonts

docs/openmaptiles/fonts/Open\ Sans\ Italic/0-255.pbf:
	cd docs/openmaptiles/fonts && unzip Open\ Sans\ Italic.zip
	chmod 777 -R docs/openmaptiles/fonts

docs/openmaptiles/fonts/Open\ Sans\ Regular/0-255.pbf:
	cd docs/openmaptiles/fonts && unzip Open\ Sans\ Regular.zip
	chmod 777 -R docs/openmaptiles/fonts

# Launch local tile server
.PHONY: start
start:
	http-server \
		-p $(PORT) \
		docs
