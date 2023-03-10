include .env

region_pbf = tmp/osm/$(REGION_NAME)-latest.osm.pbf
admin_osmjson = tmp/$(ADMIN_NAME).osm.json
admin_geojson = tmp/$(ADMIN_NAME).geojson
admin_poly = tmp/$(ADMIN_NAME).poly
admin_pbf = tmp/$(ADMIN_NAME).pbf
mbtiles = tmp/region.mbtiles
tilejson = docs/tiles.json
stylejson = docs/style.json
zxy_metadata = docs/zxy/metadata.json

targets = \
	docs/openmaptiles/fonts/Open\ Sans\ Bold/0-255.pbf \
	docs/openmaptiles/fonts/Open\ Sans\ Italic/0-255.pbf \
	docs/openmaptiles/fonts/Open\ Sans\ Regular/0-255.pbf \
	$(region_pbf) \
	$(mbtiles) \
	$(tilejson) \
	$(zxy_metadata) \
	$(stylejson) \
	#$(admin_osmjson) \
	#$(admin_geojson) \
	#$(admin_poly) \
	#$(admin_pbf) \


all: $(targets)

clean:
	sudo chmod 777 -R tmp
	rm -rf tmp/region.*
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
	sudo apt install -y libsqlite3-dev \
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
	cp config.json . && \
	cp process.lua .

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
	osmtogeojson $(admin_osmjson) > $(admin_geojson)\

# Convert GeoJSON to Poly file
$(admin_poly):
	geojson2poly $(admin_geojson) $(admin_poly)

# Extract only admin area OSM PBF from region OSM PBF
$(admin_pbf):
	osmconvert $(region_pbf) -B="$(admin_poly)" --complete-ways -o=$(admin_pbf)


# Convert OSM PBF to MBTiles format file
# TODO to selectable admin or reigon pbf
$(mbtiles):
	mkdir -p $(@D)
	tilemaker \
		--skip-integrity \
		--input $(region_pbf) \
		--output $(mbtiles)

# Generate TileJSON format file from MBTiles format file
$(tilejson):
	mbtiles2tilejson \
		tmp/region.mbtiles \
		--url $(TILES_URL) > docs/tiles.json
	sed "s|http://localhost:5000/|$(BASE_PATH)|g" -i docs/tiles.json

# Split MBTiles format file to zxy orderd Protocolbuffer Binary format files
$(zxy_metadata):
	mkdir -p $(@D)
	tile-join \
		--force \
		--no-tile-compression \
		--no-tile-size-limit \
		--no-tile-stats \
		--output-to-directory=tmp/zxy \
		$(mbtiles)
	cp -r tmp/zxy docs/

# Generate style.json from style.yml
$(stylejson):
	charites build style.yml docs/style.json
	sed "s|http://localhost:5000/|$(BASE_PATH)|g" -i docs/style.json

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
