# LE Grammar for LE Grammars
# 
# Copyright (c) 2007 by Ian Piumarta
# All rights reserved.
# 
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the 'Software'),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, provided that the above copyright notice(s) and this
# permission notice appear in all copies of the Software.  Acknowledgement
# of the use of this Software in supporting documentation would be
# appreciated but is not required.
# 
# THE SOFTWARE IS PROVIDED 'AS IS'.  USE ENTIRELY AT YOUR OWN RISK.
# 
# Last edited: 2007-09-13 08:12:17 by piumarta on emilia.local

%{
# include "greg.h"

# include <stdio.h>
# include <stdlib.h>
# include <unistd.h>
# include <string.h>
# include <libgen.h>
# include <assert.h>

  typedef struct Header Header;

  struct Header {
    char   *text;
    Header *next;
  };

  FILE *input= 0;

  int   verboseFlag= 0;

  static int	 lineNumber= 0;
  static char	*fileName= 0;
  static char	*trailer= 0;
  static Header	*headers= 0;

  void makeHeader(char *text);
  void makeTrailer(char *text);

  void yyerror(struct _GREG *, char *message);

# define YY_INPUT(buf, result, max)		\
  {						\
    int c= getc(input);				\
    if ('\n' == c || '\r' == c) ++lineNumber;	\
    result= (EOF == c) ? 0 : (*(buf)= c, 1);	\
  }

# define YY_LOCAL(T)	static T
# define YY_RULE(T)	static T
%}

# Hierarchical syntax

grammar=	- ( declaration | definition )+ trailer? end-of-file

declaration=	'%{' < ( !'%}' . )* > RPERCENT		{ makeHeader(yytext); }						#{YYACCEPT}

trailer=	'%%' < .* >				{ makeTrailer(yytext); }					#{YYACCEPT}

definition=	identifier 				{ if (push(beginRule(findRule(yytext)))->rule.expression)
							    fprintf(stderr, "rule '%s' redefined\n", yytext); }
			EQUAL expression		{ Node *e= pop();  Rule_setExpression(pop(), e); }
			SEMICOLON?											#{YYACCEPT}

expression=	sequence (BAR sequence			{ Node *f= pop();  push(Alternate_append(pop(), f)); }
			    )*

sequence=	prefix (prefix				{ Node *f= pop();  push(Sequence_append(pop(), f)); }
			  )*

prefix=		AND action				{ push(makePredicate(yytext)); }
|		AND suffix				{ push(makePeekFor(pop())); }
|		NOT suffix				{ push(makePeekNot(pop())); }
|		    suffix

suffix=		primary (QUESTION			{ push(makeQuery(pop())); }
                        | STAR			        { push(makeStar (pop())); }
			| PLUS			        { push(makePlus (pop())); }
			)?

primary=	(
                identifier				{ push(makeVariable(yytext)); }
			COLON identifier !EQUAL		{ Node *name= makeName(findRule(yytext));  name->name.variable= pop();  push(name); }
|		identifier !EQUAL			{ push(makeName(findRule(yytext))); }
|		OPEN expression CLOSE
|		literal					{ push(makeString(yytext)); }
|		class					{ push(makeClass(yytext)); }
|		DOT					{ push(makeDot()); }
|		action					{ push(makeAction(yytext)); }
|		BEGIN					{ push(makePredicate("YY_BEGIN")); }
|		END					{ push(makePredicate("YY_END")); }
                ) (errblock { Node *node = pop(); ((struct Any *) node)->errblock = strdup(yytext); push(node); })?

# Lexical syntax

identifier=	< [-a-zA-Z_][-a-zA-Z_0-9]* > -

