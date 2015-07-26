//
//  hoedown_html_patch.c
//  MacDown
//
//  Created by Tzu-ping Chung  on 14/06/2014.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#include <string.h>
#include <hoedown/escape.h>
#include <hoedown/document.h>
#include <hoedown/html.h>
#include "hoedown_html_patch.h"

#define USE_XHTML(opt) (opt->flags & HOEDOWN_HTML_USE_XHTML)
#define USE_TASK_LIST(opt) (opt->flags & HOEDOWN_HTML_USE_TASK_LIST)

// rndr_blockcode from HEAD. The "language-" prefix in class in needed to make
// the HTML compatible with Prism.
void hoedown_patch_render_blockcode(
    hoedown_buffer *ob, const hoedown_buffer *text, const hoedown_buffer *lang,
    const hoedown_renderer_data *data)
{
	if (ob->size) hoedown_buffer_putc(ob, '\n');

    hoedown_html_renderer_state *state = data->opaque;
    hoedown_html_renderer_state_extra *extra = state->opaque;

    hoedown_buffer *mapped = NULL;
    if (lang && extra->language_addition)
        mapped = extra->language_addition(lang, extra->owner);

    HOEDOWN_BUFPUTSL(ob, "<pre");
    if (state->flags & HOEDOWN_HTML_BLOCKCODE_LINE_NUMBERS)
        HOEDOWN_BUFPUTSL(ob, " class=\"line-numbers\"");
    HOEDOWN_BUFPUTSL(ob, "><code class=\"language-");
    if (mapped)
    {
        hoedown_escape_html(ob, mapped->data, mapped->size, 0);
        hoedown_buffer_free(mapped);
    }
    else
    {
        if (lang)
            hoedown_escape_html(ob, lang->data, lang->size, 0);
        else
            HOEDOWN_BUFPUTSL(ob, "none");
    }
    HOEDOWN_BUFPUTSL(ob, "\">");

	if (text)
    {
        // Remove last newline to prevent prism from adding a blank line at the
        // end of code blocks.
        size_t size = text->size;
        if (size > 0 && text->data[size - 1] == '\n')
            size--;
        hoedown_escape_html(ob, text->data, size, 0);
    }

	HOEDOWN_BUFPUTSL(ob, "</code></pre>\n");
}

// Supports task list syntax if HOEDOWN_HTML_USE_TASK_LIST is on.
// Implementation based on hoextdown.
void hoedown_patch_render_listitem(
    hoedown_buffer *ob, const hoedown_buffer *text, hoedown_list_flags flags,
    const hoedown_renderer_data *data)
{
	if (text)
    {
        hoedown_html_renderer_state *state = data->opaque;
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
