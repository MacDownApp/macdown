//
//  hoedown_html_patch.c
//  MacDown
//
//  Created by Tzu-ping Chung  on 14/06/2014.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#include <hoedown/escape.h>
#include <hoedown/markdown.h>

// rndr_blockcode from HEAD. The "language-" prefix in class in needed to make
// the HTML compatible with Prism.
void hoedown_patch_render_blockcode(
    hoedown_buffer *ob, const hoedown_buffer *text, const hoedown_buffer *lang,
    void *opaque)
{
	if (ob->size) hoedown_buffer_putc(ob, '\n');

	if (lang) {
		HOEDOWN_BUFPUTSL(ob, "<pre><code class=\"language-");
		hoedown_escape_html(ob, lang->data, lang->size, 0);
		HOEDOWN_BUFPUTSL(ob, "\">");
	} else {
		HOEDOWN_BUFPUTSL(ob, "<pre><code>");
	}

	if (text)
		hoedown_escape_html(ob, text->data, text->size, 0);

	HOEDOWN_BUFPUTSL(ob, "</code></pre>\n");
}