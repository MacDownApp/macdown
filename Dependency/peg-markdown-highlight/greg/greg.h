/* Copyright (c) 2007 by Ian Piumarta
 * All rights reserved.
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the 'Software'),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, provided that the above copyright notice(s) and this
 * permission notice appear in all copies of the Software.  Acknowledgement
 * of the use of this Software in supporting documentation would be
 * appreciated but is not required.
 * 
 * THE SOFTWARE IS PROVIDED 'AS IS'.  USE ENTIRELY AT YOUR OWN RISK.
 * 
 * Last edited: 2007-05-15 10:32:05 by piumarta on emilia
 */

#include <stdio.h>

#define GREG_MAJOR      0
#define GREG_MINOR      4
#define GREG_LEVEL      3

enum { Unknown= 0, Rule, Variable, Name, Dot, Character, String, Class, Action, Predicate, Alternate, Sequence, PeekFor, PeekNot, Query, Star, Plus };

enum {
  RuleUsed      = 1<<0,
  RuleReached   = 1<<1,
};

typedef union Node Node;

struct Rule      { int type;  Node *next;   char *errblock;  char *name;  Node *variables;  Node *expression;  int id;  int flags;       };
struct Variable  { int type;  Node *next;   char *errblock;  char *name;  Node *value;  int offset;                                      };
struct Name      { int type;  Node *next;   char *errblock;  Node *rule;  Node *variable;                                                };
struct Dot       { int type;  Node *next;   char *errblock;                                                                              };
struct Character { int type;  Node *next;   char *errblock;  char *value;                                                                };
struct String    { int type;  Node *next;   char *errblock;  char *value;                                                                };
struct Class     { int type;  Node *next;   char *errblock;  unsigned char *value;                                                       };
struct Action    { int type;  Node *next;   char *errblock;  char *text;   Node *list;  char *name;  Node *rule;                         };
struct Predicate { int type;  Node *next;   char *errblock;  char *text;                                                                 };
struct Alternate { int type;  Node *next;   char *errblock;  Node *first;  Node *last;                                                   };
struct Sequence  { int type;  Node *next;   char *errblock;  Node *first;  Node *last;                                                   };
struct PeekFor   { int type;  Node *next;   char *errblock;  Node *element;                                                              };
struct PeekNot   { int type;  Node *next;   char *errblock;  Node *element;                                                              };
struct Query     { int type;  Node *next;   char *errblock;  Node *element;                                                              };
struct Star      { int type;  Node *next;   char *errblock;  Node *element;                                                              };
struct Plus      { int type;  Node *next;   char *errblock;  Node *element;                                                              };
struct Any       { int type;  Node *next;   char *errblock;                                                                              };

union Node
{
  int                   type;
  struct Rule           rule;
  struct Variable       variable;
  struct Name           name;
  struct Dot            dot;
  struct Character      character;
  struct String         string;
  struct Class          cclass;
  struct Action         action;
  struct Predicate      predicate;
  struct Alternate      alternate;
  struct Sequence       sequence;
  struct PeekFor        peekFor;
  struct PeekNot        peekNot;
  struct Query          query;
  struct Star           star;
  struct Plus           plus;
  struct Any            any;
};

extern Node *actions;
extern Node *rules;
extern Node *start;

extern int   ruleCount;

extern FILE *output;

extern Node *makeRule(char *name);
extern Node *findRule(char *name);
extern Node *beginRule(Node *rule);
extern void  Rule_setExpression(Node *rule, Node *expression);
extern Node *Rule_beToken(Node *rule);
extern Node *makeVariable(char *name);
extern Node *makeName(Node *rule);
extern Node *makeDot(void);
extern Node *makeCharacter(char *text);
extern Node *makeString(char *text);
extern Node *makeClass(char *text);
extern Node *makeAction(char *text);
extern Node *makePredicate(char *text);
extern Node *makeAlternate(Node *e);
extern Node *Alternate_append(Node *e, Node *f);
extern Node *makeSequence(Node *e);
extern Node *Sequence_append(Node *e, Node *f);
extern Node *makePeekFor(Node *e);
extern Node *makePeekNot(Node *e);
extern Node *makeQuery(Node *e);
extern Node *makeStar(Node *e);
extern Node *makePlus(Node *e);
extern Node *push(Node *node);
extern Node *top(void);
extern Node *pop(void);

extern void  Rule_compile_c_header(void);
extern void  Rule_compile_c(Node *node);

extern void  Node_print(Node *node);
extern void  Rule_print(Node *node);
