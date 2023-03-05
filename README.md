# mundo-tilemaker

## What?

- MUNDO is an acronym for "Model United Nations Development and Operations"
- MUNDO is a Model United Nations focusing on UN peacekeeping operations and the UNDP
- mundo-tilemaker is a vector tile maps building tool that places the highest priority on portability and deployability
- mundo-tilemaker is based on OpenStreetMap, tilemaker, tippecanoe and charites
- mundo-tilemaker is a variant of the vector-tile-builder
  - https://github.com/yuiseki/vector-tile-builder
- The difference between mundo-tilemaker and vector-tile-builder is in whether it depends on Docker
  - vector-tile-builder was highly dependent on Docker
  - mundo-tilemaker does not depend on Docker in any way
    - mundo-tilemaker makes it possible to build vector tile maps even in situations where using Docker is difficult
- mundo-tilemaker is developed to be used in combination with mundo-maps
  - https://github.com/yuiseki/mundo-maps
