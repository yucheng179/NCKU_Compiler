/* Definition section */
%option yymore
%{
    #include <utf8.c/utf8.h>
    #include "lib/code_gen.h"
    #include "compiler_util.h"
    #include "object.h"
    #include "value_data.h"
    #include "y.tab.h"

    #define YY_NO_UNPUT
    #define YY_NO_INPUT

    int yycolumn, yyoffset, yycolumnUtf8 = 1, yylengUtf8;
    utf8_string yytextUtf8;

    static inline void updateNewline() {
        yylloc.first_line = yylineno;
        yycolumn = 0;
        yycolumnUtf8 = 1;
    }

    static inline void processUtf8Char() {
        yytextUtf8 = make_utf8_string(yytext);
        if (yytextUtf8.str) {
            yylengUtf8 = utf8_char_count(yytextUtf8);
            yylloc.last_line = yylineno;
            yylloc.first_column = yycolumnUtf8;
            yylloc.last_column = yycolumnUtf8 + yylengUtf8 - 1;
            yylloc.first_column_byte = yycolumn;
            yylloc.last_column_byte = yycolumn + yytextUtf8.byte_len - 1;
            yylloc.line_start_offset = yyoffset - yycolumn;
            yycolumnUtf8 += yylengUtf8;
            yyoffset += yytextUtf8.byte_len;
            yycolumn += yytextUtf8.byte_len;
        }
    }

    bool unrecognizedChar = false;
    char unregBuf[ERROR_TEXT_BUFFER_LEN] = {0};
    YYLTYPE unregLoc;

    static inline void flushUnrecognized() {
        if (unregBuf[0] != '\0') {
            YYLTYPE current_loc = yylloc;
            yylloc = unregLoc;
            yylloc.last_line = current_loc.first_line - 1;
            yylloc.last_column = current_loc.first_column - 1;
            yylloc.last_column_byte = current_loc.first_column_byte - 1;
            compileError = true;
            yyerror("謬字「%s」", unregBuf);
            yylloc = current_loc;
            unregBuf[0] = '\0';
        }
    }

    static inline void readUnrecognizedChar() {
        if (yytextUtf8.str) {
            if (unregBuf[0] == '\0') unregLoc = yylloc;
            if (strlen(unregBuf) + yyleng < sizeof(unregBuf)) strcat(unregBuf, yytext);
        } else {
            yymore();
        }
        unrecognizedChar = true;
    }

    static inline void yymore_utf8() {
        yymore();
        if (yytextUtf8.str) {
            yycolumnUtf8 -= yylengUtf8;
            yyoffset -= yytextUtf8.byte_len;
            yycolumn -= yytextUtf8.byte_len;
        }
    }

    #define YY_USER_ACTION \
        if (!unrecognizedChar) flushUnrecognized(); \
        unrecognizedChar = false; \
        processUtf8Char();

    void trimStringToken(int paddLen, char** result) {
        int strLastTokenLen = yyleng - paddLen - paddLen;
        *result = (char*)malloc(strLastTokenLen + 1);
        memcpy(*result, yytext + paddLen, strLastTokenLen);
        (*result)[strLastTokenLen] = '\0';
    }
%}

digit ("負"|"·"|"又"|"有"|"零"|"〇"|"一"|"二"|"三"|"四"|"五"|"六"|"七"|"八"|"九"|"兩"|"十"|"百"|"千"|"萬"|"億"|"兆"|"京"|"垓"|"秭"|"穰"|"溝"|"澗"|"正"|"載"|"極"|"分"|"釐"|"毫"|"絲"|"忽"|"微"|"纖"|"沙"|"塵"|"埃"|"渺"|"漠"|"壹"|"貳"|"參"|"肆"|"伍"|"陸"|"柒"|"捌"|"玖"|"拾"|"佰"|"仟")
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
%x CMT_CON
%x STR_CON
%x IDENT_CON

