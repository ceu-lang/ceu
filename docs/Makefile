all:
	rm -Rf out/manual/$(VERSION)/
	mkdir -p out/manual/
	cd manual/$(VERSION)/ && mkdocs build --clean && mkdocs2pandoc > ceu-$(VERSION).md && pandoc ceu-$(VERSION).md -o ceu-$(VERSION).pdf && mv site/ ../../out/manual/$(VERSION)/
	pandoc manual/index.md > out/index.html
