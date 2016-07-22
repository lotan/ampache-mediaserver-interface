%{
/*
ToDo:
- SQL compatible conversion -> as generic as possible?
- handle array of strings (URLs) (no specification available)

Changes to original specification/design descisions:
- disregard wChar entirely (on rules where wChar is not there where
  necessary, a syntax error will occur)
- number values are also accepted without quotes
- lexer is now case insensitive

Remarks:
- replaced filtered out properties with '0 = 1'
*/

#include "query-definitions.h"

#include <stdlib.h>
#include <stdio.h>

#define MAX_OUTPUT_STRING 1024

// stuff from flex that bison needs to know about:
extern void  yy_scan_string(const char *str);
extern int   yylex();
extern int   yyparse();
extern char *yytext;

void yyerror(const char *s);

int   parse_error;
char  output_string[MAX_OUTPUT_STRING];
char *os;

int   everything;
int   parse_filter;

%}

%union {
	int   ival;
	char *sval;
	struct {
		int  name;
		char type;
	} pval;
}

%token UNRECOGNIZED;

%token <ival> INT;

%token asterisk;

%token <ival> boolVal;

%token existsOp;

%token opContains;
%token opDoesNotContain;
%token opDerivedfrom;

%token <sval> relOp;

%left  logOp;

%token <pval> property;
     
%token <sval> quotedVal;

%token openingParentheses;
%token closingParentheses;

%%

searchExp:
     asterisk { everything = 1; }
	| relExp
	| searchExp logOp searchExp
	| openingParentheses searchExp closingParentheses
	;

relExp:
	  property relOp INT {
      if (FILTER[parse_filter][$1.name] == 1) {
         if ($1.name < PROPPARENT - 1) {
            os += sprintf(os, "%s %s %i", PROPERTIES[$1.name], $2, $3);
         }
      } else {
         os += sprintf(os, "0 = 1");
      } }
	| property relOp quotedVal {
      if (FILTER[parse_filter][$1.name] == 1) {
         os += sprintf(os, "%s %s \"%s\"", PROPERTIES[$1.name], $2, $3);
      } else {
         os += sprintf(os, "0 = 1");
      } }
	| property opContains quotedVal {
      if (FILTER[parse_filter][$1.name] == 1) {
         os += sprintf(os, "%s contains \"%s\"", PROPERTIES[$1.name], $3);
      } else {
         os += sprintf(os, "0 = 1");
      } }
	| property opDoesNotContain quotedVal {
      if (FILTER[parse_filter][$1.name] == 1) {
         os += sprintf(os, "%s doesNotContain \"%s\"", PROPERTIES[$1.name], $3);
      } else {
         os += sprintf(os, "0 = 1");
      } }
	| property opDerivedfrom quotedVal {
      if (FILTER[parse_filter][$1.name] == 1) {
         os += sprintf(os, "%s derivedfrom \"%s\"", PROPERTIES[$1.name], $3);
      } else {
         os += sprintf(os, "0 = 1");
      } }
	| property existsOp boolVal {
      if (FILTER[parse_filter][$1.name] == 1) {
         os += sprintf(os, "%s exists %i", PROPERTIES[$1.name], $3);
      } else {
         os += sprintf(os, "0 = 1");
      } }
	;

%%

void yyerror(const char *s) {
	parse_error = 1;
}

char *parse_mediaserver_query(const char *query, const int filter) {
	parse_error  = 0;
   everything   = 0;
   parse_filter = filter;
	os           = output_string;

	yy_scan_string(query);
	yyparse();

	if (parse_error == 1) {
		return NULL;
	} else if (everything == 1) {
      return "";
   } else {
		return output_string;
	}
}
