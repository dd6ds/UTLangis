/* C interface of the Rust Signal backend (core/src/lib.rs).
 *
 * The backend runs on its own thread. Commands go in as JSON strings, events
 * come back as JSON strings through the callback, which is called on the
 * backend thread - the receiver must hand them over to its own thread.
 * The command and event formats are documented in core/src/lib.rs. */

#ifndef UTLANGIS_CORE_H
#define UTLANGIS_CORE_H

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef void (*utlangis_event_cb)(void *context, const char *json);

/* Starts the backend with its database and attachments below data_dir.
 * Returns false if it is already running or data_dir is not usable. */
bool utlangis_start(const char *data_dir, utlangis_event_cb callback, void *context);

/* Queues one command. Ignored while the backend is not running. */
void utlangis_command(const char *json);

/* Stops the backend and waits for its thread to finish. */
void utlangis_stop(void);

#ifdef __cplusplus
}
#endif

#endif
