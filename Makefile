.PHONY: app run install doctor test

app:
	scripts/bundle.sh

run: app
	open build/Gridspace.app

install: app
	rm -rf /Applications/Gridspace.app
	cp -R build/Gridspace.app /Applications/
	open /Applications/Gridspace.app

doctor: app
	build/Gridspace.app/Contents/MacOS/Gridspace --doctor

test:
	swift test
