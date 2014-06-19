/* PEG Markdown Highlight
 * Copyright 2011-2013 Ali Rantakari -- http://hasseg.org
 * Licensed under the GPL2+ and MIT licenses (see LICENSE for more info).
 * 
 * pmh_parser_foot.c
 * 
 * Code to be appended to the end of the parser code generated from the
 * PEG grammar.
 */


static void _parse(parser_data *p_data, yyrule start_rule)
{
    GREG *g = YY_NAME(parse_new)(p_data);
    if (start_rule == NULL)
        YY_NAME(parse)(g);
    else
        YY_NAME(parse_from)(g, start_rule);
    YY_NAME(parse_free)(g);
    
    pmh_PRINTF("\n\n");
}

static void parse_markdown(parser_data *p_data)
{
    pmh_PRINTF("\nPARSING DOCUMENT: ");
    
    _parse(p_data, NULL);
}

static void parse_references(parser_data *p_data)
{
    pmh_PRINTF("\nPARSING REFERENCES: ");
    
    p_data->parsing_only_references = true;
    _parse(p_data, yy_References);
    p_data->parsing_only_references = false;
    
    p_data->references = p_data->head_elems[pmh_REFERENCE];
    p_data->head_elems[pmh_REFERENCE] = NULL;
}

