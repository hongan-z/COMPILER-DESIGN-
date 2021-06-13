
/*
BISON specification for MINI-L language
*/

%{
#include <stdio.h>
#include <stdlib.h>

void yyerror(const char *msg);
extern int currLine;
extern int currPos;
extern char* currStr;
FILE * yyin;
int yylex();
%}

%union{
    double dval;
    int ival;
    char* strval;
}

%error-verbose
%start Program


%token FUNCTION BEGIN_PARAMS END_PARAMS BEGIN_LOCALS END_LOCALS BEGIN_BODY END_BODY 
%token INTEGER ARRAY OF IF THEN ENDIF ELSE IN
%token WHILE DO BEGINLOOP ENDLOOP CONTINUE FOR FOREACH
%token READ WRITE AND OR NOT TRUE FALSE RETURN BREAK
%token ADD SUB MULT DIV MOD
%token EQ NEQ LT GT LTE GTE
%token SEMICOLON COLON COMMA L_PAREN R_PAREN L_SQUARE_BRACKET R_SQUARE_BRACKET ASSIGN
%token <strval> IDENT
%token <ival> NUMBER
%token WRONG




%%
Program:		%empty {printf("");}
				|Program functions Program{printf("prog_start -> functions\n");}
				 
;

;
function: 		 FUNCTION ident SEMICOLON BEGIN_PARAMS declarations END_PARAMS BEGIN_LOCALS declarations END_LOCALS BEGIN_BODY statements END_BODY {printf("function -> FUNCTION IDENT SEMICOLON BEGIN_PARAMS declarations END_PARAMS BEGIN_LOCALS declarations END_LOCALS BEGIN_BODY statements END_BODY\n");}		

;
functions:		 %empty {printf("functions -> epsilon\n");}
				 |function functions {printf("functions -> function functions\n");}
;
declaration:      identifiers COLON INTEGER {printf("declaration -> identifiers COLON INTEGER\n");}
                 | identifiers COLON ARRAY L_SQUARE_BRACKET NUMBER R_SQUARE_BRACKET OF INTEGER {printf("declaration -> identifiers COLON ARRAY L_SQUARE_BRACKET NUMBER R_SQUARE_BRACKET OF INTEGER\n", $5);}
				 | identifiers error INTEGER { yyerrok; }
				 | COLON error { yyerrok; }



;
declarations:    %empty{printf("declarations -> epsilon\n");}
				 | declaration SEMICOLON declarations {printf("declarations -> declaration SEMICOLON declarations\n");}
				 | declaration error statement { yyerrok; }


;

identifiers:     ident {printf("identifiers -> ident\n");}
                 | ident COMMA identifiers {printf("identifiers -> ident COMMA identifiers\n");}

;
statements:      %empty { printf("statements -> epsilon\n"); }				 
                 |statement SEMICOLON statements {printf("statements -> statement SEMICOLON statements\n");}

;
statement:      var WRONG expression {printf("** ----- Line %d, position %d: syntax error, expecting :=\n", currLine, currPos);}
				 | var ASSIGN error expression { yyerrok; }
				 | var error expression { yyerrok; }
				 | var ASSIGN expression {printf("statement -> var ASSIGN expression\n");}
                 | IF bool_exp THEN statements Elsestatement ENDIF statements{printf("statement -> IF bool_exp THEN statements Elsestatement ENDIF\n");}
				 | IF bool_exp THEN statements ENDIF statements{printf("statement -> IF bool_exp THEN statements ENDIF\n");}	
                 | WHILE bool_exp BEGINLOOP statements ENDLOOP {printf("statement -> WHILE bool_exp BEGINLOOP statements ENDLOOP\n");}
                 | DO BEGINLOOP statements ENDLOOP WHILE bool_exp {printf("statement -> DO BEGINLOOP statements ENDLOOP WHILE bool_exp\n");}
                 | FOREACH ident IN ident BEGINLOOP statements ENDLOOP {printf("statement -> FOREACH ident IN ident BEGINLOOP statements ENDLOOP\n");}
                 | READ vars {printf("statement -> READ vars\n");}
                 | WRITE vars {printf("statement -> WRITE vars\n");}
				 | BREAK statements {printf("statement -> BREAK\n");}
                 | CONTINUE {printf("statement -> CONTINUE\n");}
                 | RETURN expression {printf("statement -> RETURN expression\n");}
				 | error statement { yyerrok; }

				 
				 
