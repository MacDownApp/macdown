SASS = node_modules/.bin/sass

target = ../../MacDown/Resources/Styles/GitHub-2020.css

all: $(target)

$(target): index.sass package-lock.json
	$(SASS) --load-path=node_modules $< | sed s/.markdown-body/body/ > $@

clean:
	$(RM) $(target)

.PHONY: all clean
