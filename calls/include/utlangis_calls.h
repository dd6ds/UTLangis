/* One-to-one Signal calls (libutlangis_calls.so, see calls/src/lib.rs).
 * The app loads the library at run time; commands and events are JSON. */
#ifndef UTLANGIS_CALLS_H
#define UTLANGIS_CALLS_H

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef void (*ut_calls_event_callback)(void *context, const char *json);
/* A picture of the other side: RGBA, width x height. */
typedef void (*ut_calls_frame_callback)(void *context, uint32_t width, uint32_t height,
                                        const uint8_t *rgba);

bool ut_calls_start(ut_calls_event_callback callback, void *context);
void ut_calls_command(const char *json);
void ut_calls_set_video_callback(ut_calls_frame_callback callback, void *context);
void ut_calls_push_frame(uint32_t width, uint32_t height, const uint8_t *rgba);
void ut_calls_stop(void);

#ifdef __cplusplus
}
#endif

#endif
