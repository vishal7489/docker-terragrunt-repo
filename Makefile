.PHONY: phony
phony: help

# Provide versions of Terraform and Terragrunt to use with this Docker image
TF_VERSION := 0.14.6
TG_VERSION := 0.25.3

# GitHub Actions bogus variables
GITHUB_REF ?= refs/heads/null
GITHUB_SHA ?= aabbccddeeff

# Set version tags
TF_LATEST := $(shell curl -s 'https://api.github.com/repos/hashicorp/terraform/releases/latest' | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/^v//')
TG_LATEST := $(shell curl -s 'https://api.github.com/repos/gruntwork-io/terragrunt/releases/latest' | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/^v//')
VERSION := tf-$(TF_VERSION)-tg-$(TG_VERSION)
VERSION_LATEST := tf-$(TF_LATEST)-tg-$(TG_LATEST)

# Other variables and constants
CURRENT_BRANCH := $(shell echo $(GITHUB_REF) | sed 's/refs\/heads\///')
GITHUB_SHORT_SHA := $(shell echo $(GITHUB_SHA) | cut -c1-7)
DOCKER_USER_ID := learnawstechclub
DOCKER_ORG_NAME := devopsinfra
DOCKER_IMAGE := docker-terragrunt
DOCKER_NAME := $(DOCKER_ORG_NAME)/$(DOCKER_IMAGE)
GITHUB_USER_ID := Vishal7489
GITHUB_ORG_NAME := devops-infra
GITHUB_NAME := $(GITHUB_ORG_NAME)/$(DOCKER_IMAGE)
BUILD_DATE := $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")

# Some cosmetics
SHELL := bash
TXT_RED := $(shell tput setaf 1)
TXT_GREEN := $(shell tput setaf 2)
TXT_YELLOW := $(shell tput setaf 3)
TXT_RESET := $(shell tput sgr0)
define NL


endef

# Main actions
.PHONY: help check build build-plain build-aws build-gcp build-azure push-docker push-github

help: ## Display help prompt
	$(info Available options:)
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "$(TXT_YELLOW)%-25s $(TXT_RESET) %s\n", $$1, $$2}'

check: ## Check TF and TG versions
	$(info $(NL)$(TXT_GREEN) == CURRENT VERSIONS ==$(TXT_RESET))
	$(info $(TXT_GREEN)Current Terraform:$(TXT_YELLOW)  $(TF_VERSION)$(TXT_RESET))
	$(info $(TXT_GREEN)Current Terragrunt:$(TXT_YELLOW) $(TG_VERSION)$(TXT_RESET))
	$(info $(TXT_GREEN)Current tag:$(TXT_YELLOW)        $(VERSION)$(TXT_RESET))
	@if [[ $(VERSION) != $(VERSION_LATEST) ]]; then \
  		echo -e "\n$(TXT_YELLOW) == UPDATING VERSIONS ==$(TXT_RESET)"; \
  		echo -e "$(TXT_GREEN)Latest Terraform:$(TXT_YELLOW)     $(TF_LATEST)$(TXT_RESET)"; \
  		echo -e "$(TXT_GREEN)Latest Terragrunt:$(TXT_YELLOW)    $(TG_LATEST)$(TXT_RESET)"; \
  		echo -e "$(TXT_GREEN)Latest tag:$(TXT_YELLOW)           $(VERSION_LATEST)$(TXT_RESET)"; \
  		echo "VERSION_TAG=$(VERSION_LATEST)" >> $(GITHUB_ENV) ; \
		find . -type f -name "*" -print0 | xargs -0 sed -i "s/$(TG_VERSION)/$(TG_LATEST)/g"; \
		find . -type f -name "*" -print0 | xargs -0 sed -i "s/$(TF_VERSION)/$(TF_LATEST)/g"; \
	else \
		echo "VERSION_TAG=null" >> $(GITHUB_ENV) ; \
		echo -e "\n$(TXT_YELLOW) == NO CHANGES NEEDED ==$(TXT_RESET)"; \
	fi

build: check build-plain build-aws ## Build Docker images

build-plain: ## Build image without cloud CLIs
	$(info $(NL)$(TXT_GREEN)Building Docker image:$(TXT_YELLOW) $(DOCKER_NAME):$(VERSION)$(TXT_RESET))
	@docker build \
		--build-arg TF_VERSION=$(TF_VERSION) \
		--build-arg TG_VERSION=$(TG_VERSION) \
		--build-arg VCS_REF=$(GITHUB_SHORT_SHA) \
		--build-arg BUILD_DATE=$(BUILD_DATE) \
		--file=Dockerfile \
		--tag=$(DOCKER_NAME):$(VERSION) .

build-aws: ## Build image with AWS CLI
	$(info $(NL)$(TXT_GREEN)Building Docker image:$(TXT_YELLOW) $(DOCKER_NAME):aws-$(VERSION)$(TXT_RESET))
	@docker build \
		--build-arg AWS=yes \
		--build-arg TF_VERSION=$(TF_VERSION) \
		--build-arg TG_VERSION=$(TG_VERSION) \
		--build-arg VCS_REF=$(GITHUB_SHORT_SHA) \
		--build-arg BUILD_DATE=$(BUILD_DATE) \
		--file=Dockerfile \
		--tag=$(DOCKER_NAME):aws-$(VERSION) .

push-docker: ## Push to DockerHub
	$(info $(NL)$(TXT_GREEN) == STARTING DEPLOYMENT TO DOCKERHUB == $(TXT_RESET))
	$(info $(NL)$(TXT_GREEN)Logging to DockerHub$(TXT_RESET))
	@echo $(DOCKER_TOKEN) | docker login -u $(DOCKER_USER_ID) --password-stdin
	$(info $(NL)$(TXT_GREEN)Pushing image:$(TXT_YELLOW) $(DOCKER_NAME):$(VERSION)$(TXT_RESET))
	@docker tag $(DOCKER_NAME):$(VERSION) $(DOCKER_NAME):latest
	@docker push $(DOCKER_NAME):$(VERSION)
	@docker push $(DOCKER_NAME):latest
	$(info $(NL)$(TXT_GREEN)Pushing image:$(TXT_YELLOW) $(DOCKER_NAME):aws-$(VERSION)$(TXT_RESET))
	@docker tag $(DOCKER_NAME):aws-$(VERSION) $(DOCKER_NAME):aws-latest
	@docker push $(DOCKER_NAME):aws-$(VERSION)
	@docker push $(DOCKER_NAME):aws-latest
#	$(info $(NL)$(TXT_GREEN)Pushing image:$(TXT_YELLOW) $(DOCKER_NAME):gcp-$(VERSION)$(TXT_RESET))
#	@docker tag $(DOCKER_NAME):gcp-$(VERSION) $(DOCKER_NAME):gcp-latest
#	@docker push $(DOCKER_NAME):gcp-$(VERSION)
#	@docker push $(DOCKER_NAME):gcp-latest
#	$(info $(NL)$(TXT_GREEN)Pushing image:$(TXT_YELLOW) $(DOCKER_NAME):azure-$(VERSION)$(TXT_RESET))
#	@docker tag $(DOCKER_NAME):azure-$(VERSION) $(DOCKER_NAME):azure-latest
#	@docker push $(DOCKER_NAME):azure-$(VERSION)
#	@docker push $(DOCKER_NAME):azure-latest

push-github: ## Push to GitHub Container Registry
	$(info $(NL)$(TXT_GREEN) == STARTING DEPLOYMENT TO GITHUB == $(TXT_RESET))
	$(info $(NL)$(TXT_GREEN)Logging to GitHub$(TXT_RESET))
	@echo $(GITHUB_TOKEN) | docker login https://docker.pkg.github.com -u $(GITHUB_USER_ID) --password-stdin
	$(info $(NL)$(TXT_GREEN)Pushing image:$(TXT_YELLOW) docker.pkg.github.com/$(GITHUB_NAME)/$(DOCKER_IMAGE):$(VERSION)$(TXT_RESET))
	@docker tag $(DOCKER_NAME):$(VERSION) docker.pkg.github.com/$(GITHUB_NAME)/$(DOCKER_IMAGE):$(VERSION)
	@docker tag $(DOCKER_NAME):$(VERSION) docker.pkg.github.com/$(GITHUB_NAME)/$(DOCKER_IMAGE):latest
	@docker push docker.pkg.github.com/$(GITHUB_NAME)/$(DOCKER_IMAGE):$(VERSION)
	@docker push docker.pkg.github.com/$(GITHUB_NAME)/$(DOCKER_IMAGE):latest
	$(info $(NL)$(TXT_GREEN)Pushing image:$(TXT_YELLOW) docker.pkg.github.com/$(GITHUB_NAME)/$(DOCKER_IMAGE):aws-$(VERSION)$(TXT_RESET))
	@docker tag $(DOCKER_NAME):aws-$(VERSION) docker.pkg.github.com/$(GITHUB_NAME)/$(DOCKER_IMAGE):aws-$(VERSION)
	@docker tag $(DOCKER_NAME):aws-$(VERSION) docker.pkg.github.com/$(GITHUB_NAME)/$(DOCKER_IMAGE):aws-latest
	@docker push docker.pkg.github.com/$(GITHUB_NAME)/$(DOCKER_IMAGE):aws-$(VERSION)
	@docker push docker.pkg.github.com/$(GITHUB_NAME)/$(DOCKER_IMAGE):aws-latest
#	$(info $(NL)$(TXT_GREEN)Pushing image:$(TXT_YELLOW) docker.pkg.github.com/$(GITHUB_NAME)/$(DOCKER_IMAGE):gcp-$(VERSION)$(TXT_RESET))
#	@docker tag $(DOCKER_NAME):gcp-$(VERSION) docker.pkg.github.com/$(GITHUB_NAME)/$(DOCKER_IMAGE):gcp-$(VERSION)
#	@docker tag $(DOCKER_NAME):gcp-$(VERSION) docker.pkg.github.com/$(GITHUB_NAME)/$(DOCKER_IMAGE):gcp-latest
#	@docker push docker.pkg.github.com/$(GITHUB_NAME)/$(DOCKER_IMAGE):gcp-$(VERSION)
#	@docker push docker.pkg.github.com/$(GITHUB_NAME)/$(DOCKER_IMAGE):gcp-latest
#	$(info $(NL)$(TXT_GREEN)Pushing image:$(TXT_YELLOW) docker.pkg.github.com/$(GITHUB_NAME)/$(DOCKER_IMAGE)/$(DOCKER_IMAGE):azure-$(VERSION)$(TXT_RESET))
#	@docker tag $(DOCKER_NAME):azure-$(VERSION) docker.pkg.github.com/$(GITHUB_NAME)/$(DOCKER_IMAGE):azure-$(VERSION)
#	@docker tag $(DOCKER_NAME):azure-$(VERSION) docker.pkg.github.com/$(GITHUB_NAME)/$(DOCKER_IMAGE):azure-latest
#	@docker push docker.pkg.github.com/$(GITHUB_NAME)/$(DOCKER_IMAGE):azure-$(VERSION)
#	@docker push docker.pkg.github.com/$(GITHUB_NAME)/$(DOCKER_IMAGE):azure-latest
