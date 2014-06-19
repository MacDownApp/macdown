/* PEG Markdown Highlight
 * Copyright 2011-2013 Ali Rantakari -- http://hasseg.org
 * Licensed under the GPL2+ and MIT licenses (see LICENSE for more info).
 * 
 * pmh_parser_head.c
 * 
 * Code to be inserted into the beginning of the parser code generated
 * from the PEG grammar.
 */

#include "pmh_parser.h"

#ifndef pmh_DEBUG_OUTPUT
#define pmh_DEBUG_OUTPUT 0
#endif

#if pmh_DEBUG_OUTPUT
#define pmh_IF(x)           if (x)
#define pmh_PRINTF(x, ...)  fprintf(stderr, x, ##__VA_ARGS__)
#define pmh_PUTCHAR(x)      putchar(x)
#else
#define pmh_IF(x)
#define pmh_PRINTF(x, ...)
#define pmh_PUTCHAR(x)
#endif



// Alias strdup to _strdup on MSVC:
#ifdef _MSC_VER
#define strdup _strdup
#endif



// Internal language element occurrence structure, containing
// both public and private members:
struct pmh_RealElement
{
    // "Public" members:
    // (these must match what's defined in pmh_definitions.h)
    // -----------------------------------------------
    pmh_element_type type;
    unsigned long pos;
    unsigned long end;
    struct pmh_RealElement *next;
    char *label;
    char *address;
    
    // "Private" members for use by the parser itself:
    // -----------------------------------------------
    
    // next element in list of all elements:
    struct pmh_RealElement *all_elems_next;
    
    // offset to text (for elements of type pmh_EXTRA_TEXT, used when the
    // parser reads the value of 'text'):
    int text_offset;
    
    // text content (for elements of type pmh_EXTRA_TEXT):
    char *text;
    
    // children of element (for elements of type pmh_RAW_LIST)
    struct pmh_RealElement *children;
};
typedef struct pmh_RealElement pmh_realelement;




// Parser state data:
typedef struct
{
    /* The original, unmodified UTF-8 input: */
    char *original_input;
    
    /* The offsets of the bytes we have stripped from original_input: */
    unsigned long *strip_positions;
    size_t strip_positions_len;
    
    /* Buffer of characters to be parsed: */
    char *charbuf;
    
    /* Linked list of {start, end} offset pairs determining which parts */
    /* of charbuf to actually parse: */
    pmh_realelement *current_elem;
    pmh_realelement *elem_head;
    
    /* Current parsing offset within charbuf: */
    unsigned long offset;
    
    /* The extensions to use for parsing (bitfield */
    /* of enum pmh_extensions): */
    int extensions;
    
    /* Array of parsing result elements, indexed by type: */
    pmh_realelement **head_elems;
    
    /* Whether we are parsing only references: */
    bool parsing_only_references;
    
    /* List of reference elements: */
    pmh_realelement *references;
} parser_data;

static parser_data *mk_parser_data(char *original_input,
                                   unsigned long *strip_positions,
                                   size_t strip_positions_len,
                                   char *charbuf,
                                   pmh_realelement *parsing_elems,
                                   unsigned long offset,
                                   int extensions,
                                   pmh_realelement **head_elems,
                                   pmh_realelement *references)
{
    parser_data *p_data = (parser_data *)malloc(sizeof(parser_data));
    p_data->extensions = extensions;
    p_data->original_input = original_input;
    p_data->strip_positions = strip_positions;
    p_data->strip_positions_len = strip_positions_len;
    p_data->charbuf = charbuf;
    p_data->offset = offset;
    p_data->elem_head = p_data->current_elem = parsing_elems;
    p_data->references = references;
    p_data->parsing_only_references = false;
    if (head_elems != NULL)
        p_data->head_elems = head_elems;
    else {
        p_data->head_elems = (pmh_realelement **)
                             malloc(sizeof(pmh_realelement *) * pmh_NUM_TYPES);
        int i;
        for (i = 0; i < pmh_NUM_TYPES; i++)
            p_data->head_elems[i] = NULL;
    }
    return p_data;
}


// Forward declarations
static void parse_markdown(parser_data *p_data);
static void parse_references(parser_data *p_data);