%%
<INITIAL>"注曰"            { lexerLog("COMMENT\n"); return COMMENT; }
<INITIAL>"批曰"            { lexerLog("COMMENT\n"); return COMMENT; }
<INITIAL>"吾有"|"今有"    { lexerLog("HERE_ARE\n"); return HERE_ARE; }
<INITIAL>"名之曰"          { lexerLog("NAME_IT\n"); return NAME_IT; }
<INITIAL>"欲行是術"        { lexerLog("TO_PERFORM_FUNC\n"); return TO_PERFORM_FUNC; }
<INITIAL>"必先得"          { lexerLog("REQUIRE_ARGS\n"); return REQUIRE_ARGS; }
<INITIAL>"乃行是術曰"      { lexerLog("FUNC_BEGIN\n"); return FUNC_BEGIN; }
<INITIAL>"所餘幾何"        { yylval.exp_op = OP_MOD; lexerLog("EXP_MATH_MOD_OP\n"); return EXP_MATH_MOD_OP; }
<INITIAL>"不大於"          { yylval.exp_op = OP_LE; lexerLog("EXP_LOGIC_OP\n"); return EXP_LOGIC_OP; }
<INITIAL>"不小於"          { yylval.exp_op = OP_GE; lexerLog("EXP_LOGIC_OP\n"); return EXP_LOGIC_OP; }
<INITIAL>"不等於"          { yylval.exp_op = OP_NE; lexerLog("EXP_LOGIC_OP\n"); return EXP_LOGIC_OP; }
<INITIAL>"中無陰乎"        { yylval.exp_op = OP_AN; lexerLog("EXP_BINARY_LOGIC_OP\n"); return EXP_BINARY_LOGIC_OP; }
<INITIAL>"中有陽乎"        { yylval.exp_op = OP_OR; lexerLog("EXP_BINARY_LOGIC_OP\n"); return EXP_BINARY_LOGIC_OP; }
<INITIAL>"乃得""矣"?      { lexerLog("RETURN\n"); return RETURN; }
<INITIAL>"取"              { lexerLog("TAKE\n"); return TAKE; }
<INITIAL>"以施"            { lexerLog("TO_CALL\n"); return TO_CALL; }
<INITIAL>"是謂"            { lexerLog("FUNC_END_FOR\n"); return FUNC_END_FOR; }
<INITIAL>"之術"            { lexerLog("FUNC_END\n"); return FUNC_END; }
<INITIAL>"之長"            { lexerLog("LENGTH\n"); return LENGTH; }
<INITIAL>"恆為是"          { lexerLog("WHILE_TRUE\n"); return WHILE_TRUE; }
<INITIAL>"若非"            { lexerLog("ELSE\n"); return ELSE; }
<INITIAL>"或若"            { lexerLog("ELSE_IF\n"); return ELSE_IF; }
<INITIAL>"云云"            { lexerLog("END\n"); return END; }
<INITIAL>"為是"            { lexerLog("FOR\n"); return FOR; }
<INITIAL>"昔之"            { lexerLog("PAST\n"); return PAST; }
<INITIAL>"是矣"            { lexerLog("IS_THUS\n"); return IS_THUS; }
<INITIAL>"乃止"            { lexerLog("BREAK\n"); return BREAK; }
<INITIAL>"書之"            { lexerLog("PRINT\n"); return PRINT; }
<INITIAL>"大於"            { yylval.exp_op = OP_GT; lexerLog("EXP_LOGIC_OP\n"); return EXP_LOGIC_OP; }
<INITIAL>"小於"            { yylval.exp_op = OP_LT; lexerLog("EXP_LOGIC_OP\n"); return EXP_LOGIC_OP; }
<INITIAL>"等於"            { yylval.exp_op = OP_EQ; lexerLog("EXP_LOGIC_OP\n"); return EXP_LOGIC_OP; }
<INITIAL>"若"              { lexerLog("IF\n"); return IF; }
<INITIAL>"也"              { lexerLog("END\n"); return END; }
<INITIAL>"恆"              { lexerLog("WHILE_TRUE\n"); return WHILE_TRUE; }
<INITIAL>"遍"              { lexerLog("END\n"); return END; }
<INITIAL>"有"              { lexerLog("HERE_IS_A\n"); return HERE_IS_A; }
<INITIAL>"曰"              { lexerLog("SAID\n"); return SAID; }
<INITIAL>"其"              { lexerLog("ITS\n"); return ITS; }
<INITIAL>"者"              { lexerLog("TOPIC\n"); return TOPIC; }
<INITIAL>"今"              { lexerLog("SET\n"); return SET; }
<INITIAL>"施"              { lexerLog("CALL\n"); return CALL; }
<INITIAL>"充"              { lexerLog("PUSH\n"); return PUSH; }
<INITIAL>"於"              { yylval.exp_left = true; lexerLog("EXP_PREPOSITION\n"); return EXP_PREPOSITION; }
<INITIAL>"以"              { yylval.exp_left = false; lexerLog("EXP_PREPOSITION\n"); return EXP_PREPOSITION; }
<INITIAL>"之"              { lexerLog("INDEX\n"); return INDEX; }
<INITIAL>"夫"              { lexerLog("THOSE\n"); return THOSE; }
<INITIAL>"數"              { yylval.var_type = OBJECT_TYPE_NUM; lexerLog("VAR_TYPE 數\n"); return VAR_TYPE; }
<INITIAL>"言"              { yylval.var_type = OBJECT_TYPE_STR; lexerLog("VAR_TYPE 言\n"); return VAR_TYPE; }
<INITIAL>"爻"              { yylval.var_type = OBJECT_TYPE_BOOL; lexerLog("VAR_TYPE 爻\n"); return VAR_TYPE; }
<INITIAL>"列"              { yylval.var_type = OBJECT_TYPE_ARRAY; lexerLog("VAR_TYPE 列\n"); return VAR_TYPE; }
<INITIAL>"元"              { yylval.var_type = OBJECT_TYPE_AUTO; lexerLog("VAR_TYPE 元\n"); return VAR_TYPE; }
<INITIAL>"術"              { yylval.var_type = OBJECT_TYPE_FUNC; lexerLog("VAR_TYPE_FUNC 術\n"); return VAR_TYPE_FUNC; }
<INITIAL>"陽"              { yylval.b_var = true; return BOOL_LIT; }
<INITIAL>"陰"              { yylval.b_var = false; return BOOL_LIT; }
<INITIAL>"加"              { yylval.exp_op = OP_ADD; return EXP_MATH_OP; }
<INITIAL>"減"              { yylval.exp_op = OP_SUB; return EXP_MATH_OP; }
<INITIAL>"乘"              { yylval.exp_op = OP_MUL; return EXP_MATH_OP; }
<INITIAL>"除"              { yylval.exp_op = OP_DIV; return EXP_MATH_OP; }

