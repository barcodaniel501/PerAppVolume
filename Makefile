APP = PerAppVolume

.PHONY: app install run icon clean

## Build build/PerAppVolume.app (universal) and a release zip
app:
	./scripts/build-app.sh

## Build and copy the app to /Applications
install: app
	rm -rf "/Applications/$(APP).app"
	cp -R "build/$(APP).app" /Applications/
	@echo "Installed to /Applications/$(APP).app"

## Build and open the app
run: app
	open "build/$(APP).app"

## Regenerate AppBundle/AppIcon.icns
icon:
	swift scripts/make-icon.swift build/AppIcon.iconset
	iconutil -c icns build/AppIcon.iconset -o AppBundle/AppIcon.icns

clean:
	rm -rf .build build
