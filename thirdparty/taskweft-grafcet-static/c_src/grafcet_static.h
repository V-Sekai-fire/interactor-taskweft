/* C ABI for the Lean 4 GRAFCET static analyser.
 *
 * The Lean library exports two entry points via its @[export] attribute.
 * Until that landing, `grafcet_static_stub.c` supplies stub bodies that
 * return an "unimplemented" JSON string so the Elixir NIF can load and
 * be exercised end to end.
 *
 * Input SFC is a UTF-8 JSON string in the compact GRAFCET profile
 * documented in RFD 2143; output is a UTF-8 JSON string with the
 * analysis result. Both sides own their strings; the caller frees the
 * returned buffer with `grafcet_static_free`.
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 */
#ifndef TASKWEFT_GRAFCET_STATIC_H
#define TASKWEFT_GRAFCET_STATIC_H

#ifdef __cplusplus
extern "C" {
#endif

/* Returns malloc'd null-terminated UTF-8 JSON, e.g.:
 *   {"reachable": ["init", "find", ...],
 *    "concurrent_pairs": [["pickup_from_table", "unstack"]]}
 * or on error: {"error": "reason"}. Never NULL.
 */
char *grafcet_static_analyse(const char *sfc_json);

/* Frees a buffer previously returned by grafcet_static_analyse. */
void grafcet_static_free(char *buf);

#ifdef __cplusplus
}
#endif

#endif
