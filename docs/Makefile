all:
	rm -Rf out/
	mkdir out/
	pandoc index.md > index.html
	cd manual/ && make
	mv manual/out/ out/manual/
