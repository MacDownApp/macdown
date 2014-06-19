ALL : pmh_parser.c

GREGDIR=greg
GREG=$(GREGDIR)/greg

$(GREG):
	make -C $(GREGDIR)

pmh_parser_core.c : pmh_grammar.leg $(GREG)
	$(GREG) -o $@ $<

pmh_parser.c : pmh_parser_core.c pmh_parser_head.c pmh_parser_foot.c tools/combine_parser_files.sh
	./tools/combine_parser_files.sh > $@

.PHONY: clean test

clean:
	rm -f pmh_parser_core.c pmh_parser.c *.o; \
	rm -rf *.dSYM; \
	make -C $(GREGDIR) spotless

distclean: clean
