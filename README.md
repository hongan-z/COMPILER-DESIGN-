# COMPILER-DESIGN-Projct 
PhaseI
Suppose your lexical analyzer is in the executable named lexer. Then for the MINI-L program fibonacci.min, your lexical analyzer should be invoked as follows:

cat fibonacci.min | lexer

------------------------------------------------------------------------------------------------------function fibonacci;
beginparams
	k : integer;
endparams
beginlocals
endlocals
beginbody
	if (k <= 1) then return 1; endif;
	return fibonacci(k - 1) + fibonacci(k - 2);
endbody

function main;
beginparams
endparams
beginlocals
	n : integer;
	fib_n : integer;
endlocals
beginbody
	read n;
	fib_n := fibonacci(n);
	write fib_n;
endbody
------------------------------------------------------------------------------------------------------
output:
FUNCTION
IDENT fibonacci
SEMICOLON
BEGIN_PARAMS
IDENT k
COLON
INTEGER
SEMICOLON
END_PARAMS
BEGIN_LOCALS
END_LOCALS
BEGIN_BODY
IF
L_PAREN
IDENT k
LTE
NUMBER 1
R_PAREN
THEN
RETURN
NUMBER 1
SEMICOLON
ENDIF
SEMICOLON
RETURN
IDENT fibonacci
L_PAREN
IDENT k
SUB
NUMBER 1
R_PAREN
ADD
IDENT fibonacci
L_PAREN
IDENT k
SUB
NUMBER 2
R_PAREN
SEMICOLON
END_BODY
FUNCTION
IDENT main
SEMICOLON
BEGIN_PARAMS
END_PARAMS
BEGIN_LOCALS
IDENT n
COLON
INTEGER
SEMICOLON
IDENT fib_n
COLON
INTEGER
SEMICOLON
END_LOCALS
BEGIN_BODY
READ
IDENT n
SEMICOLON
IDENT fib_n
ASSIGN
IDENT fibonacci
L_PAREN
IDENT n
R_PAREN
SEMICOLON
WRITE
IDENT fib_n
SEMICOLON
END_BODY
---------------------------------------------------------------------------------------------------
The following tasks will need to be performed to complete this phase of the project.
Write the specification for a flex lexical analyzer for the MINI-L language. For this phase of the project, your lexical analyzer need only output the list of tokens identified from an inputted MINI-L program.
Example: write the flex specification in a file named mini_l.lex.
Run flex to generate the lexical analyzer for MINI-L using your specification.
Example: execute the command flex mini_l.lex. This will create a file called lex.yy.c in the current directory.
Compile your MINI-L lexical analyzer. This will require the -lfl flag for gcc.
Example: compile your lexical analyzer into the executable lexer with the following command: gcc -o lexer lex.yy.c -lfl. The program lexer should now be able to convert an inputted MINI-L program into the corresponding list of tokens.