literal=	['] < ( !['] char )* > ['] -
|		["] < ( !["] char )* > ["] -

class=		'[' < ( !']' range )* > ']' -

range=		char '-' char | char

char=		'\\' [abefnrtv'"\[\]\\]
|		'\\' [0-3][0-7][0-7]
|		'\\' [0-7][0-7]?
|		!'\\' .


errblock=       '~{' < braces* > '}' -
action=		'{' < braces* > '}' -

braces=		'{' (!'}' .)* '}'
|		!'}' .

EQUAL=		'=' -
COLON=		':' -
SEMICOLON=	';' -
BAR=		'|' -
AND=		'&' -
NOT=		'!' -
QUESTION=	'?' -
STAR=		'*' -
PLUS=		'+' -
OPEN=		'(' -
CLOSE=		')' -
DOT=		'.' -
BEGIN=		'<' -
END=		'>' -
RPERCENT=	'%}' -

-=		(space | comment)*
space=		' ' | '\t' | end-of-line
comment=	'#' (!end-of-line .)* end-of-line
end-of-line=	'\r\n' | '\n' | '\r'
end-of-file=	!.

%%

void yyerror(struct _GREG *G, char *message)
{
  fprintf(stderr, "%s:%d: %s", fileName, lineNumber, message);
  if (G->text[0]) fprintf(stderr, " near token '%s'", G->text);
  if (G->pos < G->limit || !feof(input))
    {
      G->buf[G->limit]= '\0';
      fprintf(stderr, " before text \"");
      while (G->pos < G->limit)
	{
	  if ('\n' == G->buf[G->pos] || '\r' == G->buf[G->pos]) break;
	  fputc(G->buf[G->pos++], stderr);
	}
      if (G->pos == G->limit)
	{
	  int c;
	  while (EOF != (c= fgetc(input)) && '\n' != c && '\r' != c)
	    fputc(c, stderr);
	}
      fputc('\"', stderr);
    }
  fprintf(stderr, "\n");
  exit(1);
}

void makeHeader(char *text)
{
  Header *header= (Header *)malloc(sizeof(Header));
  header->text= strdup(text);
  header->next= headers;
  headers= header;
}

void makeTrailer(char *text)
{
  trailer= strdup(text);
}

static void version(char *name)
{
  printf("%s version %d.%d.%d\n", name, GREG_MAJOR, GREG_MINOR, GREG_LEVEL);
}

static void usage(char *name)
{
  version(name);
  fprintf(stderr, "usage: %s [<option>...] [<file>...]\n", name);
  fprintf(stderr, "where <option> can be\n");
  fprintf(stderr, "  -h          print this help information\n");
  fprintf(stderr, "  -o <ofile>  write output to <ofile>\n");
  fprintf(stderr, "  -v          be verbose\n");
  fprintf(stderr, "  -V          print version number and exit\n");
  fprintf(stderr, "if no <file> is given, input is read from stdin\n");
  fprintf(stderr, "if no <ofile> is given, output is written to stdout\n");
  exit(1);
}

int main(int argc, char **argv)
{
  GREG *G;
  Node *n;
  int   c;

  output= stdout;
  input= stdin;
  lineNumber= 1;
  fileName= "<stdin>";

  while (-1 != (c= getopt(argc, argv, "Vho:v")))
    {
      switch (c)
	{
	case 'V':
	  version(basename(argv[0]));
	  exit(0);

	case 'h':
	  usage(basename(argv[0]));
	  break;

	case 'o':
	  if (!(output= fopen(optarg, "w")))
	    {
	      perror(optarg);
	      exit(1);
	    }
	  break;

	case 'v':
	  verboseFlag= 1;
	  break;

	default:
	  fprintf(stderr, "for usage try: %s -h\n", argv[0]);
	  exit(1);
	}
    }
  argc -= optind;
  argv += optind;

  G = yyparse_new(NULL);
  if (argc)
    {
      for (;  argc;  --argc, ++argv)
	{
	  if (!strcmp(*argv, "-"))
	    {
	      input= stdin;
	      fileName= "<stdin>";
	    }
	  else
	    {
	      if (!(input= fopen(*argv, "r")))
		{
		  perror(*argv);
		  exit(1);
		}
	      fileName= *argv;
	    }
	  lineNumber= 1;
	  if (!yyparse(G))
	    yyerror(G, "syntax error");
	  if (input != stdin)
	    fclose(input);
	}
    }
  else
    if (!yyparse(G))
      yyerror(G, "syntax error");
  yyparse_free(G);

  if (verboseFlag)
    for (n= rules;  n;  n= n->any.next)
      Rule_print(n);

  Rule_compile_c_header();

  for (; headers;  headers= headers->next)
    fprintf(output, "%s\n", headers->text);

  if (rules)
    Rule_compile_c(rules);

  if (trailer)
    fprintf(output, "%s\n", trailer);

  return 0;
}
