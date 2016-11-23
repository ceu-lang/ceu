all:
	mkdir -p out/
	pandoc index.md > out/index.html
	cd manual/ && make
	mv manual/out/ out/manual/
