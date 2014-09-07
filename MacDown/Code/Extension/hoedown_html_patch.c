//
//  hoedown_html_patch.c
//  MacDown
//
//  Created by Tzu-ping Chung  on 14/06/2014.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#include <string.h>
#include <hoedown/escape.h>
#include <hoedown/markdown.h>
#include <hoedown/html.h>
#include "hoedown_html_patch.h"

#define USE_XHTML(opt) (opt->flags & HOEDOWN_HTML_USE_XHTML)
#define USE_TASK_LIST(opt) (opt->flags & HOEDOWN_HTML_USE_TASK_LIST)

// rndr_blockcode from HEAD. The "language-" prefix in class in needed to make
// the HTML compatible with Prism.
void hoedown_patch_render_blockcode(
    hoedown_buffer *ob, const hoedown_buffer *text, const hoedown_buffer *lang,
    void *opaque)
{
	if (ob->size) hoedown_buffer_putc(ob, '\n');

	if (lang) {
        rndr_state_ex *state = opaque;
        hoedown_buffer *mapped = NULL;
        if (state->language_addition)
            mapped = state->language_addition(lang, state->owner);
		HOEDOWN_BUFPUTSL(ob, "<pre><code class=\"language-");
        if (mapped)
        {
            hoedown_escape_html(ob, mapped->data, mapped->size, 0);
            hoedown_buffer_free(mapped);
        }
        else
        {
            hoedown_escape_html(ob, lang->data, lang->size, 0);
        }
		HOEDOWN_BUFPUTSL(ob, "\">");
	} else {
		HOEDOWN_BUFPUTSL(ob, "<pre><code>");
	}

	if (text)
		hoedown_escape_html(ob, text->data, text->size, 0);

	HOEDOWN_BUFPUTSL(ob, "</code></pre>\n");
}

// Supports task list syntax if HOEDOWN_HTML_USE_TASK_LIST is on.
// Implementation based on hoextdown.
void hoedown_patch_render_listitem(
    hoedown_buffer *ob, const hoedown_buffer *text, int flags, void *opaque)
{
	if (text)
    {
        rndr_state_ex *state = opaque;
        size_t offset = 0;
        if (flags & HOEDOWN_LI_BLOCK)
            offset = 3;

        // Do task list checkbox ([x] or [ ]).
        if (USE_TASK_LIST(state) && text->size >= 3)
        {
            if (strncmp((char *)(text->data + offset), "[ ]", 3) == 0)
            {
                HOEDOWN_BUFPUTSL(ob, "<li class=\"task-list-item\">");
                hoedown_buffer_put(ob, text->data, offset);
                if (USE_XHTML(state))
                    HOEDOWN_BUFPUTSL(ob, "<input type=\"checkbox\" />");
                else
                    HOEDOWN_BUFPUTSL(ob, "<input type=\"checkbox\">");
				offset += 3;
            }
            else if (strncmp((char *)(text->data + offset), "[x]", 3) == 0)
            {
                HOEDOWN_BUFPUTSL(ob, "<li class=\"task-list-item\">");
                hoedown_buffer_put(ob, text->data, offset);
                if (USE_XHTML(state))
                    HOEDOWN_BUFPUTSL(ob, "<input type=\"checkbox\" checked />");
                else
                    HOEDOWN_BUFPUTSL(ob, "<input type=\"checkbox\" checked>");
				offset += 3;
            }
            else
            {
                HOEDOWN_BUFPUTSL(ob, "<li>");
                offset = 0;
            }
        }
        else
        {
            HOEDOWN_BUFPUTSL(ob, "<li>");
            offset = 0;
        }
		size_t size = text->size;
		while (size && text->data[size - offset - 1] == '\n')
			size--;

		hoedown_buffer_put(ob, text->data + offset, size - offset);
	}
	HOEDOWN_BUFPUTSL(ob, "</li>\n");
}

// Add .table class to table for Bootstrap.
void hoedown_patch_render_table(
    hoedown_buffer *ob, const hoedown_buffer *header,
    const hoedown_buffer *body, void *opaque)
{
    if (ob->size) hoedown_buffer_putc(ob, '\n');
    HOEDOWN_BUFPUTSL(ob, "<table class=\"table\"><thead>\n");
    if (header)
        hoedown_buffer_put(ob, header->data, header->size);
    HOEDOWN_BUFPUTSL(ob, "</thead><tbody>\n");
    if (body)
        hoedown_buffer_put(ob, body->data, body->size);
    HOEDOWN_BUFPUTSL(ob, "</tbody></table>\n");
}
