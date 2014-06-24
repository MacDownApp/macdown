//
//  hoedown_html_patch.c
//  MacDown
//
//  Created by Tzu-ping Chung  on 14/06/2014.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#include <hoedown/escape.h>
#include <hoedown/markdown.h>
#include "hoedown_html_patch.h"

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