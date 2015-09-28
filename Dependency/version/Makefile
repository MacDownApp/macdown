ALL: version.h

version.h:
	bash ../../Tools/generate_version_header.sh

.PHONY: install clean distclean

install: ALL

clean:
	-rm version.h 2>/dev/null

distclean: clean
