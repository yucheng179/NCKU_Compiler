/* Definition section */
%code requires {
    # define YYLTYPE_IS_DECLARED 1
    # define YYLTYPE_IS_TRIVIAL 1
}

%{
    #include <string.h>
    #include "compiler_util.h"
    #include "main.h"
    #include "expression.h"
    #include "value_data.h"
    #include "scope.h"
    #include "control/for.h"
    #include "control/if.h"
    #include "control/while.h"
    #include "control/function.h"

    static ValueData* namingValues = NULL;
    static Object* pushingArray = NULL;
    static Object currentCallFunc = {.type = OBJECT_TYPE_UNDEFINED};
    static YYLTYPE currentCallLoc = {0};
    static ObjectType currentParamType = OBJECT_TYPE_UNDEFINED;

    static Object cloneObjectForParser(const Object* obj) {
        Object clone = *obj;
        if (obj->type == OBJECT_TYPE_STR && obj->value.str)
            clone.value.str = strdup(obj->value.str);
        else if (ObjectType_isNumber(obj->type) && obj->value.number)
            clone.value.number = cloneStruct(ScientificNotation, obj->value.number);
        else if (obj->type == OBJECT_TYPE_REGISTER && obj->value.symbol)
            clone.value.symbol = symbol_clone(obj->value.symbol);
        return clone;
    }

    static void parserSetLast(const Object* obj) {
        object_free(&ctx->last_result);
        ctx->last_result = cloneObjectForParser(obj);
    }

    static ValueData singleValueData(Object* obj, const YYLTYPE* loc) {
        ValueData vd;
        object_ValueDataListCreate(OBJECT_TYPE_AUTO, NULL, &vd);
        object_ValueDataListAdd(&vd, obj, loc);
        return vd;
    }
%}

%define parse.error custom
%locations

%union {
    ObjectType var_type;
    bool b_var;
    ScientificNotation n_var;
    char *s_var;
    Object obj_val;
    ValueData val_data;
    FuncCallInfo* func_call;
    bool exp_left;
    ExpOp exp_op;
}

%token COMMENT
%token HERE_ARE HERE_IS_A SAID NAME_IT PRINT TO_CALL RETURN
%token ITS PAST TOPIC SET IS_THUS
%token IF ELSE_IF ELSE END FOR WHILE_TRUE BREAK
%token CALL TO_PERFORM_FUNC REQUIRE_ARGS FUNC_BEGIN FUNC_END_FOR FUNC_END
%token PUSH THOSE LENGTH TAKE

%token <n_var> NUMBER_LIT
%token <b_var> BOOL_LIT
%token <var_type> VAR_TYPE VAR_TYPE_FUNC
%token <s_var> STR_LIT IDENT
%token <exp_op> EXP_MATH_OP EXP_MATH_MOD_OP EXP_LOGIC_OP EXP_BINARY_LOGIC_OP
%token <exp_left> EXP_PREPOSITION

%left INDEX LENGTH
%nonassoc LOWER_THAN_EXPR
%nonassoc RETURN

%type <val_data> CreateValueDataListStmt ValueItems FunctionCallStmt TakeCallStmt
%type <obj_val> ValueStmt LitOrVarStmt ValueLiteralStmt VariableStmt ExpressionChainStmt ExpressionStmt ExpressionNextStmt ValueLiteralOrLastStmt FunctionHeader
%type <func_call> FunctionCallBegin

%start Program
%%

Program
    : GlobalScopeStmt
;

GlobalScopeStmt
    : BodyListStmt
;

BodyListStmt
    : BodyListStmt BodyStmt
    |
;

BodyStmt
    : COMMENT STR_LIT             { free($2); }
    | OperationStmt
    | ConditionStmt
    | FunctionStmt
;

