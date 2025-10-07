APP_NAME=nextcloud-auto-install.sh

.PHONY: version tag show-version

version:
	@echo "Current version info:"
	@git describe --tags --always

tag:
	@if [ -z "$(v)" ]; then \
		echo "Usage: make tag v=v1.2.0"; \
		exit 1; \
	fi
	@git tag -a $(v) -m "Release $(v)"
	@git push origin $(v)
	@echo "✅ Tagged $(v) and pushed to GitHub."

show-version:
	@echo "Repository: billoven/MyNextCloudInstall"
	@git describe --tags --always
	@git rev-parse --short HEAD
	@git log -1 --format=%cd --date=short
