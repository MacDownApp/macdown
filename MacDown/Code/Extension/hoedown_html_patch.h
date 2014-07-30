//
//  hoedown_html_patch.h
//  MacDown
//
//  Created by Tzu-ping Chung  on 14/06/2014.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#ifndef MacDown_hoedown_html_patch_h
#define MacDown_hoedown_html_patch_h

static unsigned int HOEDOWN_HTML_USE_TASK_LIST = (1 << 11);
static unsigned int HOEDOWN_HTML_DISABLE_UNDERSCORE = (1 << 12);

typedef struct hoedown_buffer hoedown_buffer;

typedef struct rndr_state {
	struct {
		int header_count;
		int current_level;
		int level_offset;
		int nesting_level;
	} toc_data;

	unsigned int flags;

	/* extra callbacks */
	void (*link_attributes)(hoedown_buffer *ob, const hoedown_buffer *url, void *self);
} rndr_state;

typedef struct rndr_state_ex {
	struct {
		int header_count;
		int current_level;
		int level_offset;
		int nesting_level;
	} toc_data;

	unsigned int flags;

	/* extra callbacks */
	void (*link_attributes)(
        hoedown_buffer *ob, const hoedown_buffer *url, void *self);

    /* More extra callbacks */
    hoedown_buffer *(*language_addition)(const hoedown_buffer *language,
                                         void *owner);
    void *owner;

} rndr_state_ex;

void hoedown_patch_render_blockcode(
    hoedown_buffer *ob, const hoedown_buffer *text, const hoedown_buffer *lang,
    void *opaque);

void hoedown_patch_render_listitem(
    hoedown_buffer *ob, const hoedown_buffer *text, int flags, void *opaque);

int hoedown_patch_render_underline(
    hoedown_buffer *ob, const hoedown_buffer *text, void *opaque);

#endif
