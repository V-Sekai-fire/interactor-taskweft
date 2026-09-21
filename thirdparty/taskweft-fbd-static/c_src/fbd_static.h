/* C ABI for the Lean 4 FBD static analyser.
 *
 * The Lean library exports two entry points via its @[export] attribute.
 * Until that landing, `fbd_static_stub.c` supplies stub bodies that
 * return an "unimplemented" JSON string so the Elixir NIF can load and
 * be exercised end to end.
 *
 * Input SFC is a UTF-8 JSON string in the compact FBD profile
 * documented in RFD 2143; output is a UTF-8 JSON string with the
 * analysis result. Both sides own their strings; the caller frees the
 * returned buffer with `fbd_static_free`.
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 */
#ifndef TASKWEFT_FBD_STATIC_H
#define TASKWEFT_FBD_STATIC_H

#ifdef __cplusplus
extern "C" {
#endif

/* Returns malloc'd null-terminated UTF-8 JSON, e.g.:
 *   {"reachable": ["init", "find", ...],
 *    "concurrent_pairs": [["pickup_from_table", "unstack"]]}
 * or on error: {"error": "reason"}. Never NULL.
 */
char *fbd_static_analyse(const char *sfc_json);

/* Frees a buffer previously returned by fbd_static_analyse. */
void fbd_static_free(char *buf);

#ifdef __cplusplus
}
#endif

#endif
