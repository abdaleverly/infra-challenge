.PHONY: init
	@echo "replace bucket name in backend.tf"

.PHONY: build
build:
	@terraform init
	@terraform plan -out=tfplan -var=allowed_cidrs=$(CIDR);
	@terraform apply "tfplan"

# @terraform apply "tfplan"

.PHONY: help
help:
	@echo build: provisions and deploys infrastructure