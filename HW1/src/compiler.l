/* Definition section */
%option yymore
%{
    #include <inttypes.h>
    #include <math.h>
    #include <stdlib.h>
    #include <string.h>
    #include <utf8.c/utf8.h>
    #include "chinese_number.h"
    #include "compiler_util.h"

    #define YY_NO_UNPUT
    #define YY_NO_INPUT

    int yylineUtf8 = 1, yycolumnUtf8 = 0;
    int yylengUtf8, yytokenLine = 1, yytokenColumn = 1;
    utf8_string yytextUtf8;

    static void advancePosition(const char* text) {
        utf8_string ustr = make_utf8_string(text);
        if (!ustr.str) return;

        yylengUtf8 = (int)utf8_char_count(ustr);
        utf8_char_iter iter = make_utf8_char_iter(ustr);
        utf8_char ch;
        while ((ch = next_utf8_char(&iter)).byte_len > 0) {
            if (ch.byte_len == 1 && ch.str[0] == '\n') {
                ++yylineUtf8;
                yycolumnUtf8 = 0;
            } else if (!(ch.byte_len == 1 && ch.str[0] == '\r')) {
                ++yycolumnUtf8;
            }
        }
    }

    static inline void updateNewline() {
        /* Position is already updated in YY_USER_ACTION. */
    }

    static inline void processUtf8Char() {
        yytokenLine = yylineUtf8;
        yytokenColumn = yycolumnUtf8 + 1;
        yytextUtf8 = make_utf8_string(yytext);
        if (yytextUtf8.str) {
            advancePosition(yytext);
        }
    }

    static inline void yymore_utf8() {
        yymore();
        if (yytextUtf8.str) {
            yylineUtf8 = yytokenLine;
            yycolumnUtf8 = yytokenColumn - 1;
        }
    }

    #define YY_USER_ACTION \
        processUtf8Char();

    #define PRINT_TOKEN(format, ...) printf("%d:%d: " format "\n", yytokenLine, yytokenColumn, __VA_ARGS__)
    #define PRINT_TOKEN0(format) printf("%d:%d: " format "\n", yytokenLine, yytokenColumn)

    char* trimStringToken(int paddLen) {
        static char cache[8192];
        size_t len = strlen(yytext);
        if (len < (size_t)paddLen * 2) {
            cache[0] = '\0';
            return cache;
        }
        len -= (size_t)paddLen * 2;
        if (len >= sizeof(cache)) len = sizeof(cache) - 1;
        memcpy(cache, yytext + paddLen, len);
        cache[len] = '\0';
        return cache;
    }

    char* formatStringToken() {
        static char cache[8192];
        size_t len = strlen(yytext);
        const size_t paddLen = 6;
        if (len < paddLen * 2) {
            strcpy(cache, "\"\"");
            return cache;
        }
        len -= paddLen * 2;
        size_t copyLen = len;
        if (copyLen + 3 > sizeof(cache)) copyLen = sizeof(cache) - 3;
        cache[0] = '"';
        memcpy(cache + 1, yytext + paddLen, copyLen);
        cache[copyLen + 1] = '"';
        cache[copyLen + 2] = '\0';
        return cache;
    }

    void printNumberToken() {
        ScientificNotation sci;
        if (!chineseToArabic(yytext, &sci)) {
            if (sci.type == F64) {
                double doubleValue = sciToDouble(&sci);
                int64_t intValue = (int64_t)doubleValue;
                if (isfinite(doubleValue) && doubleValue == (double)intValue) {
                    printf("%d:%d: NUMBER_LIT %" PRId64 "\n", yytokenLine, yytokenColumn, intValue);
                    return;
                }
            }

            char* value = sciToStr(&sci);
            if (value) {
                PRINT_TOKEN("NUMBER_LIT %s", value);
                free(value);
            }
        }
    }
%}

/* Define regular expression label */
digit ("負"|"零"|"〇"|"一"|"二"|"三"|"四"|"五"|"六"|"七"|"八"|"九"|"兩"|"十"|"百"|"千"|"萬"|"億"|"兆"|"京"|"垓"|"秭"|"穰"|"溝"|"澗"|"正"|"載"|"極"|"分"|"釐"|"毫"|"絲"|"忽"|"微"|"纖"|"沙"|"塵"|"埃"|"渺"|"漠"|"壹"|"貳"|"參"|"肆"|"伍"|"陸"|"柒"|"捌"|"玖"|"拾"|"佰"|"仟"|"又"|"·")+

UTF8_BOM "\357\273\277"

ASCII   [\x00-\x7f]
U       [\x80-\xbf]

B2      [\xC2-\xDF]{U}
B3_1    \xE0[\xA0-\xBF]{U}
B3_2    [\xE1-\xEC]{U}{U}
B3_3    \xED[\x80-\x9F]{U}
B3_4    [\xEE-\xEF]{U}{U}
B4_1    \xF0[\x90-\xBF]{U}{U}
B4_2    [\xF1-\xF3]{U}{U}{U}
B4_3    \xF4[\x80-\x8F]{U}{U}

ALL_UTF8 {ASCII}|{B2}|{B3_1}|{B3_2}|{B3_3}|{B3_4}|{B4_1}|{B4_2}|{B4_3}

B3_2_EXCLUDE_QUO ([\xE1-\xE2]{U}{U})|(\xE3\x80[\x80-\x8C\x8E-\xBF])|(\xE3[\x81-\xBF]{U})|([\xE4-\xEC]{U}{U})

EXCLUDE_QUO [\x20-\x7E]|{B2}|{B3_1}|{B3_2_EXCLUDE_QUO}|{B3_3}|{B3_4}|{B4_1}|{B4_2}|{B4_3}