static char **get_element_type_names()
{
    static char **elem_type_names = NULL;
    if (elem_type_names == NULL)
    {
        elem_type_names = (char **)malloc(sizeof(char*) * pmh_NUM_LANG_TYPES);
        int i;
        for (i = 0; i < pmh_NUM_LANG_TYPES; i++)
            elem_type_names[i] = NULL;
        elem_type_names[pmh_LINK] = "LINK";
        elem_type_names[pmh_AUTO_LINK_URL] = "AUTO_LINK_URL";
        elem_type_names[pmh_AUTO_LINK_EMAIL] = "AUTO_LINK_EMAIL";
        elem_type_names[pmh_IMAGE] = "IMAGE";
        elem_type_names[pmh_CODE] = "CODE";
        elem_type_names[pmh_HTML] = "HTML";
        elem_type_names[pmh_HTML_ENTITY] = "HTML_ENTITY";
        elem_type_names[pmh_EMPH] = "EMPH";
        elem_type_names[pmh_STRONG] = "STRONG";
        elem_type_names[pmh_LIST_BULLET] = "LIST_BULLET";
        elem_type_names[pmh_LIST_ENUMERATOR] = "LIST_ENUMERATOR";
        elem_type_names[pmh_COMMENT] = "COMMENT";
        elem_type_names[pmh_H1] = "H1";
        elem_type_names[pmh_H2] = "H2";
        elem_type_names[pmh_H3] = "H3";
        elem_type_names[pmh_H4] = "H4";
        elem_type_names[pmh_H5] = "H5";
        elem_type_names[pmh_H6] = "H6";
        elem_type_names[pmh_BLOCKQUOTE] = "BLOCKQUOTE";
        elem_type_names[pmh_VERBATIM] = "VERBATIM";
        elem_type_names[pmh_HTMLBLOCK] = "HTMLBLOCK";
        elem_type_names[pmh_HRULE] = "HRULE";
        elem_type_names[pmh_REFERENCE] = "REFERENCE";
        elem_type_names[pmh_NOTE] = "NOTE";
    }
    return elem_type_names;
}

pmh_element_type pmh_element_type_from_name(char *name)
{
    char **elem_type_names = get_element_type_names();
    
    int i;
    for (i = 0; i < pmh_NUM_LANG_TYPES; i++)
    {
        char *i_name = elem_type_names[i];
        if (i_name == NULL)
            continue;
        if (strcmp(i_name, name) == 0)
            return i;
    }
    
    return pmh_NO_TYPE;
}

char *pmh_element_name_from_type(pmh_element_type type)
{
    char **elem_type_names = get_element_type_names();
    char* ret = elem_type_names[type];
    if (ret == NULL)
        return "unknown type";
    return ret;
}




/*
Remove pmh_RAW elements with zero length; return pointer
to new head.
*/
static pmh_realelement *remove_zero_length_raw_spans(pmh_realelement *elem)
{
    pmh_realelement *head = elem;
    pmh_realelement *parent = NULL;
    pmh_realelement *c = head;
    while (c != NULL)
    {
        if (c->type == pmh_RAW && c->pos >= c->end)
        {
            if (parent != NULL)
                parent->next = c->next;
            else
                head = c->next;
            parent = c;
            c = c->next;
            continue;
        }
        parent = c;
        c = c->next;
    }
    return head;
}

#if pmh_DEBUG_OUTPUT
/*
Print null-terminated string s.t. some characters are
represented by their corresponding espace sequences
*/
static void print_str_literal_escapes(char *str)
{
    char *c = str;
    pmh_PRINTF("'");
    while (*c != '\0')
    {
        if (*c == '\n')         pmh_PRINTF("\\n");
        else if (*c == '\t')    pmh_PRINTF("\\t");
        else putchar(*c);
        c++;
    }
    pmh_PRINTF("'");
}
#endif

#if pmh_DEBUG_OUTPUT
/*
Print elements in a linked list of
pmh_RAW, pmh_SEPARATOR, pmh_EXTRA_TEXT elements
*/
static void print_raw_spans_inline(pmh_realelement *elem)
{
    pmh_realelement *cur = elem;
    while (cur != NULL)
    {
        if (cur->type == pmh_SEPARATOR)
            pmh_PRINTF("<pmh_SEP %ld> ", cur->pos);
        else if (cur->type == pmh_EXTRA_TEXT) {
            pmh_PRINTF("{pmh_ETEXT ");
            print_str_literal_escapes(cur->text);
            pmh_PRINTF("}");
        }
        else
            pmh_PRINTF("(%ld-%ld) ", cur->pos, cur->end);
        cur = cur->next;
    }
}
#endif

