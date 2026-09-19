//
// Created by WavJaby on 2026/3/2.
//

#include "value_data.h"

#include <string.h>

#include "compiler_util.h"

static bool type_compatible(ObjectType expected, ObjectType actual) {
    if (expected == OBJECT_TYPE_AUTO) return true;
    if (expected == OBJECT_TYPE_NUM)
        return ObjectType_isNumber(actual) || actual == OBJECT_TYPE_NUM || actual == OBJECT_TYPE_SYMBOL || actual == OBJECT_TYPE_REGISTER;
    if (expected == OBJECT_TYPE_STR) return true;
    if (actual == OBJECT_TYPE_SYMBOL || actual == OBJECT_TYPE_REGISTER) return true;
    return expected == actual;
}

static Object clone_object_value(const Object* obj) {
    Object clone = *obj;
    switch (obj->type) {
    case OBJECT_TYPE_STR:
        if (obj->value.str) clone.value.str = strdup(obj->value.str);
        break;
    case OBJECT_TYPE_I32:
    case OBJECT_TYPE_I64:
    case OBJECT_TYPE_F64:
    case OBJECT_TYPE_NUM:
        if (obj->value.number) clone.value.number = cloneStruct(ScientificNotation, obj->value.number);
        break;
    case OBJECT_TYPE_REGISTER:
        if (obj->value.symbol) clone.value.symbol = symbol_clone(obj->value.symbol);
        break;
    default:
        break;
    }
    return clone;
}

bool object_ValueDataListCreate(ObjectType valueType, const ScientificNotation* count, ValueData* valueData) {
    linkedList_init(&valueData->valueList);
    valueData->valueType = valueType;
    valueData->count = (count != NULL) ? sciToInt32(count) : 1;
    if (valueData->count <= 0) {
        yyerrorf("????????\n");
        return true;
    }
    return false;
}

bool object_ValueDataListAdd(ValueData* valueData, const Object* obj, const YYLTYPE* tokenLoc) {
    if ((int32_t)valueData->valueList.length >= valueData->count) {
        yyerrorlf("??????\n", tokenLoc);
        return true;
    }

    const ObjectType actual = object_getValueType(obj);
    if (valueData->valueType == OBJECT_TYPE_AUTO)
        valueData->valueType = actual;
    else if (!type_compatible(valueData->valueType, actual)) {
        yyerrorlf("?????%s???????%s???\n", tokenLoc,
                  objectType2str[actual], objectType2str[valueData->valueType]);
        return true;
    }

    Object clone = clone_object_value(obj);
    linkedList_addp(&valueData->valueList, false, cloneStruct(Object, &clone));
    return false;
}

bool object_ValueDataListAddDefaults(ValueData* valueData, const YYLTYPE* tokenLoc) {
    while ((int32_t)valueData->valueList.length < valueData->count) {
        Object obj;
        switch (valueData->valueType) {
        case OBJECT_TYPE_STR:
            obj = object_createStr(strdup(""));
            break;
        case OBJECT_TYPE_BOOL:
            obj = object_createBool(false);
            break;
        case OBJECT_TYPE_ARRAY:
            obj = object_createArray();
            break;
        case OBJECT_TYPE_AUTO:
        case OBJECT_TYPE_NUM:
        case OBJECT_TYPE_I32: {
            ScientificNotation zero; chineseToArabic("\xE9\x9B\xB6", &zero);
            obj = object_createNumber(&zero);
            if (valueData->valueType == OBJECT_TYPE_AUTO) valueData->valueType = obj.type;
            break;
        }
        case OBJECT_TYPE_I64: {
            ScientificNotation zero; chineseToArabic("\xE9\x9B\xB6", &zero); zero.type = I64;
            obj = object_createNumber(&zero);
            break;
        }
        case OBJECT_TYPE_F64: {
            ScientificNotation zero; chineseToArabic("\xE9\x9B\xB6", &zero); zero.type = F64;
            obj = object_createNumber(&zero);
            break;
        }
        default:
            yyerrorlf("?%s??????\n", tokenLoc, objectType2str[valueData->valueType]);
            return true;
        }
        if (object_ValueDataListAdd(valueData, &obj, tokenLoc)) {
            object_free(&obj);
            return true;
        }
        object_free(&obj);
    }
    return false;
}

Object* object_ValueDataListPop(ValueData* valueData) {
    if (valueData->valueList.length == 0)
        return NULL;
    LinkedListNode* node = valueData->valueList.head->next;
    Object* obj = node->value;
    linkedList_deleteNode(&valueData->valueList, node);
    return obj;
}

bool object_ValueDataListFree(ValueData* valueData) {
    linkedList_freeA(&valueData->valueList, free);
    return false;
}
