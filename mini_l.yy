
%{
%}

%skeleton "lalr1.cc"
%require "3.0.4"
%defines
%define api.token.constructor
%define api.value.type variant
%define parse.error verbose
%locations

%code requires
{
    #include <iostream>
    #include <list>
    #include <string>
    #include <functional>
    #include <vector>
    #include <stdlib.h>
    #include <stdio.h>
    #include <tuple>
    #include <utility>

    #ifndef FOO
    #define FOO

    #define debug false

    void debug_print(std::string msg);
    void debug_print_char(std::string msg, std::string c);
    void debug_print_int(std::string msg, int i);

    std::string concat(std::vector<std::string> strings, std::string prefix, std::string delim);

    enum IdentType {

        INTEGER,
        ARRAY,
        FUNCTION
    };

    void populateKeywords();

    bool isKeyword(std::string str);

    bool isInSymbolTable(std::string name);

    bool checkIdType(std::string id, IdentType type);

    std::string generateTempReg();
    std::string generateTempLabel();

    struct ExprStruct {

    public:
        std::string reg_name;
        std::vector < std::string > code;

        friend std::ostream& operator <<(std::ostream& out, const ExprStruct& printMe) {

            for (std::string thisLineOfCode : printMe.code)
                out << thisLineOfCode << std::endl;

            return out;
        }
    };

    struct StatementStruct {

    public:

        std::string begin_label;
        std::string end_label;
        std::vector < std::string > code;
    };

    std::ostream& operator <<(std::ostream& out, const std::vector< ExprStruct > & printMe);

    std::ostream& operator <<(std::ostream& out, const std::vector< std::string> & printMe);

    #endif // FOO

}



%code
{
    #include "my_compiler.tab.hh"
    #include <iostream>
    #include <sstream>
    #include <string>
    #include <map>
    #include <regex>
    #include <set>
    #include <algorithm>
    #include <climits>
    #include <unordered_set>
    #include <stack>

    //extern yy::location loc;

    yy::parser::symbol_type yylex();

    	/* define your symbol table, global variables,
    	 * list of keywords or any function you may need here */

    enum IdentType;

    std::map< std::string, IdentType > symbol_table;
    std::unordered_set < std::string > keywords;            // reserved keywords
    std::stack <std::string> loop_scope;

    bool errorOccurred = false;
    int paramCount = 0;


	/* end of your code */
}

%token END 0 "end of file";

/* specify tokens, type of non-terminals and terminals here */
%token FUNCTION BEGINPARAMS ENDPARAMS BEGINLOCALS ENDLOCALS BEGINBODY ENDBODY
%token INTEGER ARRAY OF IF THEN ENDIF ELSE
%token WHILE DO BEGINLOOP ENDLOOP CONTINUE FOR
%token READ WRITE AND OR NOT TRUE FALSE RETURN
%token ADD SUB MULT DIV MOD
%token EQ NEQ LT GT LTE GTE
%token SEMICOLON COLON COMMA L_PAREN R_PAREN L_SQUARE_BRACKET R_SQUARE_BRACKET ASSIGN
%token <std::string> IDENTIFIER
%token <int> NUMBER
%type  <std::vector<ExprStruct>> declaration_loop var_loop expression_loop
%type  <ExprStruct> program declaration var expression term mult_expr bool_expr relation_and_expr relation_expr

%type  <std::vector<StatementStruct>> statement_loop
%type  <StatementStruct> statement function

%type  <std::vector<std::string>> id_loop
%type  <std::string> mulop comp


%right ASSIGN
%left  OR
%left  AND
%right NOT
%left  LT GT LTE GTE EQ NEQ
%left  ADD SUB
%left  MULT DIV MOD
%left  L_SQUARE_BRACKET R_SQUARE_BRACKET
%left  L_PAREN R_PAREN
	/* end of token specifications */

%%

%start prog_start;

	/* define your grammars here use the same grammars
	 * you used in Phase 2 and modify their actions to generate codes
	 * assume that your grammars start with prog_start
	 */

prog_start:

    { populateKeywords(); } program {

        if (!errorOccurred)
            std::cout << $2;

        // Print error if there isn't a main function
        if (!checkIdType("main", IdentType::FUNCTION)) {

            yy::parser::error(@2, "No main function defined");
        }
    }