FunctionStmt
    : FunctionHeader TO_PERFORM_FUNC FunctionArgsStmt FUNC_BEGIN { func_defineBody(); } BodyListStmt FUNC_END_FOR IDENT FUNC_END END
        { func_defineBodyEnd(&$1, $8, &@9); object_free(&$1); free($8); }
    | FunctionHeader TO_PERFORM_FUNC FunctionArgsStmt FUNC_BEGIN { func_defineBody(); } BodyListStmt FUNC_END_FOR IDENT FUNC_END
        { func_defineBodyEnd(&$1, $8, &@9); object_free(&$1); free($8); }
;

FunctionHeader
    : HERE_ARE NUMBER_LIT VAR_TYPE_FUNC NAME_IT IDENT { $$ = func_define(&$2, $5); free($5); }
;

FunctionArgsStmt
    : REQUIRE_ARGS NUMBER_LIT VAR_TYPE { currentParamType = $3; } FunctionArgListStmt
    |
;

FunctionArgListStmt
    : FunctionArgListStmt SAID IDENT { func_defineAddParam(currentParamType, $3); free($3); }
    | SAID IDENT                     { func_defineAddParam(currentParamType, $2); free($2); }
;

ConditionStmt
    : IF ExpressionChainStmt TOPIC { code_if(&$2); } BodyListStmt ElseIfList ElseStmt END { code_ifEnd(); }
    | WHILE_TRUE { code_whileLoopStart(); } BodyListStmt END { code_whileLoopEnd(NULL); }
    | WHILE_TRUE { code_whileLoopStart(); } IF ExpressionChainStmt TOPIC BREAK END { code_if(&$4); code_break(&@6); code_ifEnd(); } BodyListStmt END { code_whileLoopEnd(NULL); }
    | FOR ValueStmt OptionalEnd { code_forLoop(&$2); } BodyListStmt END { code_forLoopEnd(NULL); }
;

OptionalEnd
    : END
    |
;

ElseIfList
    : ElseIfList ELSE_IF { code_elseIfLabel(); } ExpressionChainStmt TOPIC { code_elseIf(&$4); } BodyListStmt
    |
;

ElseStmt
    : ELSE { code_else(); } BodyListStmt
    |
;

OperationStmt
    : ValueItems NAME_IT { object_ValueDataListAddDefaults(&$1, &@1); namingValues = &$1; } VariableDefineStmt
        { namingValues = NULL; object_ValueDataListFree(&$1); }
    | ValueItems PRINT { code_stdoutPrint(&$1, true); object_ValueDataListFree(&$1); }
    | ValueItems RETURN { code_returnValue(&$1, &@2); }
    | ValueStmt PRINT  { ValueData vd = singleValueData(&$1, &@1); code_stdoutPrint(&vd, true); object_ValueDataListFree(&vd); }
    | ExpressionChainStmt NAME_IT IDENT
        { ValueData vd = singleValueData(&$1, &@1); code_createVariable(&vd, $3); object_ValueDataListFree(&vd); }
    | ValueStmt NAME_IT IDENT
        { ValueData vd = singleValueData(&$1, &@1); code_createVariable(&vd, $3); object_ValueDataListFree(&vd); }
    | ExpressionChainStmt PRINT
        { ValueData vd = singleValueData(&$1, &@1); code_stdoutPrint(&vd, true); object_ValueDataListFree(&vd); }
    | PAST VariableStmt TOPIC SET ValueLiteralOrLastStmt IS_THUS { code_assign(&$2, &$5); }
    | ExpressionChainStmt PAST VariableStmt TOPIC SET ITS IS_THUS { code_assign(&$3, &$1); }
    | FunctionCallStmt NAME_IT IDENT { code_createVariable(&$1, $3); object_ValueDataListFree(&$1); }
    | FunctionCallStmt PRINT         { code_stdoutPrint(&$1, true); object_ValueDataListFree(&$1); }
    | FunctionCallStmt RETURN        { code_returnValue(&$1, &@2); }
    | FunctionCallStmt               { object_ValueDataListFree(&$1); }
    | TakeCallStmt NAME_IT IDENT     { code_createVariable(&$1, $3); object_ValueDataListFree(&$1); }
    | TakeCallStmt PRINT             { code_stdoutPrint(&$1, true); object_ValueDataListFree(&$1); }
    | TakeCallStmt RETURN            { code_returnValue(&$1, &@2); }
    | RETURN ValueStmt               { code_return(&$2, &@1); }
    | ValueStmt RETURN               { code_return(&$1, &@2); }
    | RETURN                         { ValueData vd; object_ValueDataListCreate(OBJECT_TYPE_UNDEFINED, NULL, &vd); code_returnValue(&vd, &@1); }
    | BREAK                          { code_break(&@1); }
    | PUSH VariableStmt { pushingArray = &$2; } PushItemList { object_free(&$2); pushingArray = NULL; }