/*
Perform postprocessing parsing runs for pmh_RAW_LIST elements in `elem`,
iteratively until no such elements exist.
*/
static void process_raw_blocks(parser_data *p_data)
{
    pmh_PRINTF("--------process_raw_blocks---------\n");
    while (p_data->head_elems[pmh_RAW_LIST] != NULL)
    {
        pmh_PRINTF("new iteration.\n");
        pmh_realelement *cursor = p_data->head_elems[pmh_RAW_LIST];
        p_data->head_elems[pmh_RAW_LIST] = NULL;
        while (cursor != NULL)
        {
            pmh_realelement *span_list = (pmh_realelement*)cursor->children;
            
            span_list = remove_zero_length_raw_spans(span_list);
            
            #if pmh_DEBUG_OUTPUT
            pmh_PRINTF("  process: ");
            print_raw_spans_inline(span_list);
            pmh_PRINTF("\n");
            #endif
            
            while (span_list != NULL)
            {
                pmh_PRINTF("next: span_list: %ld-%ld\n",
                           span_list->pos, span_list->end);
                
                // Skip separators in the beginning, as well as
                // separators after another separator:
                if (span_list->type == pmh_SEPARATOR) {
                    span_list = span_list->next;
                    continue;
                }
                
                // Store list of spans until next separator in subspan_list:
                pmh_realelement *subspan_list = span_list;
                pmh_realelement *previous = NULL;
                while (span_list != NULL && span_list->type != pmh_SEPARATOR) {
                    previous = span_list;
                    span_list = span_list->next;
                }
                if (span_list != NULL && span_list->type == pmh_SEPARATOR) {
                    span_list = span_list->next;
                    previous->next = NULL;
                }
                
                #if pmh_DEBUG_OUTPUT
                pmh_PRINTF("    subspan process: ");
                print_raw_spans_inline(subspan_list);
                pmh_PRINTF("\n");
                #endif
                
                // Process subspan_list:
                parser_data *raw_p_data = mk_parser_data(
                    p_data->original_input,
                    p_data->strip_positions,
                    p_data->strip_positions_len,
                    p_data->charbuf,
                    subspan_list,
                    subspan_list->pos,
                    p_data->extensions,
                    p_data->head_elems,
                    p_data->references
                );
                parse_markdown(raw_p_data);
                free(raw_p_data);
                
                pmh_PRINTF("parse over\n");
            }
            
            cursor = cursor->next;
        }
    }
}


#if pmh_DEBUG_OUTPUT
static void print_raw_blocks(char *text, pmh_realelement *elem[])
{
    pmh_PRINTF("--------print_raw_blocks---------\n");
    pmh_PRINTF("block:\n");
    pmh_realelement *cursor = elem[pmh_RAW_LIST];
    while (cursor != NULL)
    {
        print_raw_spans_inline(cursor->children);
        cursor = cursor->next;
    }
}
#endif




/* Free all elements created while parsing */
void pmh_free_elements(pmh_element **elems)
{
    pmh_realelement *cursor = (pmh_realelement*)elems[pmh_ALL];
    while (cursor != NULL) {
        pmh_realelement *tofree = cursor;
        cursor = cursor->all_elems_next;
        if (tofree->text != NULL)
            free(tofree->text);
        if (tofree->label != NULL)
            free(tofree->label);
        if (tofree->address != NULL)
            free(tofree->address);
        free(tofree);
    }
    elems[pmh_ALL] = NULL;
    
    free(elems);
}






#define IS_CONTINUATION_BYTE(x) ((x & 0xC0) == 0x80)
#define HAS_UTF8_BOM(x)         ( ((*x & 0xFF) == 0xEF)\
                                  && ((*(x+1) & 0xFF) == 0xBB)\
                                  && ((*(x+2) & 0xFF) == 0xBF) )