;

program:

    /*epsilon*/ %empty {
    }

    | program function {
        $$.code.insert($$.code.end(), $1.code.begin(), $1.code.end());
        $$.code.insert($$.code.end(), $2.code.begin(), $2.code.end());
    }
;

function:
    FUNCTION IDENTIFIER {

        std::string function_name = $2;
        symbol_table.insert( std::pair<std::string, IdentType>(function_name, IdentType::FUNCTION) );

        if (isKeyword(function_name)) {

            yy::parser::error(@2, "Function name \"" + function_name + "\" cannot be named the same as a keyword.");
        }

    } SEMICOLON
    BEGINPARAMS declaration_loop ENDPARAMS
    BEGINLOCALS declaration_loop ENDLOCALS
    BEGINBODY statement_loop ENDBODY {
        std::string function_name = $2;
        std::vector< ExprStruct > params = $6;
        std::vector< ExprStruct > locals = $9;
        std::vector< StatementStruct > body   = $12;

        $$.code.push_back("func " + function_name);

        for (ExprStruct this_expr_struct : params) {

            $$.code.insert($$.code.end(), this_expr_struct.code.begin(), this_expr_struct.code.end());
        }

        for (ExprStruct this_expr_struct : locals) {

            $$.code.insert($$.code.end(), this_expr_struct.code.begin(), this_expr_struct.code.end());
        }

        for (StatementStruct this_expr_struct : body) {

            $$.code.insert($$.code.end(), this_expr_struct.code.begin(), this_expr_struct.code.end());
        }

        $$.code.push_back("endfunc");
    }
;

declaration_loop:

    /*epsilon*/ %empty {
    }

	| declaration_loop declaration SEMICOLON {
        $$.insert($$.end(), $1.begin(), $1.end());
        $$.push_back($2);
    }
;

statement_loop:

    statement SEMICOLON {
        $$.push_back($1);
    }

	| statement_loop statement SEMICOLON {

        $$ = $1;
        $$.push_back($2);
    }
;

declaration:

    id_loop COLON INTEGER {

        for (std::string thisId : $1) {

            if (isInSymbolTable(thisId)) {
                yy::parser::error(@1, "Multiple definitions of variable \"" + thisId + "\"");
            }
            else {
                symbol_table.insert( std::pair<std::string, IdentType>(thisId, IdentType::INTEGER));

                ExprStruct expr_struct;
                expr_struct.code.push_back(". " + thisId);
                expr_struct.reg_name = thisId;

                $$.code.insert($$.code.end(), expr_struct.code.begin(), expr_struct.code.end());
            }
        }


    }

	| id_loop COLON ARRAY L_SQUARE_BRACKET NUMBER R_SQUARE_BRACKET OF INTEGER {

        for (std::string thisId : $1) {

            if (isInSymbolTable(thisId)) {
                yy::parser::error(@1, "Multiple definitions of variable \"" + thisId + "\"");
            }
            else {
                symbol_table.insert( std::pair<std::string, IdentType>(thisId, IdentType::INTEGER));

                ExprStruct expr_struct;
                expr_struct.code.push_back(".[] " + thisId + ", " + std::to_string($5));
                expr_struct.reg_name = thisId;

                $$.code.insert($$.code.end(), expr_struct.code.begin(), expr_struct.code.end());
            }

            if ($5 <= 0) {

                yy::parser::error(@5, "Array \"" + thisId + "\" must be declared with size greater than zero");
            }
        }
    }
;

id_loop:

    IDENTIFIER {

        debug_print("id_loop -> IDENTIFIER");
        $$.push_back($1);
    }

    | id_loop COMMA IDENTIFIER {

        debug_print("id_loop -> id_loop COMMA IDENTIFIER");

        for (std::string s : $1) {
            $$.push_back(s);
        }

        $$.push_back($3);
    }
;