;
Elsestatement:   %empty {printf("Elsestatement -> epsilon\n");}
                 | ELSE statements {printf("Elsestatement -> ELSE statements\n");}
				 
;

var:             ident L_SQUARE_BRACKET expression R_SQUARE_BRACKET {printf("var -> ident L_SQUARE_BRACKET expression R_SQUARE_BRACKET\n");}
                 | ident {printf("var -> ident\n");}

;
vars:            var {printf("vars -> var\n");}
                 | var COMMA vars {printf("vars -> var COMMA vars\n");}

;

expression:      multiplicative_expression {printf("expression -> multiplicative_expression\n");}
                 | multiplicative_expression ADD expression {printf("expression -> multiplicative_expression ADD multiplicative_expression\n");}
                 | multiplicative_expression SUB expression {printf("expression -> multiplicative_expression SUB multiplicative_expression\n");}
;
expressions:     %empty {printf("expressions -> epsilon\n");}
                 | expression COMMA expressions {printf("expressions -> expression COMMA expressions\n");}
                 | expression {printf("expressions -> expression\n");}

;

multiplicative_expression :         term {printf("multiplicative_expression -> term\n");} 
                 | term MULT term {printf("multiplicative_expression -> term MULT term\n");}
                 | term DIV term {printf("multiplicative_expression -> term DIV term\n");}
                 | term MOD term {printf("multiplicative_expression -> term MOD term\n");}
;

term:            var {printf("term -> var\n");}
                 | SUB var {printf("term -> SUB var\n");}
                 | NUMBER {printf("term -> NUMBER\n", $1);}
                 | SUB NUMBER {printf("term -> SUB NUMBER\n", $2);}
                 | L_PAREN expression R_PAREN {printf("term -> L_PAREN expression R_PAREN\n");}
                 | SUB L_PAREN expression R_PAREN {printf("term -> SUB L_PAREN expression R_PAREN\n");}
                 | ident L_PAREN expressions R_PAREN{printf("term -> ident L_PAREN expressions R_PAREN\n");}
				 | NUMBER error { yyerrok; }

;

bool_exp:         RExp {printf("bool_exp -> relation_and_exp\n");}
                 | RExp OR bool_exp {printf("bool_exp -> relation_and_exp OR bool_exp\n");}

;

RExp:            NOT RExp1 {printf("relation_exp -> NOT relation_exp\n");}
                 | RExp1 {printf("relation_and_exp -> relation_exp\n");}


;
RExp1:           expression comp expression {printf("relation_exp -> expression comp expression\n");}
                 | TRUE {printf("relation_exp -> TRUE\n");}
                 | FALSE {printf("relation_exp -> FALSE\n");}
                 | L_PAREN bool_exp R_PAREN {printf("relation_exp -> L_PAREN bool_exp R_PAREN\n");}

;

comp:            EQ {printf("comp -> EQ\n");}
                 | NEQ {printf("comp -> NEQ\n");}
                 | LT {printf("comp -> LT\n");}
                 | GT {printf("comp -> GT\n");}
                 | LTE {printf("comp -> LTE\n");}
                 | GTE {printf("comp -> GTE\n");}
;

ident:      IDENT {printf("ident -> IDENT %s\n", $1);}
%%

		 
int main(int argc, char ** argv) {
    if (argc > 1) {
        yyin = fopen(argv[1], "r");
        if (yyin == NULL) {
            printf("syntax: %s filename", argv[0]);
			
        }
    }
    yyparse(); // more magical stuff
    return 0;
}

void yyerror(const char *msg) {
    printf("** ----- Line %d, position %d: %s\n", currLine, currPos, msg);
}