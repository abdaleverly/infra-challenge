VARS := HTTP_CIDR

.PHONY: $(VARS)
$(VARS):
	@if [ "$($@)" = "" ]; then \
		echo "You must set $@ variable"; \
		exit 1; \
	fi

.PHONY: backend
backend:
	@if grep -n TF_S3_BACKEND_BUCKET_NAME *.tf; then \
		echo "Replace the 'TF_S3_BACKEND_BUCKET_NAME' variable with your S3 bucket to store terraform state"; \
		echo "See prerequisites section of the README"; \
		exit 1; \
	fi

.PHONY: init
init: backend
	$(info checking prerequisites...No error is a good thing)
EXECUTABLES = aws terraform
CHECK := $(foreach exec,$(EXECUTABLES),\
  $(if $(shell which $(exec)),All good,$(error "No $(exec) in PATH. See prerequisites section in README")))

.PHONY: build
build: init $(VARS)
	terraform init
	terraform plan -out=tfplan -var=allowed_cidrs=$(HTTP_CIDR);
	terraform apply "tfplan"

.PHONY: get-web-endpoint
get-web-endpoint:
	@terraform output -raw web_endpoint

.PHONY: clean
clean: backend $(VARS)
	@echo "cleaning out artifacts"
	aws s3 rm s3://$$(terraform output -raw artifact_bucket) --recursive
	terraform destroy -var=allowed_cidrs=$(HTTP_CIDR);

.PHONY: test
test:
	@export ENDPOINT=$$(terraform output -raw web_endpoint); \
	version=$$(curl -sS "$${ENDPOINT}/version" | jq -r '.version' 2> /dev/null || echo "NOT READY"); \
	if [ ! -z $(SHORT_HASH_OR_TAG) ]; then \
		if [ "$${version}" = "$(SHORT_HASH_OR_TAG)" ]; then \
			echo "SUCCESS"; \
		else \
			echo "$(SHORT_HASH_OR_TAG) NOT READY"; \
		fi; \
	else \
		echo $${version}; \
	fi

.PHONY: help
help:
	@echo "init:\t\t\tvalidate prerequisites"
	@echo "build:\t\t\tprovisions and deploys resources"
	@echo "get-web-endpoint:\toutput web endpoint"
	@echo "clean:\t\t\tcleans up resources"
	@echo "test:\t\t\tsmoke test web endpoint"