statement:

    var ASSIGN expression {
        debug_print("statement -> var ASSIGN expression\n");

        $$.code.insert($$.code.end(), $3.code.begin(), $3.code.end());

        $$.code.push_back("= " + $1.reg_name + ", " + $3.reg_name);

    }

	| IF bool_expr THEN statement_loop ENDIF {

        debug_print("statement -> IF bool_expr THEN statement_loop ENDIF\n");

        $$.code.insert($$.code.end(), $2.code.begin(), $2.code.end());
        $$.begin_label = generateTempReg();
        $$.code.push_back(". " + $$.begin_label);

        std::string endif_label = generateTempLabel();

        std::string negation_reg = generateTempReg();
        $$.code.push_back(". " + negation_reg);
        $$.code.push_back("! " + negation_reg + ", " + $2.reg_name);

        $$.code.push_back("?:= " + endif_label + ", " + negation_reg);

        for (StatementStruct thisStatement : $4) {

            $$.code.insert($$.code.end(), thisStatement.code.begin(), thisStatement.code.end());
        }

        $$.code.push_back(": " + endif_label);


    }

	| IF bool_expr THEN statement_loop ELSE statement_loop ENDIF {

        $$.code.insert($$.code.end(), $2.code.begin(), $2.code.end());

        $$.begin_label = generateTempLabel();   // else
        $$.end_label = generateTempLabel();     // end

        std::string negation_reg = generateTempReg();
        $$.code.push_back(". " + negation_reg);
        $$.code.push_back("! " + negation_reg + ", " + $2.reg_name);

        $$.code.push_back("?:= " + $$.begin_label + ", " + negation_reg);

        for (StatementStruct thisStatement : $4) {

            $$.code.insert($$.code.end(), thisStatement.code.begin(), thisStatement.code.end());
        }

        $$.code.push_back(":= " + $$.end_label /*+ " ; end of if, jump to end"*/);

        $$.code.push_back(": " + $$.begin_label /*+ " ; else label"*/);

        for (StatementStruct thisStatement : $6) {

            $$.code.insert($$.code.end(), thisStatement.code.begin(), thisStatement.code.end());
        }

        $$.code.push_back(": " + $$.end_label /*+ " ; endif label"*/);

    }

	| WHILE bool_expr BEGINLOOP {loop_scope.push(generateTempLabel());} statement_loop ENDLOOP {

        StatementStruct css;
        assert(!loop_scope.empty());
        css.begin_label = loop_scope.top();
        std::string middle_label = generateTempLabel();
        css.end_label = generateTempLabel();


        $$.code.push_back(": " + css.begin_label);

        $$.code.insert($$.code.end(), $2.code.begin(), $2.code.end()); // bool_expr code

        $$.code.push_back("?:= " + middle_label + ", " + $2.reg_name);
        $$.code.push_back(":= " + css.end_label);
        $$.code.push_back(": " + middle_label);



        for (StatementStruct thisStatement : $5) {

            $$.code.insert($$.code.end(), thisStatement.code.begin(), thisStatement.code.end());
        }

        $$.code.push_back(":= " + css.begin_label);
        $$.code.push_back(": " + css.end_label);


        $$.begin_label = css.begin_label;
        $$.end_label = css.end_label;

        loop_scope.pop();

    }

	| DO BEGINLOOP { loop_scope.push(generateTempLabel()); } statement_loop ENDLOOP WHILE bool_expr {

        StatementStruct ss;

        assert(!loop_scope.empty());
        ss.end_label = loop_scope.top();
        ss.begin_label = generateTempLabel();

        $$.code.push_back(": " + ss.begin_label);

        for (StatementStruct thisStatement : $4) {

            $$.code.insert($$.code.end(), thisStatement.code.begin(), thisStatement.code.end());
        }

        $$.code.push_back(": " + ss.end_label);

        $$.code.insert($$.code.end(), $7.code.begin(), $7.code.end());

        $$.code.push_back("?:= " + ss.begin_label + ", " + $7.reg_name);

        loop_scope.pop();

    }
	| FOR var ASSIGN NUMBER SEMICOLON bool_expr SEMICOLON var ASSIGN expression BEGINLOOP {loop_scope.push(generateTempLabel());}statement_loop ENDLOOP
							{
								$$.code.push_back("= " + $2.reg_name + ", " + std::to_string($4));

								StatementStruct css;
        				assert(!loop_scope.empty());
        				css.begin_label = loop_scope.top();
        				std::string middle_label = generateTempLabel();
        				css.end_label = generateTempLabel();

								$$.code.push_back(": " + css.begin_label);

								$$.code.insert($$.code.end(), $6.code.begin(), $6.code.end());

								$$.code.insert($$.code.end(), $10.code.begin(), $10.code.end());
								$$.code.push_back("= " + $8.reg_name + ", " + $10.reg_name);

								$$.code.push_back("?:= " + middle_label + ", " + $6.reg_name);
        				$$.code.push_back(":= " + css.end_label);
        				$$.code.push_back(": " + middle_label);



        				for (StatementStruct thisStatement : $13) {

            				$$.code.insert($$.code.end(), thisStatement.code.begin(), thisStatement.code.end());
        				}

        				$$.code.push_back(":= " + css.begin_label);
        				$$.code.push_back(": " + css.end_label);


        				$$.begin_label = css.begin_label;
				        $$.end_label = css.end_label;

				        loop_scope.pop();

							}

	| READ var_loop {

        debug_print("statement -> READ var_loop\n");


        for (ExprStruct this_expr_struct : $2) {
           
            $$.code.push_back(".< " + this_expr_struct.reg_name);
        }
    }

	| WRITE var_loop {

        debug_print("statement -> WRITE var_loop\n");
 
        for (ExprStruct this_expr_struct : $2) {
            //$$.code.insert($$.code.end(), this_expr_struct.code.begin(), this_expr_struct.code.end());
            // $$.code.push_back(".> " + this_expr_struct.original_name);
            $$.code.push_back(".> " + this_expr_struct.reg_name);
        }
    }

    | CONTINUE {

        debug_print("statement -> CONTINUE\n");

        if (loop_scope.empty()) {

            yy::parser::error(@1, "\'continue\' keyword forbidden outside loops");
        }

        else {

            std::string jump_here = loop_scope.top();
            $$.code.push_back(":= " + jump_here);
        }
    }

    | RETURN expression {

        debug_print("statement -> RETURN expression\n");

        $$.code.insert($$.code.end(), $2.code.begin(), $2.code.end());
        // $$.reg_name = $2.reg_name;
        $$.begin_label = $2.reg_name;
        $$.code.push_back("ret " + $2.reg_name);

    }