#define ADD_STRIP_POS(x) \
    /* reallocate more space for the array, if needed: */ \
    if (strip_positions_size <= strip_positions_pos) { \
        size_t new_size = strip_positions_size * 2; \
        unsigned long *new_arr = (unsigned long *) \
                                 calloc(new_size, \
                                        sizeof(unsigned long)); \
        memcpy(new_arr, strip_positions, \
               (sizeof(unsigned long) * strip_positions_size)); \
        strip_positions_size = new_size; \
        free(strip_positions); \
        strip_positions = new_arr; \
    } \
    strip_positions[strip_positions_pos] = x; \
    strip_positions_pos++;

/*
Copy `str` to `out`, while doing the following:
  - remove UTF-8 continuation bytes
  - remove possible UTF-8 BOM (byte order mark)
  - append two newlines to the end (like peg-markdown does)
  - keep track of which bytes we have stripped (in strip_positions)
*/
static int strcpy_preformat(char *str, char **out,
                            unsigned long **out_strip_positions,
                            size_t *out_strip_positions_len)
{
    size_t strip_positions_size = 1024;
    size_t strip_positions_pos = 0;
    unsigned long *strip_positions = (unsigned long *)
                                     calloc(strip_positions_size,
                                            sizeof(unsigned long));
    
    
    // +2 in the following is due to the "\n\n" suffix:
    char *new_str = (char *)malloc(sizeof(char) * strlen(str) + 1 + 2);
    char *c = str;
    int i = 0;
    
    if (HAS_UTF8_BOM(c)) {
        c += 3;
        ADD_STRIP_POS(0);
        ADD_STRIP_POS(1);
        ADD_STRIP_POS(2);
    }
    
    while (*c != '\0')
    {
        if (!IS_CONTINUATION_BYTE(*c)) {
            *(new_str+i) = *c, i++;
        } else {
            ADD_STRIP_POS((int)(c-str));
        }
        c++;
    }
    
    *(new_str+(i++)) = '\n';
    *(new_str+(i++)) = '\n';
    *(new_str+i) = '\0';
    
    *out = new_str;
    *out_strip_positions = strip_positions;
    *out_strip_positions_len = strip_positions_pos;
    return i;
}



void pmh_markdown_to_elements(char *text, int extensions,
                              pmh_element **out_result[])
{
    char *text_copy = NULL;
    unsigned long *strip_positions = NULL;
    size_t strip_positions_len = 0;
    int text_copy_len = strcpy_preformat(text, &text_copy, &strip_positions,
                                         &strip_positions_len);
    
    pmh_realelement *parsing_elem = (pmh_realelement *)
                                    malloc(sizeof(pmh_realelement));
    parsing_elem->type = pmh_RAW;
    parsing_elem->pos = 0;
    parsing_elem->end = text_copy_len;
    parsing_elem->next = NULL;
    
    parser_data *p_data = mk_parser_data(
        text,
        strip_positions,
        strip_positions_len,
        text_copy,
        parsing_elem,
        0,
        extensions,
        NULL,
        NULL
    );
    pmh_realelement **result = p_data->head_elems;
    
    if (*text_copy != '\0')
    {
        // Get reference definitions into p_data->references
        parse_references(p_data);
        
        // Reset parser state to beginning of input
        p_data->offset = 0;
        p_data->current_elem = p_data->elem_head;
        
        // Parse whole document
        parse_markdown(p_data);
        
        #if pmh_DEBUG_OUTPUT
        print_raw_blocks(text_copy, result);
        #endif
        
        process_raw_blocks(p_data);
    }
    
    free(strip_positions);
    free(p_data);
    free(parsing_elem);
    free(text_copy);
    
    *out_result = (pmh_element**)result;
}



