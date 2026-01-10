.PHONY: setup teardown status context secrets-backup secrets-restore secrets-status help

setup: ## Full environment setup (Kind clusters + ArgoCD + stack)
	./scripts/gitops setup

teardown: ## Delete all clusters and resources
	./scripts/gitops teardown

status: ## Show cluster status
	./scripts/gitops cluster status

context: ## Switch kubectl context (usage: make context CLUSTER=dev-eu-central-1)
	./scripts/gitops context $(CLUSTER)

secrets-backup: ## Backup sealed secrets key
	./scripts/gitops secrets backup

secrets-restore: ## Restore sealed secrets key
	./scripts/gitops secrets restore

secrets-status: ## Show sealed secrets backup status
	./scripts/gitops secrets status

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-18s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