;

var_loop:

    var {

        debug_print("var_loop -> var\n");
        $$.push_back($1);

    }

	| var_loop COMMA var {

        debug_print("var_loop -> var_loop COMMA var\n");
        $$.insert($$.end(), $1.begin(), $1.end());
        $$.push_back($3);
    }
;

bool_expr:
    relation_and_expr {
        debug_print("bool_expr -> relation_and_expr\n");
        $$ = $1;

    }
    | bool_expr OR relation_and_expr {
        debug_print("bool_expr -> bool_expr OR relation_and_expr\n");

    }
;

relation_and_expr:
    relation_expr {
        debug_print("relation_and_expr -> relation_expr\n");
        $$ = $1;

    }
    | relation_and_expr AND relation_expr {
        debug_print("relation_and_expr -> relation_and_expr AND relation_expr\n");

    }
;

relation_expr:

    expression comp expression {

        debug_print("relation_expr -> expression comp expression\n");

        $$.code.insert($$.code.end(), $1.code.begin(), $1.code.end());
        $$.code.insert($$.code.end(), $3.code.begin(), $3.code.end());

        $$.reg_name = generateTempReg();
        $$.code.push_back(". " + $$.reg_name);

        $$.code.push_back($2 + " " + $$.reg_name + ", " + $1.reg_name + ", " + $3.reg_name);

    }

	| NOT expression comp expression {

        std::cout << "In relation_expr -> NOT expression comp expression" << std::endl;

        debug_print("relation_expr -> NOT expression comp expression\n");

        $$.code.insert($$.code.end(), $2.code.begin(), $2.code.end());
        $$.code.insert($$.code.end(), $4.code.begin(), $4.code.end());

        $$.reg_name = generateTempReg();
        $$.code.push_back(". " + $$.reg_name);

        $$.code.push_back($3 + " " + $$.reg_name + ", " + $2.reg_name + ", " + $4.reg_name);

        $$.code.push_back("! " + $$.reg_name + ", " + $$.reg_name);
    }

	| TRUE {

        debug_print("relation_expr -> TRUE\n");

        $$.reg_name = generateTempReg();
        $$.code.push_back(". " + $$.reg_name);

        $$.code.push_back("= " + $$.reg_name + ", 1");
    }
	| NOT TRUE { debug_print("relation_expr -> NOT TRUE\n");

        $$.reg_name = generateTempReg();
        $$.code.push_back(". " + $$.reg_name);
        $$.code.push_back("= " + $$.reg_name + ", 0");
    }
	| FALSE {
        debug_print("relation_expr -> FALSE\n");

        $$.reg_name = generateTempReg();
        $$.code.push_back(". " + $$.reg_name);
        $$.code.push_back("= " + $$.reg_name + ", 0");
    }
	| NOT FALSE {
        debug_print("relation_expr -> NOT FALSE\n");

        $$.reg_name = generateTempReg();
        $$.code.push_back(". " + $$.reg_name);

        $$.code.push_back("= " + $$.reg_name + ", 1");
    }
	| L_PAREN bool_expr R_PAREN {
        debug_print("relation_expr -> L_PAREN bool_expr R_PAREN\n");

        $$.code.insert($$.code.end(), $2.code.begin(), $2.code.end());

        $$.reg_name = generateTempReg();
        $$.code.push_back(". " + $$.reg_name);
        $$.code.push_back("= " + $$.reg_name + ", " + $2.reg_name);
    }
