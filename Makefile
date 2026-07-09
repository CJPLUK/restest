PACKAGES := restest_common apidiff

.PHONY: all $(PACKAGES)

all: $(PACKAGES)

$(PACKAGES):
	cd $@ && cjpm build