/*
Mergesort linked list of elements (using comparison function `compare`),
return new head. (Adapted slightly from Simon Tatham's algorithm.)
*/
static pmh_element *ll_mergesort(pmh_element *list,
                                 int (*compare)(const pmh_element*,
                                                const pmh_element*))
{
    if (!list)
        return NULL;
    
    pmh_element *out_head = list;
    
    /* Merge widths of doubling size until done */
    int merge_width = 1;
    while (1)
    {
        pmh_element *l, *r; /* left & right segment pointers */
        pmh_element *tail = NULL; /* tail of sorted section */
        
        l = out_head;
        out_head = NULL;
        
        int merge_count = 0;
        
        while (l)
        {
            merge_count++;
            
            /* Position r, determine lsize & rsize */
            r = l;
            int lsize = 0;
            int i;
            for (i = 0; i < merge_width; i++) {
                lsize++;
                r = r->next;
                if (!r)
                    break;
            }
            int rsize = merge_width;
            
            /* Merge l & r */
            while (lsize > 0 || (rsize > 0 && r))
            {
                bool get_from_left = false;
                if (lsize == 0)             get_from_left = false;
                else if (rsize == 0 || !r)  get_from_left = true;
                else if (compare(l,r) <= 0) get_from_left = true;
                
                pmh_element *e;
                if (get_from_left) {
                    e = l; l = l->next; lsize--;
                } else {
                    e = r; r = r->next; rsize--;
                }
                
                /* add the next pmh_element to the merged list */
                if (tail)
                    tail->next = e;
                else
                    out_head = e;
                tail = e;
            }
            
            l = r;
        }
        tail->next = NULL;
        
        if (merge_count <= 1)
            return out_head;
        
        merge_width *= 2;
    }
}

static int elem_compare_by_pos(const pmh_element *a, const pmh_element *b)
{
    return a->pos - b->pos;
}

void pmh_sort_elements_by_pos(pmh_element *element_lists[])
{
    int i;
    for (i = 0; i < pmh_NUM_LANG_TYPES; i++)
        element_lists[i] = ll_mergesort(element_lists[i], &elem_compare_by_pos);
}








/* return true if extension is selected */
static bool extension(parser_data *p_data, int ext)
{
    return ((p_data->extensions & ext) != 0);
}

/* return reference pmh_realelement for a given label */
static pmh_realelement *get_reference(parser_data *p_data, char *label)
{
    if (!label)
        return NULL;
    
    pmh_realelement *cursor = p_data->references;
    while (cursor != NULL)
    {
        if (cursor->label && strcmp(label, cursor->label) == 0)
            return cursor;
        cursor = cursor->next;
    }
    return NULL;
}


/* cons an element/list onto a list, returning pointer to new head */
static pmh_realelement *cons(pmh_realelement *elem, pmh_realelement *list)
{
    assert(elem != NULL);
    
    pmh_realelement *cur = elem;
    while (cur->next != NULL) {
        cur = cur->next;
    }
    cur->next = list;
    
    return elem;
}


/* reverse a list, returning pointer to new list */
static pmh_realelement *reverse(pmh_realelement *list)
{
    pmh_realelement *new_head = NULL;
    pmh_realelement *next = NULL;
    while (list != NULL) {
        next = list->next;
        list->next = new_head;
        new_head = list;
        list = next;
    }
    return new_head;
}



/* construct pmh_realelement */
static pmh_realelement *mk_element(parser_data *p_data, pmh_element_type type,
                                   long pos, long end)
{
    pmh_realelement *result = (pmh_realelement *)malloc(sizeof(pmh_realelement));
    result->type = type;
    result->pos = pos;
    result->end = end;
    result->next = NULL;
    result->text_offset = 0;
    result->label = result->address = result->text = NULL;
    
    pmh_realelement *old_all_elements_head = p_data->head_elems[pmh_ALL];
    p_data->head_elems[pmh_ALL] = result;
    result->all_elems_next = old_all_elements_head;
    
    //pmh_PRINTF("  mk_element: %s [%ld - %ld]\n", pmh_element_name_from_type(type), pos, end);
    
    return result;
}

static pmh_realelement *copy_element(parser_data *p_data, pmh_realelement *elem)
{
    pmh_realelement *result = mk_element(p_data, elem->type, elem->pos, elem->end);
    result->label = (elem->label == NULL) ? NULL : strdup(elem->label);
    result->text = (elem->text == NULL) ? NULL : strdup(elem->text);
    result->address = (elem->address == NULL) ? NULL : strdup(elem->address);
    return result;
}

/* construct pmh_EXTRA_TEXT pmh_realelement */
static pmh_realelement *mk_etext(parser_data *p_data, char *string)
{
    pmh_realelement *result;
    assert(string != NULL);
    result = mk_element(p_data, pmh_EXTRA_TEXT, 0,0);
    result->text = strdup(string);
    return result;
}