;

comp:
    EQ { $$  = "=="; }
	| NEQ { $$  = "!="; }
	| LT { $$  = "<"; }
	| GT { $$  = ">"; }
	| LTE { $$  = "<="; }
	| GTE { $$  = ">="; }
;

expression:
    mult_expr { debug_print("expression -> mult_expr\n");
        $$ = $1;
        
    }
    | expression ADD mult_expr {

        debug_print("expression -> expression ADD mult_expr\n");

        $$ = $1;
        $$.reg_name = generateTempReg();
        $$.code.insert($$.code.end(), $3.code.begin(), $3.code.end());
        $$.code.push_back(". " + $$.reg_name);
        $$.code.push_back("+ " + $$.reg_name + ", " + $1.reg_name + ", " + $3.reg_name);


    }
    | expression SUB mult_expr {

        debug_print("expression -> expression SUB mult_expr\n");

        $$ = $1;
        $$.reg_name = generateTempReg();
        $$.code.insert($$.code.end(), $3.code.begin(), $3.code.end());
        $$.code.push_back(". " + $$.reg_name);
        $$.code.push_back("- " + $$.reg_name + ", " + $1.reg_name + ", " + $3.reg_name);
    }
;

mult_expr:

    term {
        debug_print("mult_expr -> term\n");
        $$ = $1;
    }

    | mult_expr mulop term {
        debug_print_char("mult_expr -> mult_expr %s term\n", $2);
        $$.reg_name = generateTempReg();
        $$.code.insert($$.code.end(), $1.code.begin(), $1.code.end());
        $$.code.insert($$.code.end(), $3.code.begin(), $3.code.end());
        $$.code.push_back(". " + $$.reg_name);
        $$.code.push_back($2 + " " + $$.reg_name + ", " + $1.reg_name + ", " + $3.reg_name);

    }
;

mulop:
    MULT { $$ = "*"; }
	| DIV  { $$ = "/"; }
	| MOD { $$ = "%"; }
;

