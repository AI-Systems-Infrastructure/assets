# Render every page of the draw.io sources in src/ to png/<page>.png and pdf/<page>.pdf.
#
# Each page is named after the image it produces, so one .drawio file can hold several
# related images. Sources must be saved uncompressed (draw.io: File > Properties, untick
# "Compressed"), so that page sizes can be read from them here.
#
#   make            render everything that is out of date (make -j4 renders in parallel)
#   make png/<page>.png, make pdf/<page>.pdf
#   make clean      remove all rendered images

DRAWIO ?= drawio
MAGICK ?= magick
# Pixel density of the PNGs (integer).
SCALE  ?= 2

SOURCES := $(wildcard src/*.drawio)

# One word per page: <source>:<page index>:<page name>:<width>:<height>:<background>
PAGES := $(shell awk ' \
	function attr(key,   s) { \
		if (!match($$0, "(^|[ \t\n])" key "=\"[^\"]*\"")) return ""; \
		s = substr($$0, RSTART, RLENGTH); sub(/^[^"]*"/, "", s); sub(/"$$/, "", s); return s \
	} \
	BEGIN { RS = "<diagram " } \
	FNR > 1 { \
		w = attr("pageWidth"); h = attr("pageHeight"); bg = attr("background"); \
		if (w == "" || h == "") { print "UNREADABLE:" FILENAME; next } \
		print FILENAME ":" FNR - 1 ":" attr("name") ":" w ":" h ":" (bg == "" ? "none" : bg) \
	}' $(SOURCES))

ifneq ($(filter UNREADABLE:%,$(PAGES)),)
$(error Cannot read page sizes from $(patsubst UNREADABLE:%,%,$(filter UNREADABLE:%,$(PAGES))); save it uncompressed)
endif

field = $(word $2,$(subst :, ,$1))
NAMES := $(foreach p,$(PAGES),$(call field,$p,3))

all: $(NAMES:%=png/%.png) $(NAMES:%=pdf/%.pdf)

# $(call page,<source>,<index>,<name>,<width>,<height>,<background>)
# Page export pads the PNG by 1px on the right and bottom, so it is cropped back to the
# page size; pages without a background are exported with a transparent one.
define page
png/$3.png: $1 | png
	@echo "render $$@"
	@rm -f $$@
	@$$(DRAWIO) -x -f png -p $2 -s $$(SCALE) --size page $(if $(filter none,$6),-t) -o $$@ $$< >/dev/null 2>&1
	@$$(MAGICK) $$@ -crop $$$$(( $4 * $$(SCALE) ))x$$$$(( $5 * $$(SCALE) ))+0+0 +repage $$@

pdf/$3.pdf: $1 | pdf
	@echo "render $$@"
	@rm -f $$@
	@$$(DRAWIO) -x -f pdf -p $2 -o $$@ $$< >/dev/null 2>&1
	@test -s $$@ || { echo "draw.io failed to export $$@" >&2; exit 1; }
endef

$(foreach p,$(PAGES),$(eval $(call page,$(call field,$p,1),$(call field,$p,2),$(call field,$p,3),$(call field,$p,4),$(call field,$p,5),$(call field,$p,6))))

png pdf:
	mkdir -p $@

clean:
	rm -f $(NAMES:%=png/%.png) $(NAMES:%=pdf/%.pdf)

.PHONY: all clean
