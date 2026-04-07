/*
  Simple DirectMedia Layer
  Copyright (C) 1997-2026 Sam Lantinga <slouken@libsdl.org>

  This software is provided 'as-is', without any express or implied
  warranty.  In no event will the authors be held liable for any damages
  arising from the use of this software.

  Permission is granted to anyone to use this software for any purpose,
  including commercial applications, and to alter it and redistribute it
  freely, subject to the following restrictions:

  1. The origin of this software must not be misrepresented; you must not
     claim that you wrote the original software. If you use this software
     in a product, an acknowledgment in the product documentation would be
     appreciated but is not required.
  2. Altered source versions must be plainly marked as such, and must not be
     misrepresented as being the original software.
  3. This notice may not be removed or altered from any source distribution.
*/
#include "SDL_internal.h"

#ifdef SDL_VIDEO_DRIVER_COCOA

#include "SDL_cocoavideo.h"
#include "../../events/SDL_events_c.h"
#include "../../events/SDL_clipboardevents_c.h"

#ifndef NSPasteboardTypeString
#define NSPasteboardTypeString NSStringPboardType
#endif

static char **GetMimeTypes(int *pnformats)
{
    char **new_mime_types = NULL;
    *pnformats = 0;

    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    NSString *type = [pasteboard availableTypeFromArray:[NSArray arrayWithObject:NSPasteboardTypeString]];
    if (type) {
        const char *mime = "text/plain;charset=utf-8";
        const size_t len = SDL_strlen(mime) + 1;
        new_mime_types = SDL_AllocateTemporaryMemory((2 * sizeof(char *)) + len);
        if (new_mime_types) {
            char *strPtr = (char *)(new_mime_types + 2);
            SDL_memcpy(strPtr, mime, len);
            new_mime_types[0] = strPtr;
            new_mime_types[1] = NULL;
            *pnformats = 1;
        }
    }
    return new_mime_types;
}

void Cocoa_CheckClipboardUpdate(SDL_CocoaVideoData *data)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    NSInteger count = [pasteboard changeCount];
    if (count != data.clipboard_count) {
        if (count) {
            int nformats = 0;
            char **new_mime_types = GetMimeTypes(&nformats);
            if (new_mime_types) {
                SDL_SendClipboardUpdate(false, new_mime_types, nformats);
            }
        }
        data.clipboard_count = count;
    }
    [pool drain];
}

bool Cocoa_SetClipboardData(SDL_VideoDevice *_this)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    SDL_CocoaVideoData *data = (__bridge SDL_CocoaVideoData *)_this->internal;
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];

    if (_this->clipboard_callback && _this->num_clipboard_mime_types == 1) {
        if (SDL_strncmp(_this->clipboard_mime_types[0], "text/plain;charset=utf-8", 24) == 0) {
            size_t size = 0;
            const char *text = (const char *)_this->clipboard_callback(_this->clipboard_userdata, _this->clipboard_mime_types[0], &size);
            if (text) {
                NSString *nsstr = [[NSString alloc] initWithBytes:text length:size encoding:NSUTF8StringEncoding];
                if (!nsstr) {
                    [pool drain];
                    return SDL_SetError("Unable to convert clipboard text to NSString");
                }
                [pasteboard declareTypes:[NSArray arrayWithObject:NSPasteboardTypeString] owner:nil];
                [pasteboard setString:nsstr forType:NSPasteboardTypeString];
                [nsstr release];
                data.clipboard_count = [pasteboard changeCount];
                [pool drain];
                return true;
            }
        }
    }

    [pool drain];
    return SDL_SetError("Leopard clipboard backend currently supports text/plain;charset=utf-8 only");
}

void *Cocoa_GetClipboardData(SDL_VideoDevice *_this, const char *mime_type, size_t *size)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    void *data = NULL;
    *size = 0;
    if (SDL_strncmp(mime_type, "text/plain;charset=utf-8", 24) == 0 || SDL_strcmp(mime_type, "text/plain") == 0) {
        NSString *str = [[NSPasteboard generalPasteboard] stringForType:NSPasteboardTypeString];
        if (str) {
            const char *utf8 = [str UTF8String];
            if (utf8) {
                *size = SDL_strlen(utf8);
                data = SDL_malloc(*size + sizeof(Uint32));
                if (data) {
                    SDL_memcpy(data, utf8, *size);
                    SDL_memset((Uint8 *)data + *size, 0, sizeof(Uint32));
                }
            }
        }
    }
    [pool drain];
    return data;
}

bool Cocoa_HasClipboardData(SDL_VideoDevice *_this, const char *mime_type)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    bool result = false;
    if (SDL_strncmp(mime_type, "text/plain;charset=utf-8", 24) == 0 || SDL_strcmp(mime_type, "text/plain") == 0) {
        result = ([[NSPasteboard generalPasteboard] stringForType:NSPasteboardTypeString] != nil);
    }
    [pool drain];
    return result;
}

#endif // SDL_VIDEO_DRIVER_COCOA