term:

    var {

        debug_print("term -> var\n");
        $$ = $1;
        $$.reg_name = generateTempReg();
        $$.code.push_back(". " + $$.reg_name);
        $$.code.push_back("= " + $$.reg_name + ", " + $1.reg_name);

    }
	| SUB var {

        debug_print("term -> SUB var\n");

        $$ = $2;

        std::string twoTemp = generateTempReg();
        $$.code.push_back(". " + twoTemp);
        $$.code.push_back("= " + twoTemp + ", " + "2");

        std::string doubleTemp = generateTempReg();
        $$.code.push_back(". " + doubleTemp);
        $$.code.push_back("= " + doubleTemp + ", " + $2.reg_name);

        // Right now the var is in doubleTemp,
        // and 2 is in twoTemp

        // doubleTemp *= 2
        $$.code.push_back("* " + doubleTemp + ", " + doubleTemp + ", " + twoTemp);

        // Give $$ its own copy of the original var
        $$.reg_name = generateTempReg();
        $$.code.push_back(". " + $$.reg_name);
        $$.code.push_back("= " + $$.reg_name + ", " + $2.reg_name);

        // Now, do $$ -= doubleTemp
        $$.code.push_back("- " + $$.reg_name + ", " + $$.reg_name + ", " + doubleTemp);
    }
	| NUMBER {

        debug_print_int("term -> NUMBER %d\n", $1);

        //ExprStruct es;
        $$.reg_name = generateTempReg();
        $$.code.push_back(". " + $$.reg_name);
        $$.code.push_back("= " + $$.reg_name + ", " + std::to_string($1));
    }

	| SUB NUMBER {
        debug_print_int("term -> SUB NUMBER %d\n", $2);

        ExprStruct number_es;

        // Give number_es.reg_name a register and declare it
        number_es.reg_name = generateTempReg();
        $$.code.push_back(". " + number_es.reg_name);
        $$.code.push_back("= " + number_es.reg_name + ", " + std::to_string($2));

        // Put the result for 0 - number_es.reg_name into $$
        $$.reg_name = generateTempReg();
        $$.code.push_back(". " + $$.reg_name);
        $$.code.push_back("- " + $$.reg_name + ", 0, " + number_es.reg_name);

    }
	| L_PAREN expression R_PAREN {

        debug_print("term -> L_PAREN expression R_PAREN\n");

        $$.code.insert($$.code.end(), $2.code.begin(), $2.code.end());

        $$.reg_name = generateTempReg();
        $$.code.push_back(". " + $$.reg_name);
        $$.code.push_back("= " + $$.reg_name + ", " + $2.reg_name);

    }

	| SUB L_PAREN expression R_PAREN {

        debug_print("term -> SUB L_PAREN expression R_PAREN\n");

        $$.code.insert($$.code.end(), $3.code.begin(), $3.code.end());

        $$.reg_name = generateTempReg();
        $$.code.push_back(". " + $$.reg_name);
        $$.code.push_back("= " + $$.reg_name + ", " + $3.reg_name);
        $$.code.push_back("- " + $$.reg_name + ", 0, " + $$.reg_name);

    }
	| IDENTIFIER L_PAREN R_PAREN {

        debug_print_char("term -> IDENTIFIER %s L_PAREN R_PAREN\n", $1);

        if (!isInSymbolTable($1)) {

            yy::parser::error(@1, "Function \"" + $1 + "\" has not been declared in the current context");
        }

        $$.reg_name = generateTempReg();
        $$.code.push_back(". " + $$.reg_name);
        $$.code.push_back("call " + $1 + ", " + $$.reg_name);
    }

	| IDENTIFIER L_PAREN expression_loop R_PAREN {

        debug_print_char("term -> IDENTIFIER %s L_PAREN expression_loop R_PAREN\n", $1);

        if (!isInSymbolTable($1)) {

            yy::parser::error(@1, "Function \"" + $1 + "\" has not been declared in the current context");
        }
        if (!checkIdType($1, IdentType::FUNCTION)) {

            yy::parser::error(@1, "Attempted to call non-function \"" + $1 + "\"");
        }

        for (ExprStruct this_expr_struct : $3) {

            $$.code.insert($$.code.end(), this_expr_struct.code.begin(), this_expr_struct.code.end());
            $$.code.push_back("param " + this_expr_struct.reg_name);
        }

        $$.reg_name = generateTempReg();
        $$.code.push_back(". " + $$.reg_name);
        $$.code.push_back("call " + $1 + ", " + $$.reg_name);

        paramCount = 0;

    }
;

