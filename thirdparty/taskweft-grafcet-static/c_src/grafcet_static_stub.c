/* Stub implementation of the Lean-produced analyser. Returns a fixed
 * JSON string signalling that the real Lean library has not yet been
 * linked in. Real bodies come from Lean's `@[export]` output; see
 * `Lean/Exports.lean` when that lands.
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 */
#include "grafcet_static.h"

#include <stdlib.h>
#include <string.h>

char *grafcet_static_analyse(const char *sfc_json) {
    (void)sfc_json;
    static const char msg[] =
        "{\"error\":\"stub\","
        "\"reason\":\"Lean-produced shared lib not yet linked in\","
        "\"see\":\"rfd 2144\"}";
    char *out = (char *)malloc(sizeof msg);
    if (!out) return NULL;
    memcpy(out, msg, sizeof msg);
    return out;
}

void grafcet_static_free(char *buf) {
    free(buf);
}
