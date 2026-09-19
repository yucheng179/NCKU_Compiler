#include "expression.h"

#include "lib/code_gen.h"
#include "compiler_util.h"
#include "object.h"
#include "scope.h"

static inline bool object_sameRegister(const Object* a, const Object* b) {
    return a->type == OBJECT_TYPE_REGISTER && b->type == OBJECT_TYPE_REGISTER &&
        a->value.symbol->index == b->value.symbol->index;
}

static inline bool isExpressionOperationLegal(const ExpOp eop, const ObjectType targetType) {
    if (ExpOp_isArithmetic(eop) && !ObjectType_isNumber(targetType)) {
        if (eop == OP_ADD && targetType == OBJECT_TYPE_STR) {
            // String concatenation is legal
        } else {
            yyerrorf("運算符號『%s』不適用於『%s』之屬\n", expOp2str[eop], objectType2str[targetType]);
            return false;
        }
    }
    if (ExpOp_isBooleanOnly(eop) && targetType != OBJECT_TYPE_BOOL) {
        yyerrorf("運算符號『%s』不適用於『%s』之屬\n", expOp2str[eop], objectType2str[targetType]);
        return false;
    }
    if (eop == OP_MOD && !ObjectType_isInteger(targetType)) {
        yyerrorf("運算符號『%s』不適用於『%s』之屬\n", expOp2str[eop], objectType2str[targetType]);
        return false;
    }
    return true;
}

Object code_expression(const ExpOp eop, const bool opLeft, Object* a, Object* b,
                       const YYLTYPE* aLoc, const YYLTYPE* bLoc) {
    ObjectType aValueType = object_getValueType(a), bValueType = object_getValueType(b);
    ObjectType targetType = object_getPromotedType(aValueType, bValueType);
    if (eop == OP_ADD && aValueType == OBJECT_TYPE_STR && bValueType == OBJECT_TYPE_STR)
        targetType = OBJECT_TYPE_STR;
    if (targetType == OBJECT_TYPE_UNDEFINED || !isExpressionOperationLegal(eop, targetType))
        goto FAILED;

    const Object* lhs = opLeft ? b : a;
    const Object* rhs = opLeft ? a : b;

    ObjectType resultType = ExpOp_isOutputLogic(eop) ? OBJECT_TYPE_BOOL : targetType;
    SymbolData resultReg = object_createRegisterSymbol(resultType);

    char lhsName[MAX_NAME_LENGTH], rhsName[MAX_NAME_LENGTH];
    Object regLhs, regRhs;

    if (targetType == OBJECT_TYPE_STR && eop == OP_ADD) {
        regLhs = object_nameLiteralOrLoadReg(lhs, lhsName, MAX_NAME_LENGTH);
        regRhs = object_nameLiteralOrLoadReg(rhs, rhsName, MAX_NAME_LENGTH);
        if (regLhs.type == OBJECT_TYPE_UNDEFINED || regRhs.type == OBJECT_TYPE_UNDEFINED) goto FAILED;
        buffPrintln(&ctx->code, "%%reg%s = call ptr @wy_rt_str_concat(ptr %s, ptr %s)",
                    resultReg.name, lhsName, rhsName);
    } else {
        regLhs = object_loadRegAndPromote(lhs, targetType, lhsName, MAX_NAME_LENGTH);
        regRhs = object_loadRegAndPromote(rhs, targetType, rhsName, MAX_NAME_LENGTH);
        if (regLhs.type == OBJECT_TYPE_UNDEFINED || regRhs.type == OBJECT_TYPE_UNDEFINED) goto FAILED;
        const char* op = ObjectType_isFloat(targetType) ? opIRFloatNames[eop] : opIRIntNames[eop];
        if (!op) goto FAILED;
        buffPrintln(&ctx->code, "%%reg%s = %s %s %s, %s",
                    resultReg.name, op, objectType2llvmType[targetType], lhsName, rhsName);
    }

    Object result = (Object){OBJECT_TYPE_REGISTER, .value.symbol = cloneStruct(SymbolData, &resultReg)};
    compilerLogAt(aLoc, "exp %s %s %s -> %s\n", object_print(lhs), opDebugNames[eop], object_print(rhs), object_print(&result));

    if (lhs->type == OBJECT_TYPE_SYMBOL || (regLhs.type == OBJECT_TYPE_REGISTER && lhs->type != OBJECT_TYPE_REGISTER)) object_free(&regLhs);
    if (rhs->type == OBJECT_TYPE_SYMBOL || (regRhs.type == OBJECT_TYPE_REGISTER && rhs->type != OBJECT_TYPE_REGISTER)) object_free(&regRhs);
    if (!object_sameRegister(a, b)) object_free(a);
    object_free(b);
    return result;

FAILED:
    if (!object_sameRegister(a, b)) object_free(a);
    object_free(b);
    return (Object){.type = OBJECT_TYPE_UNDEFINED, .value = {}};
}

Object code_expressionMod(ExpOp dop, ExpOp eop, bool op_left, Object* a, Object* b,
                          YYLTYPE* dopLoc, YYLTYPE* eopLoc) {
    if (dop != OP_DIV) {
        yyerrorf("欲問所餘，必先用除\n");
        goto FAILED;
    }
    return code_expression(eop, op_left, a, b, dopLoc, eopLoc);

FAILED:
    if (!object_sameRegister(a, b)) object_free(a);
    object_free(b);
    return (Object){.type = OBJECT_TYPE_UNDEFINED, .value = {}};
}

Object code_expressionChain(ExpOp eop, bool op_left, Object* a, Object* b,
                            YYLTYPE* aLoc, YYLTYPE* bLoc) {
    return code_expression(eop, op_left, a, b, aLoc, bLoc);
}

Object code_expressionChainMod(ExpOp dop, ExpOp eop, bool op_left, Object* a, Object* b,
                               YYLTYPE* dopLoc, YYLTYPE* eopLoc) {
    if (dop != OP_DIV) {
        yyerrorf("欲問所餘，必先用除\n");
        object_free(a);
        object_free(b);
        return (Object){.type = OBJECT_TYPE_UNDEFINED, .value = {}};
    }
    return code_expressionChain(eop, op_left, a, b, dopLoc, eopLoc);
}