expression_loop:

    expression {

        debug_print("expression_loop -> expression");

        $1.reg_name = generateTempReg();
        $1.code.push_back(". " + $1.reg_name);
        // $1.code.push_back("= " + $1.reg_name + ", $" + paramCount);

        $$.push_back($1);

        paramCount++;
    }

    | expression_loop COMMA expression {

        debug_print("expression_loop -> expression_loop COMMA expression");

        $$ = $1;

        $$.push_back($3);
    }
;

var:

    IDENTIFIER {

        debug_print_char("var -> IDENTIFIER %s\n", $1);

        if (!isInSymbolTable($1)) {

            yy::parser::error(@1, "Attempted to use undeclared variable \"" + $1 + "\".");
        }

        else if (checkIdType($1, IdentType::ARRAY)) {

            yy::parser::error(@1, "Attempted to use array variable \"" + $1 + "\" as a non-array variable.");
        }

        ExprStruct es;
        es.reg_name = $1;
        // es.code.push_back(". " + $1);

        $$ = es;
    }

	| IDENTIFIER L_SQUARE_BRACKET expression R_SQUARE_BRACKET {

        debug_print_char("var -> IDENTIFIER %s L_SQUARE_BRACKET expression R_SQUARE_BRACKET\n", $1);

        // $$ = ".[] " + $1 + ", " + $3;
        ExprStruct es;
        // es.original_name = $1;
        es.code.push_back(".[] " + $1 + ", " + $3.reg_name);
        es.reg_name = generateTempReg();

        $$ = es;
    }
;


// going_into_loop: %empty { currentlyInLoop = true; }
// returning_from_loop: %empty { currentlyInLoop = false; }

%%

int main(int argc, char *argv[])
{
	yy::parser p;
	return p.parse();
}


void yy::parser::error(const yy::location& l, const std::string& m)
{
	std::cerr << "Error at location " << l << ": " << m << std::endl;
    errorOccurred = true;
}

void debug_print(std::string msg) {

    if (debug) printf("%s", msg.c_str());
}

void debug_print_char(std::string msg, std::string c) {

    if (debug) printf(msg.c_str(), c.c_str());
}

void debug_print_int(std::string msg, int i) {

    if (debug) printf(msg.c_str(), i);
}

std::string concat(std::vector<std::string> strings, std::string prefix, std::string delim) {

    std::string str = "";

    for (std::string this_str : strings)
        str += prefix + this_str + delim;

    return str;

}

// int Ident::static_id = 0;

bool isKeyword(std::string name) {
    return keywords.find(name) != keywords.end();
}

bool isInSymbolTable(std::string name) {

    return symbol_table.find(name) != symbol_table.end();
}

bool checkIdType(std::string id, IdentType type) {

    if (!isInSymbolTable(id)) return false;

    return type == symbol_table.at(id);
}

std::ostream& operator <<(std::ostream& out, const std::vector< ExprStruct > & printMe) {

    for (ExprStruct thisExpr : printMe) {

        out << thisExpr << std::endl;
    }

    return out;
}


std::ostream& operator <<(std::ostream& out, const std::vector< std::string> & printMe) {

    for (std::string thisStr : printMe) {

        out << thisStr << std::endl;
    }

    return out;
}

std::string generateTempReg() {

    static int i = 0;

    return "__temp__" + std::to_string(i++);
}

std::string generateTempLabel() {

    static int i = 0;

    return "__label__" + std::to_string(i++);
}

void populateKeywords() {

    keywords.insert("function");
    keywords.insert("beginparams");
    keywords.insert("endparams");
    keywords.insert("beginlocals");
    keywords.insert("endlocals");
    keywords.insert("beginbody");
    keywords.insert("endbody");
    keywords.insert("integer");
    keywords.insert("array");
    keywords.insert("of");
    keywords.insert("if");
    keywords.insert("then");
    keywords.insert("endif");
    keywords.insert("else");
    keywords.insert("while");
    keywords.insert("do");
	keywords.insert("for");
    keywords.insert("beginloop");
    keywords.insert("endloop");
    keywords.insert("continue");
    keywords.insert("read");
    keywords.insert("write");
    keywords.insert("and");
    keywords.insert("or");
    keywords.insert("not");
    keywords.insert("true");
    keywords.insert("false");
    keywords.insert("return");
}

