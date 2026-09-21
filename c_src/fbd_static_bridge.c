/* C bridge to the Lean-produced `analyse_sfc` function.
 *
 * Marshals plain C strings to and from Lean strings, initialises the
 * Lean runtime once, and exposes the plain C ABI declared in
 * fbd_static.h. Modelled on the "calling Lean 4 from C" pattern
 * in the Lean 4 manual, appendix "Foreign Function Interface".
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 */
#include "fbd_static.h"

#include <lean/lean.h>

#include <pthread.h>
#include <stdlib.h>
#include <string.h>

/* Lean's generated setup. `initialize_*` symbols are emitted by lake in
 * each module's `.c` output; they are not in `lean.h`, so we forward-
 * declare them here, matching the mangled names lake uses (dashes in the
 * package name become `_x2d`). */
extern void lean_initialize_runtime_module(void);
extern lean_object *initialize_taskweft_x2dfbd_x2dstatic_TaskweftFbdStatic(uint8_t builtin);
extern lean_object *initialize_taskweft_x2dfbd_x2dstatic_TaskweftFbdStatic_Analyse(uint8_t builtin);
extern lean_object *analyse_sfc(lean_object *input);

static pthread_once_t g_init_once = PTHREAD_ONCE_INIT;
static int g_init_ok = 0;

static void init_lean(void) {
    lean_initialize_runtime_module();
    lean_object *io_res =
        initialize_taskweft_x2dfbd_x2dstatic_TaskweftFbdStatic(1);
    if (lean_io_result_is_error(io_res)) {
        lean_dec_ref(io_res);
        return;
    }
    lean_dec_ref(io_res);
    io_res =
        initialize_taskweft_x2dfbd_x2dstatic_TaskweftFbdStatic_Analyse(1);
    if (lean_io_result_is_error(io_res)) {
        lean_dec_ref(io_res);
        return;
    }
    lean_dec_ref(io_res);
    lean_io_mark_end_initialization();
    g_init_ok = 1;
}

char *fbd_static_analyse(const char *sfc_json) {
    pthread_once(&g_init_once, init_lean);
    if (!g_init_ok) {
        const char msg[] = "{\"error\":\"init\"}";
        char *out = (char *)malloc(sizeof msg);
        if (out) memcpy(out, msg, sizeof msg);
        return out;
    }

    lean_object *input = lean_mk_string(sfc_json ? sfc_json : "");
    lean_object *result = analyse_sfc(input); /* consumes input */

    const char *body = lean_string_cstr(result);
    size_t n = strlen(body);
    char *out = (char *)malloc(n + 1);
    if (out) {
        memcpy(out, body, n);
        out[n] = '\0';
    }
    lean_dec_ref(result);
    return out;
}

void fbd_static_free(char *buf) {
    free(buf);
}
