# Avangenio Status — tareas de build y distribución.
# Los scripts viven en scripts/. La versión sale de MARKETING_VERSION (project.yml)
# salvo que pases VERSION=X.Y.Z.

.PHONY: generate build test bundle dmg release cask clean

## generate: regenera el .xcodeproj desde project.yml
generate:
	xcodegen generate

## build: compila la app (Debug, sin firmar) para desarrollo
build: generate
	xcodebuild build -project AvangenioStatus.xcodeproj -scheme AvangenioStatus \
		-destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO

## test: corre los tests unitarios
test: generate
	xcodebuild test -project AvangenioStatus.xcodeproj -scheme AvangenioStatus \
		-destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO

## bundle: compila Release universal y arma dist/AvangenioStatus.app (firma ad-hoc)
bundle:
	scripts/bundle.sh

## dmg: genera dist/AvangenioStatus.dmg
dmg:
	scripts/make-dmg.sh

## release: valida, testea y empuja el tag vX.Y.Z (dispara el workflow de release)
release:
	scripts/release.sh

## cask: actualiza el Homebrew cask del tap (uso manual; normalmente lo hace CI)
##        ej: make cask VERSION=1.0
cask:
	scripts/update-cask.sh $(VERSION)

## clean: borra artefactos de build
clean:
	rm -rf build dist
