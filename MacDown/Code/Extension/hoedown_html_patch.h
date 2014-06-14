//
//  hoedown_html_patch.h
//  MacDown
//
//  Created by Tzu-ping Chung  on 14/06/2014.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#ifndef MacDown_hoedown_html_patch_h
#define MacDown_hoedown_html_patch_h

typedef struct hoedown_buffer hoedown_buffer;

void hoedown_patch_render_blockcode(
    hoedown_buffer *ob, const hoedown_buffer *text, const hoedown_buffer *lang,
    void *opaque);

#endif