/*
Given an element where the offsets {pos, end} represent
locations in the *parsed text* (defined by the linked list of pmh_RAW and
pmh_EXTRA_TEXT elements in p_data->current_elem), fix these offsets to represent
corresponding offsets in the parse buffer (p_data->charbuf). Also split
the given pmh_realelement into multiple parts if its offsets span multiple
p_data->current_elem elements. Return the (list of) elements with real offsets.
*/
static pmh_realelement *fix_offsets(parser_data *p_data, pmh_realelement *elem)
{
    if (elem->type == pmh_EXTRA_TEXT)
        return mk_etext(p_data, elem->text);
    
    pmh_realelement *new_head = copy_element(p_data, elem);
    
    pmh_realelement *tail = new_head;
    pmh_realelement *prev = NULL;
    
    bool found_start = false;
    bool found_end = false;
    bool tail_needs_pos = false;
    unsigned long previous_end = 0;
    unsigned long c = 0;
    
    pmh_realelement *cursor = p_data->elem_head;
    while (cursor != NULL)
    {
        int thislen = (cursor->type == pmh_EXTRA_TEXT)
                        ? strlen(cursor->text)
                        : cursor->end - cursor->pos;
        
        if (tail_needs_pos && cursor->type != pmh_EXTRA_TEXT) {
            tail->pos = cursor->pos;
            tail_needs_pos = false;
        }
        
        unsigned int this_pos = cursor->pos;
        
        if (!found_start && (c <= elem->pos && elem->pos <= c+thislen)) {
            tail->pos = (cursor->type == pmh_EXTRA_TEXT)
                        ? previous_end
                        : cursor->pos + (elem->pos - c);
            this_pos = tail->pos;
            found_start = true;
        }
        
        if (!found_end && (c <= elem->end && elem->end <= c+thislen)) {
            tail->end = (cursor->type == pmh_EXTRA_TEXT)
                        ? previous_end
                        : cursor->pos + (elem->end - c);
            found_end = true;
        }
        
        if (found_start && found_end)
            break;
        
        if (cursor->type != pmh_EXTRA_TEXT)
            previous_end = cursor->end;
        
        if (found_start) {
            pmh_realelement *new_elem = copy_element(p_data, tail);
            new_elem->pos = this_pos;
            new_elem->end = cursor->end;
            new_elem->next = tail;
            if (prev != NULL)
                prev->next = new_elem;
            if (new_head == tail)
                new_head = new_elem;
            prev = new_elem;
            tail_needs_pos = true;
        }
        
        c += thislen;
        cursor = cursor->next;
    }
    
    return new_head;
}



/* Add an element to p_data->head_elems. */
static void add(parser_data *p_data, pmh_realelement *elem)
{
    if (elem->type != pmh_RAW_LIST)
    {
        pmh_PRINTF("  add: %s [%ld - %ld]\n",
                   pmh_element_name_from_type(elem->type), elem->pos, elem->end);
        elem = fix_offsets(p_data, elem);
        pmh_PRINTF("     > %s [%ld - %ld]\n",
                   pmh_element_name_from_type(elem->type), elem->pos, elem->end);
    }
    else
    {
        pmh_PRINTF("  add: pmh_RAW_LIST ");
        pmh_realelement *cursor = elem->children;
        pmh_realelement *previous = NULL;
        while (cursor != NULL)
        {
            pmh_realelement *next = cursor->next;
            pmh_PRINTF("(%ld-%ld)>", cursor->pos, cursor->end);
            pmh_realelement *new_cursor = fix_offsets(p_data, cursor);
            if (previous != NULL)
                previous->next = new_cursor;
            else
                elem->children = new_cursor;
            pmh_PRINTF("(%ld-%ld)", new_cursor->pos, new_cursor->end);
            while (new_cursor->next != NULL) {
                new_cursor = new_cursor->next;
                pmh_PRINTF("(%ld-%ld)", new_cursor->pos, new_cursor->end);
            }
            pmh_PRINTF(" ");
            if (next != NULL)
                new_cursor->next = next;
            previous = new_cursor;
            cursor = next;
        }
        pmh_PRINTF("\n");
    }
    
    if (p_data->head_elems[elem->type] == NULL)
        p_data->head_elems[elem->type] = elem;
    else
    {
        pmh_realelement *last = elem;
        while (last->next != NULL)
            last = last->next;
        last->next = p_data->head_elems[elem->type];
        p_data->head_elems[elem->type] = elem;
    }
}


