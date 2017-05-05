/* Lexer for org.gnome.UPnP.MediaContainer2 search query */

%option default never-interactive noyywrap noinput nounput case-insensitive

%{
#include "query-parser.h"

#include "query-definitions.h"

#include <stdbool.h>

#define MAX_STRING 1024
#define MAX_OP 4

char  buffer[MAX_STRING];
char  operand[MAX_OP];
char  current_property_type;
int   current_property;
char *current_escaped_quote;
     
extern char *os;

%}

/* for UTF-8 character definition, refer to
   http://stackoverflow.com/a/10253320
   for escapedQuote definition, refer to
   1.2.2 Strings Embedded in Other Strings 
   http://www.upnp.org/specs/av/UPnP-av-MediaRenderer-v2-Device.pdf */

/* UTF-8 */

ascii    [\x21-\x7E]
asciiEsc \x21[\x23-\x5B\][\x5D-\x7E]

u2a      [\xC2-\xDF][\x80-\xBF]
u2b      \xE0[\xA0-\xBF][\x80-\xBF]
u3a      [\xE1-\xEC\xEE\xEF][\x80-\xBF]{2}
u3b      \xED[\x80-\x9F][\x80-\xBF]
u4a      \xF0[\x90-\xBF][\x80-\xBF]{2}
u4b      [\xF1-\xF3][\x80-\xBF]{3}
u4c      \xF4[\x80-\x8F][\x80-\xBF]{2}

utf8Ext  {u2a}|{u2b}|{u3a}|{u3b}|{u4a}|{u4b}|{u4c}

utf8EscChar {asciiEsc}|{utf8Ext}

/* search query, refer to
   https://wiki.gnome.org/Projects/Rygel/MediaServer2Spec */

hTab     \x09
lineFeed \x0A
vTab     \x0B
formFeed \x0C
return   \x0D
space    \x20
dQuote   \x22

wChar {space}|{hTab}|{lineFeed}|{vTab}|{formFeed}|{return}

/* Exclusive start conditions */

%x escapedQuote

%%

{wChar}+       ;

\x2A           { return asterisk; }

true           { yylval.ival = 1; return boolVal; }
false          { yylval.ival = 0; return boolVal; }

exists         { return existsOp; }

contains       { return opContains; }
doesNotContain { return opDoesNotContain; }
derivedfrom    { return opDerivedfrom; }

=|!=|<|<=|>|>= { yylval.sval = strncpy(operand, yytext, MAX_OP); return relOp; }

and|or         { os += sprintf(os, " %s ", yytext); return logOp; }

Parent         { yylval.pval.type = 'o'; yylval.pval.name = PROPPARENT;        return property; }
Type           { yylval.pval.type = 's'; yylval.pval.name = PROPTYPE;          return property; }
Path           { yylval.pval.type = 'o'; yylval.pval.name = PROPPATH;          return property; }
DisplayName    { yylval.pval.type = 's'; yylval.pval.name = PROPDISPLAYNAME;   return property; }

URLs           { yylval.pval.type = 'a'; yylval.pval.name = PROPURLS;          return property; }
MIMEType       { yylval.pval.type = 's'; yylval.pval.name = PROPMIMETYPE;      return property; }
Size           { yylval.pval.type = 'x'; yylval.pval.name = PROPSIZE;          return property; }
Artist         { yylval.pval.type = 's'; yylval.pval.name = PROPARTIST;        return property; }
Album          { yylval.pval.type = 's'; yylval.pval.name = PROPALBUM;         return property; }
Date           { yylval.pval.type = 's'; yylval.pval.name = PROPDATE;          return property; }
Genre          { yylval.pval.type = 's'; yylval.pval.name = PROPGENRE;         return property; }
DLNAProfile    { yylval.pval.type = 's'; yylval.pval.name = PROPDLNAPROFILE;   return property; }
Duration       { yylval.pval.type = 'i'; yylval.pval.name = PROPDURATION;      return property; }
Bitrate        { yylval.pval.type = 'i'; yylval.pval.name = PROPBITRATE;       return property; }
SampleRate     { yylval.pval.type = 'i'; yylval.pval.name = PROPSAMPLERATE;    return property; }
BitsPerSample  { yylval.pval.type = 'i'; yylval.pval.name = PROPBITSPERSAMPLE; return property; }
Width          { yylval.pval.type = 'i'; yylval.pval.name = PROPWIDTH;         return property; }
Height         { yylval.pval.type = 'i'; yylval.pval.name = PROPHEIGHT;        return property; }
ColorDepth     { yylval.pval.type = 'i'; yylval.pval.name = PROPCOLORDEPTH;    return property; }
PixelWidth     { yylval.pval.type = 'i'; yylval.pval.name = PROPPIXELWIDTH;    return property; }
PixelHeight    { yylval.pval.type = 'i'; yylval.pval.name = PROPPIXELHEIGHT;   return property; }
Thumbnail      { yylval.pval.type = 'o'; yylval.pval.name = PROPTHUMBNAIL;     return property; }
AlbumArt       { yylval.pval.type = 'o'; yylval.pval.name = PROPALBUMART;      return property; }
TrackNumber    { yylval.pval.type = 'i'; yylval.pval.name = PROPTRACKNUMBER;   return property; }

{dQuote}       { current_escaped_quote = buffer; BEGIN(escapedQuote); }
<escapedQuote>{dQuote} { /* closing quote - all done */
   BEGIN(INITIAL);
   *current_escaped_quote = '\0';
   yylval.sval = buffer;
   return quotedVal; }
<escapedQuote>\\\\       { *current_escaped_quote++ = '\\'; }
<escapedQuote>\\{dQuote} { *current_escaped_quote++ = '"'; }
<escapedQuote>.          { *current_escaped_quote++ = yytext[0]; }

\(             { os += sprintf(os, "("); return openingParentheses; }
\)             { os += sprintf(os, ")"); return closingParentheses; }

[-+]?[0-9]+    { yylval.ival = atoi(yytext); return INT; }

.              { return UNRECOGNIZED; }

%%
