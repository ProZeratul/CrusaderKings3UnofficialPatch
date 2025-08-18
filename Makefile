NAME := CK3_FixPack
VERSION := $(shell cat VERSION)

.PHONY: tiger
tiger:
	ck3-tiger --no-color . > ck3-tiger.out
	cat ck3-tiger.out

.PHONY: build
build: clean
	mkdir -p tmp/$(NAME)
	rsync -r --exclude=".*" --exclude=tmp --exclude=images --exclude=misc --exclude=Makefile --exclude=description.txt --exclude=LICENSE.md --exclude=VERSION --exclude=ck3-tiger.conf --exclude CHANGELOG.csv . tmp/$(NAME)
	cp descriptor.mod tmp/$(NAME).mod
	echo "path=\"mod/$(NAME)\"" >> tmp/$(NAME).mod
	cd tmp && zip -r $(NAME)-$(VERSION).zip . && cd ..

.PHONY: clean
clean:
	rm -rf tmp
	rm -f ck3-tiger.out

.PHONY: update-version
update-version:
	sed -i 's/$(VERSION)/$(NEW_VERSION)/g' descriptor.mod VERSION
