# --- DOCKER --- #
DOCKER=docker
IMAGE="heisengarg/comdb2-dev"
VERSION="latest"
CONTAINER="comdb2dev"
CNTHOME="/home/heisengarg"
CNTLRLOPTSLOC="$(CNTHOME)/lrl.options"

# --- HOST --- #
SRCDIR="$(shell pwd)/.."
LCLVOLDIR="$(shell pwd)/volumes"
LRLOPTSFILE="$(shell pwd)/lrl.options"

# --- DB --- #
CLUSTHOSTS="node1,node2,node3"
DBNAME="mogargdb"

.PHONY: buildi
buildi: Dockerfile
	$(DOCKER) build --pull -t $(IMAGE):$(VERSION) .

.PHONY: mkvol
mkvol:
	mkdir -p volumes

.PHONY: runc
runc: clean mkvol buildi
	$(DOCKER) run -d --mount type=volume,source=comdb2-dbs,target="$(CNTHOME)/dbs" \
		--cap-add=all \
		--privileged \
	   	--mount type=volume,source=comdb2-opt-bb,target=/opt/bb/ \
	   	--mount type=bind,source="$(SRCDIR)",target=$(CNTHOME)/comdb2,consistency=delegated \
	   	--mount type=bind,source=$(LCLVOLDIR),target=$(CNTHOME)/volumes \
		-w $(CNTHOME) --hostname=$(CONTAINER) --name=$(CONTAINER)\
	   	 -it $(IMAGE):$(VERSION) watch uptime && docker exec -it $(CONTAINER) zsh

.PHONY: runs
runs: clean mkvol
	$(DOCKER) run -d --mount type=volume,source=comdb2-dbs,target="$(CNTHOME)/dbs" \
		--cap-add=all \
		--privileged \
		--mount type=volume,source=comdb2-src,target=$(CNTHOME)/comdb2 \
	   	--mount type=volume,source=comdb2-opt-bb,target=/opt/bb/ \
	   	--mount type=bind,source="$(HOME)/.ssh",target=$(CNTHOME)/.ssh,consistency=cached \
	   	--mount type=bind,source=$(LCLVOLDIR),target=$(CNTHOME)/volumes \
		-w $(CNTHOME) --hostname=$(CONTAINER) --name=$(CONTAINER)\
	   	 -it $(IMAGE):$(VERSION) watch uptime && docker exec -it $(CONTAINER) zsh

.PHONY: newdb
newdb:
	$(DOCKER) run --mount type=volume,source=comdb2-dbs,target=$(CNTHOME)/dbs \
		-e LRLFILEOPTSPATH=$(CNTLRLOPTSLOC) \
		--mount type=bind,source=$(LRLOPTSFILE),target=$(CNTLRLOPTSLOC),readonly \
	   	--mount type=volume,source=comdb2-opt-bb,target=/opt/bb/ \
		-w $(CNTHOME) -it $(IMAGE):$(VERSION) db $(DBNAME) 

.PHONY: run
run: clean
	$(DOCKER) run -p 5105:5105 -p 19000:19000 \
		--cap-add=all \
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
	$(DOCKER) run -it --rm --mount type=volume,source=comdb2-dbs,target=$(CNTHOME)/dbs \
	   	--mount type=volume,source=comdb2-opt-bb,target=/opt/bb/ \
	   	--mount type=bind,source=$(LCLVOLDIR),target=$(CNTHOME)/volumes,consistency=delegated \
		-it $(IMAGE):$(VERSION) clust $(DBNAME) $(CLUSTHOSTS)

.PHONY: clustbin
clustbin: mkvol 
	$(DOCKER) run -it --rm --mount type=volume,source=comdb2-dbs,target=$(CNTHOME)/dbs \
	   	--mount type=volume,source=comdb2-opt-bb,target=/opt/bb/ \
	   	--mount type=bind,source=$(LCLVOLDIR),target=$(CNTHOME)/volumes,consistency=delegated \
		-it $(IMAGE):$(VERSION) clustbin $(DBNAME) $(CLUSTHOSTS)

.PHONY: uclust
uclust: clustbin docker-compose.yaml
	$(DOCKER) compose up -d

.PHONY: sclust
sclust: docker-compose.yaml 
	$(DOCKER) compose stop

.PHONY: dclust
dclust: docker-compose.yaml 
	$(DOCKER) compose down --remove-orphans 
	rm -rf volumes/*-ssh

.PHONY: cclust
cclust:
	$(DOCKER) exec -it client /bin/zsh

.PHONEY: lclust
lclust: 
	./client.sh -l -d $(DBNAME) -n $(CLUSTHOSTS)

.PHONY: client 
client:
	./client.sh -d $(DBNAME) -n $(CLUSTHOSTS)

.PHONY: clean
clean:
	docker rm -f $(CONTAINER)

.PHONY: logs
logs:
	docker log $(CONTAINER)