%option yylineno
%x IDENT_CON STR_CON

%%

"「「"        { BEGIN(STR_CON); yymore_utf8(); }
<STR_CON>"」」」" { BEGIN(INITIAL); PRINT_TOKEN("STR_LIT %s", formatStringToken()); }
<STR_CON>"」」"   { BEGIN(INITIAL); PRINT_TOKEN("STR_LIT %s", formatStringToken()); }
<STR_CON>"」"    { yymore_utf8(); }
<STR_CON>\r?\n   { yymore_utf8(); }
<STR_CON>{EXCLUDE_QUO}+ { yymore_utf8(); }

"「"        { BEGIN(IDENT_CON); yymore_utf8(); }
<IDENT_CON>"」"    { BEGIN(INITIAL); PRINT_TOKEN("IDENT '%s'", trimStringToken(3)); }
<IDENT_CON>\r?\n    { yymore_utf8(); }
<IDENT_CON>{EXCLUDE_QUO}+    { yymore_utf8(); }

"乃行是術曰"|"乃是術曰" { PRINT_TOKEN("FUNC_BEGIN %s", yytext); }
"欲行是術"  { PRINT_TOKEN("TO_PERFORM_FUNC %s", yytext); }
"必先得"    { PRINT_TOKEN("REQUIRE_ARGS %s", yytext); }
"是謂"      { PRINT_TOKEN("FUNC_END_FOR %s", yytext); }
"之術也"    { PRINT_TOKEN("FUNC_END %s", yytext); }
"乃得"      { PRINT_TOKEN("RETURN %s", yytext); }

"恆為是"    { PRINT_TOKEN("WHILE_TRUE %s", yytext); }
"乃止"      { PRINT_TOKEN("BREAK %s", yytext); }
"為是"      { PRINT_TOKEN("FOR %s", yytext); }
"遍"        { PRINT_TOKEN("TIMES %s", yytext); }
"或若"      { PRINT_TOKEN("ELSE_IF %s", yytext); }
"若非"      { PRINT_TOKEN("ELSE %s", yytext); }
"若"        { PRINT_TOKEN("IF %s", yytext); }

"中有陽乎"  { PRINT_TOKEN("EXP_LOGIC %s", "||"); }
"中無陰乎"  { PRINT_TOKEN("EXP_LOGIC %s", "&&"); }
"不小於"    { PRINT_TOKEN("EXP_LOGIC %s", ">="); }
"不大於"    { PRINT_TOKEN("EXP_LOGIC %s", "<="); }
"不等於"    { PRINT_TOKEN("EXP_LOGIC %s", "!="); }
"大於"      { PRINT_TOKEN("EXP_LOGIC %s", ">"); }
"小於"      { PRINT_TOKEN("EXP_LOGIC %s", "<"); }
"等於"      { PRINT_TOKEN("EXP_LOGIC %s", "=="); }

"所餘幾何"  { PRINT_TOKEN("EXP_MATH_OP %s", "%"); }
"加"        { PRINT_TOKEN("EXP_MATH %s", "+"); }
"減"        { PRINT_TOKEN("EXP_MATH %s", "-"); }
"乘"        { PRINT_TOKEN("EXP_MATH %s", "*"); }
"除"        { PRINT_TOKEN("EXP_MATH %s", "/"); }
"於"        { PRINT_TOKEN0("<-"); }
"以"        { PRINT_TOKEN0("->"); }

"吾有"|"今有" { PRINT_TOKEN("HERE_ARE %s", yytext); }
"有"        { PRINT_TOKEN("HERE_IS_A %s", yytext); }
"名之曰"    { PRINT_TOKEN("NAME_IT %s", yytext); }
"昔之"      { PRINT_TOKEN("PAST %s", yytext); }
"是矣"      { PRINT_TOKEN("IS_THUS %s", yytext); }
"曰"        { PRINT_TOKEN("SAID %s", yytext); }
"今"        { PRINT_TOKEN("SET %s", yytext); }
"其"        { PRINT_TOKEN("ITS %s", yytext); }
"者"        { PRINT_TOKEN("TOPIC %s", yytext); }

"之長"      { PRINT_TOKEN("LENGTH %s", yytext); }
"書之"      { PRINT_TOKEN("PRINT %s", yytext); }
"夫"        { PRINT_TOKEN("THOSE %s", yytext); }
"取"        { PRINT_TOKEN("TAKE %s", yytext); }
"充"        { PRINT_TOKEN("PUSH %s", yytext); }
"施"        { PRINT_TOKEN("CALL %s", yytext); }
"之"        { PRINT_TOKEN("INDEX %s", yytext); }

"也"|"云云"|"矣" { PRINT_TOKEN("END %s", yytext); }

"注曰"|"疏曰"|"批曰" { PRINT_TOKEN("COMMENT %s", yytext); }
"陽"        { PRINT_TOKEN("BOOL_LIT %s", "true"); }
"陰"        { PRINT_TOKEN("BOOL_LIT %s", "false"); }
"術"        { PRINT_TOKEN("VAR_TYPE_FUNC %s", yytext); }
"長"|"數"|"言"|"爻"|"元"|"列" { PRINT_TOKEN("VAR_TYPE %s", yytext); }

{digit}     { printNumberToken(); }

[ \t]+      {}
\r?\n       { updateNewline(); }
"。"|"，"|"," {}
{UTF8_BOM}  { yycolumnUtf8 = 0; }

<<EOF>>     { yyterminate(); }

{ALL_UTF8} { PRINT_TOKEN("UNKNOWN CHAR %s", yytext); }
. { PRINT_TOKEN("UNKNOWN CHAR %s", yytext); }

%%
int yywrap(void) {
    return 1;
}