;

CreateValueDataListStmt
    : HERE_ARE NUMBER_LIT VAR_TYPE { object_ValueDataListCreate($3, &$2, &$$); }
    | HERE_IS_A VAR_TYPE           { object_ValueDataListCreate($2, NULL, &$$); }
;

ValueItems
    : CreateValueDataListStmt                 { $$ = $1; }
    | ValueItems SAID ExpressionChainStmt TAKE NUMBER_LIT TO_CALL VariableStmt { $$ = $1; object_ValueDataListAdd(&$$, &$3, &@3); object_free(&$3); func_takeAndCall(&$5, &$7, &$$, &@7); }
    | ValueItems ExpressionChainStmt TAKE NUMBER_LIT TO_CALL VariableStmt      { $$ = $1; object_ValueDataListAdd(&$$, &$2, &@2); object_free(&$2); func_takeAndCall(&$4, &$6, &$$, &@6); }
    | ValueItems SAID ExpressionChainStmt { $$ = $1; object_ValueDataListAdd(&$$, &$3, &@3); object_free(&$3); }
    | ValueItems ExpressionChainStmt      { $$ = $1; object_ValueDataListAdd(&$$, &$2, &@2); object_free(&$2); }
    | ValueItems SAID ValueStmt               { $$ = $1; object_ValueDataListAdd(&$$, &$3, &@3); object_free(&$3); }
    | ValueItems ValueStmt                    { $$ = $1; object_ValueDataListAdd(&$$, &$2, &@2); object_free(&$2); }
    | ValueItems SAID TakeCallStmt        { $$ = $1; Object* obj = object_ValueDataListPop(&$3); if (obj) { object_ValueDataListAdd(&$$, obj, &@3); object_free(obj); free(obj); } object_ValueDataListFree(&$3); }
    | ValueItems TakeCallStmt             { $$ = $1; Object* obj = object_ValueDataListPop(&$2); if (obj) { object_ValueDataListAdd(&$$, obj, &@2); object_free(obj); free(obj); } object_ValueDataListFree(&$2); }
;

VariableDefineStmt
    : IDENT                         { code_createVariable(namingValues, $1); }
    | VariableDefineStmt SAID IDENT { code_createVariable(namingValues, $3); }
    | VariableDefineStmt IDENT      { code_createVariable(namingValues, $2); }
;

PushItemList
    : PushItemList EXP_PREPOSITION ValueStmt { code_arrayPush(pushingArray, &$3, &@2); }
    | EXP_PREPOSITION ValueStmt              { code_arrayPush(pushingArray, &$2, &@1); }
;

TakeCallStmt
    : ExpressionChainStmt TAKE NUMBER_LIT TO_CALL VariableStmt {
        ValueData vd = singleValueData(&$1, &@1);
        func_takeAndCall(&$3, &$5, &vd, &@5);
        $$ = vd;
      }
;

FunctionCallStmt
    : FunctionCallBegin FunctionCallArgList {
        ValueData ret = {.count = 0, .valueType = OBJECT_TYPE_UNDEFINED};
        func_call($1, &currentCallFunc, &ret, &currentCallLoc);
        object_free(&currentCallFunc);
        currentCallFunc = (Object){.type = OBJECT_TYPE_UNDEFINED};
        $$ = ret;
      }