// Given a range in the list of spans we use for parsing (pos, end), return
// a copy of the corresponding section in the original input, with all of
// the UTF-8 bytes intact:
static char *copy_input_span(parser_data *p_data,
                             unsigned long pos, unsigned long end)
{
    if (end <= pos)
        return NULL;
    
    char *ret = NULL;
    
    // Adjust (pos,end) to match actual indexes in charbuf:
    pmh_realelement *dummy = mk_element(p_data, pmh_NO_TYPE, pos, end);
    pmh_realelement *fixed_dummies = fix_offsets(p_data, dummy);
    pmh_realelement *cursor = fixed_dummies;
    while (cursor != NULL)
    {
        if (cursor->end <= cursor->pos)
        {
            cursor = cursor->next;
            continue;
        }
        
        // Adjust cursor's span to take bytes stripped from the original
        // input into account (i.e. match the corresponding span in
        // p_data->original_input):
        unsigned long adjusted_pos = cursor->pos;
        unsigned long adjusted_end = cursor->end;
        size_t i;
        for (i = 0; i < p_data->strip_positions_len; i++)
        {
            unsigned long strip_position = p_data->strip_positions[i];
            if (strip_position <= adjusted_pos)
                adjusted_pos++;
            if (strip_position <= adjusted_end)
                adjusted_end++;
            else
                break;
        }
        
        // Copy span from original input:
        size_t adjusted_len = adjusted_end - adjusted_pos;
        char *str = (char *)malloc(sizeof(char)*adjusted_len + 1);
        *str = '\0';
        strncat(str, (p_data->original_input + adjusted_pos), adjusted_len);
        
        if (ret == NULL)
            ret = str;
        else
        {
            // append str to ret:
            char *new_ret = (char *)malloc(sizeof(char)
                                           *(strlen(str) + strlen(ret)) + 1);
            *new_ret = '\0';
            strcat(new_ret, ret);
            strcat(new_ret, str);
            free(ret);
            free(str);
            ret = new_ret;
        }
        
        cursor = cursor->next;
    }
    
    return ret;
}





# define YYSTYPE pmh_realelement *
#ifdef __DEBUG__
# define YY_DEBUG 1
#endif

#define YY_INPUT(buf, result, max_size)\
        yy_input_func(buf, &result, max_size, (parser_data *)G->data)

static void yy_input_func(char *buf, int *result, int max_size,
                          parser_data *p_data)
{
    if (p_data->current_elem == NULL)
    {
        (*result) = 0;
        return;
    }
    
    if (p_data->current_elem->type == pmh_EXTRA_TEXT)
    {
        int yyc;
        bool moreToRead = (p_data->current_elem->text
                           && *(p_data->current_elem->text
                                + p_data->current_elem->text_offset) != '\0');
        if (moreToRead)
        {
            yyc = *(p_data->current_elem->text + p_data->current_elem->text_offset++);
            pmh_PRINTF("\e[47;30m"); pmh_PUTCHAR(yyc); pmh_PRINTF("\e[0m");
            pmh_IF(yyc == '\n') pmh_PRINTF("\e[47m \e[0m");
        }
        else
        {
            yyc = EOF;
            p_data->current_elem = p_data->current_elem->next;
            pmh_PRINTF("\e[41m \e[0m");
            if (p_data->current_elem != NULL)
                p_data->offset = p_data->current_elem->pos;
        }
        (*result) = (EOF == yyc) ? 0 : (*(buf) = yyc, 1);
        return;
    }
    
    *(buf) = *(p_data->charbuf + p_data->offset);
    (*result) = (*buf != '\0');
    p_data->offset++;
    
    pmh_PRINTF("\e[43;30m"); pmh_PUTCHAR(*buf); pmh_PRINTF("\e[0m");
    pmh_IF(*buf == '\n') pmh_PRINTF("\e[42m \e[0m");
    
    if (p_data->offset >= p_data->current_elem->end)
    {
        p_data->current_elem = p_data->current_elem->next;
        pmh_PRINTF("\e[41m \e[0m");
        if (p_data->current_elem != NULL)
            p_data->offset = p_data->current_elem->pos;
    }
}


