# --- DOCKER --- #
DOCKER=docker
IMAGE="heisengarg/comdb2-dev"
VERSION="latest"
CONTAINER="comdb2dev"
CNTHOME="/home/heisengarg"

# --- HOST --- #
SRCDIR="$(shell pwd)/.."
LCLVOLDIR="$(shell pwd)/volumes"

# --- DB --- #
CLUSTHOSTS="node1,node2,node3"
DBNAME="mogargdb"

.PHONY: buildi
buildi: Dockerfile
	$(DOCKER) build -t $(IMAGE):$(VERSION) .

.PHONY: mkvol
mkvol:
	mkdir -p volumes

.PHONY: runc
runc: mkvol clean buildi
	$(DOCKER) run --mount type=volume,source=comdb2-dbs,target="$(CNTHOME)/dbs" \
	   	--mount type=volume,source=comdb2-opt-bb,target=/opt/bb/ \
	   	--mount type=bind,source="$(SRCDIR)",target=$(CNTHOME)/comdb2,consistency=delegated \
	   	--mount type=bind,source=$(LCLVOLDIR),target=$(CNTHOME)/volumes \
		-w $(CNTHOME) --hostname=$(CONTAINER) --name=$(CONTAINER)\
	   	 -it $(IMAGE):$(VERSION) shell 

.PHONY: newdb
newdb:
	$(DOCKER) run --mount type=volume,source=comdb2-dbs,target=$(CNTHOME)/dbs \
	   	--mount type=volume,source=comdb2-opt-bb,target=/opt/bb/ \
		-it $(IMAGE):$(VERSION) db $(DBNAME) 

.PHONY: run
run: clean
	$(DOCKER) run -p 5105:5105 -p 19000:19000 \
		--mount type=volume,source=comdb2-dbs,target=$(CNTHOME)/dbs \
	   	--mount type=volume,source=comdb2-opt-bb,target=/opt/bb/ \
		--name=$(CONTAINER) --hostname=$(CONTAINER) \
	   	-it $(IMAGE):$(VERSION) run $(DBNAME) 

.PHONY: build
build:
	$(DOCKER) run -it --rm --mount type=volume,source=comdb2-opt-bb,target=/opt/bb/ \
	   	--mount type=bind,source="$(SRCDIR)",target=$(CNTHOME)/comdb2,consistency=delegated \
		-w $(CNTHOME)/comdb2 $(IMAGE):$(VERSION) build

.PHONY: clust
clust: mkvol 
	$(DOCKER) run -it --mount type=volume,source=comdb2-dbs,target=$(CNTHOME)/dbs \
	   	--mount type=volume,source=comdb2-opt-bb,target=/opt/bb/ \
	   	--mount type=bind,source=$(LCLVOLDIR),target=$(CNTHOME)/volumes,consistency=delegated \
		-it $(IMAGE):$(VERSION) clust $(DBNAME) $(CLUSTHOSTS)

.PHONY: clean
clean:
	docker rm -f $(CONTAINER)

.PHONY: logs
logs:
	docker log $(CONTAINER)