;

FunctionCallBegin
    : CALL VariableStmt { currentCallFunc = $2; currentCallLoc = @2; $$ = func_callInit(&currentCallFunc); }
;

FunctionCallArgList
    : FunctionCallArgList EXP_PREPOSITION ValueStmt { func_callArgAdd($<func_call>0, &$3, &@3); }
    | EXP_PREPOSITION ValueStmt                     { func_callArgAdd($<func_call>0, &$2, &@2); }
    |
;

ExpressionChainStmt
    : ExpressionStmt      { $$ = $1; parserSetLast(&$$); }
    | ExpressionChainStmt ExpressionNextStmt { object_free(&$1); $$ = $2; parserSetLast(&$$); }
;

ExpressionStmt
    : EXP_MATH_OP ValueLiteralOrLastStmt EXP_PREPOSITION ValueLiteralOrLastStmt { $$ = code_expression($1, $3, &$2, &$4, &@1, &@4); }
    | EXP_MATH_OP ValueLiteralOrLastStmt EXP_PREPOSITION ValueLiteralOrLastStmt EXP_MATH_MOD_OP { $$ = code_expressionMod($1, $5, $3, &$2, &$4, &@1, &@5); }
    | ValueStmt EXP_LOGIC_OP ValueStmt { $$ = code_expression($2, false, &$1, &$3, &@1, &@3); }
    | THOSE ValueStmt ValueStmt EXP_BINARY_LOGIC_OP { $$ = code_expression($4, false, &$2, &$3, &@1, &@3); }
;

ExpressionNextStmt
    : EXP_MATH_OP ValueLiteralOrLastStmt EXP_PREPOSITION ValueLiteralOrLastStmt { $$ = code_expressionChain($1, $3, &$2, &$4, &@1, &@4); }
    | EXP_MATH_OP ValueLiteralOrLastStmt EXP_PREPOSITION ValueLiteralOrLastStmt EXP_MATH_MOD_OP { $$ = code_expressionChainMod($1, $5, $3, &$2, &$4, &@1, &@5); }
    | ValueLiteralOrLastStmt EXP_LOGIC_OP ValueStmt { $$ = code_expressionChain($2, false, &$1, &$3, &@1, &@3); }
;

ValueLiteralOrLastStmt
    : ValueStmt { $$ = $1; }
    | ITS       { $$ = cloneObjectForParser(&ctx->last_result); }
;

ValueStmt
    : LitOrVarStmt                  { $$ = $1; }
    | ExpressionStmt                { $$ = $1; parserSetLast(&$$); }
    | FunctionCallStmt              { Object* obj = object_ValueDataListPop(&$1); $$ = obj ? *obj : (Object){OBJECT_TYPE_UNDEFINED}; if (obj) { parserSetLast(&$$); free(obj); } object_ValueDataListFree(&$1); }
    | ValueStmt LENGTH              { $$ = code_getLength(&$1, &@1); }
    | THOSE ValueStmt               { $$ = $2; }
    | THOSE ValueStmt LENGTH        { $$ = code_getLength(&$2, &@1); }
    | ValueStmt INDEX ValueStmt     { $$ = object_getIndex(&$1, &$3, &@1, &@3); object_free(&$1); object_free(&$3); }
    | THOSE ValueStmt INDEX ValueStmt { $$ = object_getIndex(&$2, &$4, &@1, &@4); object_free(&$2); object_free(&$4); }
;

LitOrVarStmt
    : ValueLiteralStmt { $$ = $1; }
    | VariableStmt     { $$ = $1; }
;

ValueLiteralStmt
    : NUMBER_LIT { $$ = object_createNumber(&$1); }
    | BOOL_LIT   { $$ = object_createBool($1); }
    | STR_LIT    { $$ = object_createStr($1); }
;

VariableStmt
    : IDENT { $$ = scope_findSymbol($1); free($1); }
;

%%

#include "compiler.h"
