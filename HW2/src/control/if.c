#include "if.h"

#include <WJCL/string/wjcl_string.h>

#include "lib/code_gen.h"
#include "compiler_util.h"

inline bool code_if(Object* src) {
    compilerLog("> (if)\n");
    char condName[MAX_NAME_LENGTH];
    Object regCond = object_loadRegAndPromote(src, OBJECT_TYPE_BOOL, condName, MAX_NAME_LENGTH);
    if (regCond.type == OBJECT_TYPE_UNDEFINED) goto FAILED;
    ScopeData* scope = scope_pushType(SCOPE_IF_STMT);
    scope->u.ifInfo = (IfInfo){.elseifCount = 0, .containsElse = false};
    buffPrintln(&ctx->code, "br i1 %s, label %%if%d.true, label %%if%d.false", condName, scope->id, scope->id);
    buffPrintlnS(&ctx->code, "if%d.true:", scope->id);
    if (src->type == OBJECT_TYPE_SYMBOL || (regCond.type == OBJECT_TYPE_REGISTER && src->type != OBJECT_TYPE_REGISTER)) object_free(&regCond);
    object_free(src);
    return false;
FAILED:
    object_free(src);
    return true;
}

inline bool code_elseIfLabel() {
    ScopeData* scope = scope_peek();
    int n = scope->u.ifInfo.elseifCount;
    buffPrintln(&ctx->code, "br label %%if%d.endif", scope->id);
    if (n == 0)
        buffPrintlnS(&ctx->code, "if%d.false:", scope->id);
    else
        buffPrintlnS(&ctx->code, "if%d.elseif%d.false:", scope->id, n - 1);
    return false;
}

inline bool code_elseIf(Object* src) {
    ScopeData* old = scope_peek();
    int scopeId = old->id;
    int n = old->u.ifInfo.elseifCount;
    scope_dump();
    compilerLog("> (else if)\n");
    ScopeData* scope = scope_pushId(SCOPE_IF_STMT, scopeId);
    scope->u.ifInfo = (IfInfo){.elseifCount = n + 1, .containsElse = false};

    char condName[MAX_NAME_LENGTH];
    Object regCond = object_loadRegAndPromote(src, OBJECT_TYPE_BOOL, condName, MAX_NAME_LENGTH);
    if (regCond.type == OBJECT_TYPE_UNDEFINED) goto FAILED;
    buffPrintln(&ctx->code, "br i1 %s, label %%if%d.elseif%d.true, label %%if%d.elseif%d.false",
                condName, scopeId, n, scopeId, n);
    buffPrintlnS(&ctx->code, "if%d.elseif%d.true:", scopeId, n);
    if (src->type == OBJECT_TYPE_SYMBOL || (regCond.type == OBJECT_TYPE_REGISTER && src->type != OBJECT_TYPE_REGISTER)) object_free(&regCond);
    object_free(src);
    return false;
FAILED:
    object_free(src);
    return true;
}

inline bool code_else() {
    ScopeData* old = scope_peek();
    int scopeId = old->id;
    int n = old->u.ifInfo.elseifCount;
    code_elseIfLabel();
    scope_dump();
    compilerLog("> (else)\n");
    ScopeData* scope = scope_pushId(SCOPE_IF_STMT, scopeId);
    scope->u.ifInfo = (IfInfo){.elseifCount = n, .containsElse = true};
    return false;
}

inline bool code_ifEnd() {
    ScopeData* scope = scope_peek();
    int id = scope->id;
    int n = scope->u.ifInfo.elseifCount;
    bool hasElse = scope->u.ifInfo.containsElse;
    if (hasElse) {
        buffPrintln(&ctx->code, "br label %%if%d.endif", id);
        buffPrintlnS(&ctx->code, "if%d.endif:", id);
    } else if (n == 0) {
        buffPrintln(&ctx->code, "br label %%if%d.false", id);
        buffPrintlnS(&ctx->code, "if%d.false:", id);
    } else {
        buffPrintln(&ctx->code, "br label %%if%d.endif", id);
        buffPrintlnS(&ctx->code, "if%d.elseif%d.false:", id, n - 1);
        buffPrintln(&ctx->code, "br label %%if%d.endif", id);
        buffPrintlnS(&ctx->code, "if%d.endif:", id);
    }
    scope_dump();
    compilerLog("< (if end)\n");
    return false;
}