<INITIAL>"「「"            { BEGIN(STR_CON); yymore_utf8(); }
<STR_CON>"」」」"          { trimStringToken(6, &yylval.s_var); BEGIN(INITIAL); return STR_LIT; }
<STR_CON>"」」"            { trimStringToken(6, &yylval.s_var); BEGIN(INITIAL); return STR_LIT; }
<STR_CON>"」"|{EXCLUDE_QUO}+|\r?\n { yymore_utf8(); }
<INITIAL>"「"              { BEGIN(IDENT_CON); yymore_utf8(); }
<IDENT_CON>"」"            { trimStringToken(3, &yylval.s_var); BEGIN(INITIAL); lexerLog("IDENT %s\n", yylval.s_var); return IDENT; }
<IDENT_CON>{EXCLUDE_QUO}+|\r?\n { yymore_utf8(); }

<INITIAL>{digit}+           { chineseToArabic(yytext, &yylval.n_var); lexerLog("NUMBER_LIT %s\n", yytext); return NUMBER_LIT; }
"。" {}
"，" {}
[ \t]+      {}
\r?\n       { updateNewline(); }
{UTF8_BOM}  { updateNewline(); }
<<EOF>>     { yyterminate(); }
{ALL_UTF8} { readUnrecognizedChar(); }
. { readUnrecognizedChar(); }

%%
int yywrap(void) { return 1; }
