#ifndef lint
static char yysccsid[] = "@(#)yaccpar	1.9 (Berkeley) 02/21/93";
#endif
#define YYBYACC 1
#define YYMAJOR 1
#define YYMINOR 9
#define yyclearin (yychar=(-1))
#define yyerrok (yyerrflag=0)
#define YYRECOVERING (yyerrflag!=0)
#define YYPREFIX "yy"
#line 2 "as6809.y"

/*
HEADER: 	;
TITLE: 		Frankenstein Cross Assemblers;
VERSION: 	2.0;
DESCRIPTION: "	Reconfigurable Cross-assembler producing Intel (TM)
		Hex format object records.  ";
KEYWORDS: 	cross-assemblers, 1805, 2650, 6301, 6502, 6805, 6809, 
		6811, tms7000, 8048, 8051, 8096, z8, z80;
SYSTEM: 	UNIX, MS-Dos ;
FILENAME: 	as6809.y;
WARNINGS: 	"This software is in the public domain.  
		Any prior copyright claims are relinquished.  

		This software is distributed with no warranty whatever.  
		The author takes no responsibility for the consequences 
		of its use.

		Yacc (or Bison) required to compile."  ;
SEE-ALSO: 	as6809.doc,frasmain.c;	
AUTHORS: 	Mark Zenier;
COMPILERS: 	Microport Sys V/AT, ATT Yacc, Turbo C V1.5, Bison (CUG disk 285)
		(previous versions Xenix, Unisoft 68000 Version 7, Sun 3);
*/
/* 6809 instruction generation file */
/* November 17, 1990 */

/*
	description	frame work parser description for framework cross
			assemblers
	history		February 2, 1988
			September 11, 1990 - merge table definition
			September 12, 1990 - short file names
			September 14, 1990 - short variable names
			September 17, 1990 - use yylex as external
*/
#include <stdio.h>
#include "frasmdat.h"
#include "fragcon.h"

#define yylex lexintercept

	/* select criteria for ST_EXP  0000.0000.0000.00xx */
#define	ADDR	0x3
#define	DIRECT	0x1
#define	EXTENDED	0x2
#define ST_INH 0x1
#define ST_IMM 0x2
#define ST_EXP 0x4
#define ST_IND 0x8
#define ST_PCR 0x10
#define ST_IPCR 0x20
#define ST_IEXPR 0x40
#define ST_SPSH 0x1
#define ST_UPSH 0x1
#define ST_TFR 0x1
	
	static char	genbdef[] = "[1=];";
	static char	genwdef[] = "[1=]x"; /* x for normal, y for byte rev */
	char ignosyn[] = "[Xinvalid syntax for instruction";
	char ignosel[] = "[Xinvalid operands";
#define	IDM000	0
#define	IDM100	1
#define	IDM101	2
#define	IDM102	3
#define	IDM103	4
#define	IDM104	5
#define	IDM105	6
#define	IDM106	7
#define	IDM108	8
#define	IDM109	9
#define	IDM10B	10
#define	IDM111	11
#define	IDM113	12
#define	IDM114	13
#define	IDM115	14
#define	IDM116	15
#define	IDM118	16
#define	IDM119	17
#define	IDM11B	18
	char *(indexgen [] [4]) = {
/*IDM000;*/ { "[1=].5R.00|;", "[1=].5R.20|;", "[1=].5R.40|;", "[1=].5R.60|;"},
/*IDM100;*/ { "80;", "a0;", "c0;", "e0;" },
/*IDM101;*/ { "81;", "a1;", "c1;", "e1;" },
/*IDM102;*/ { "82;", "a2;", "c2;", "e2;" },
/*IDM103;*/ { "83;", "a3;", "c3;", "e3;" },
/*IDM104;*/ { "84;", "a4;", "c4;", "e4;" },
/*IDM105;*/ { "85;", "a5;", "c5;", "e5;" },
/*IDM106;*/ { "86;", "a6;", "c6;", "e6;" },
/*IDM108;*/ { "88;[1=]r", "a8;[1=]r", "c8;[1=]r", "e8;[1=]r" },
/*IDM109;*/ { "89;[1=]x", "a9;[1=]x", "c9;[1=]x", "e9;[1=]x" },
/*IDM10B;*/ { "8B;", "aB;", "cB;", "eB;" },
/*IDM111;*/ { "91;", "B1;", "D1;", "F1;" },
/*IDM113;*/ { "93;", "B3;", "D3;", "F3;" },
/*IDM114;*/ { "94;", "B4;", "D4;", "F4;" },
/*IDM115;*/ { "95;", "B5;", "D5;", "F5;" },
/*IDM116;*/ { "96;", "B6;", "D6;", "F6;" },
/*IDM118;*/ { "98;[1=]r", "b8;[1=]r", "d8;[1=]r", "f8;[1=]r" },
/*IDM119;*/ { "99;[1=]x", "b9;[1=]x", "d9;[1=]x", "f9;[1=]x" },
/*IDM11B;*/ { "9B;", "BB;", "DB;", "FB;" }
		};

#define	PCRNEG8M	-126
#define	PCRPLUS8M	129
#define	PCR8STR		"8c;[1=].Q.1+-r"
#define	IPCR8STR	"9c;[1=].Q.1+-r"
#define	PCR16STR	"8d;[1=].Q.2+-.ffff&x"
#define	IPCR16STR	"9d;[1=].Q.2+-.ffff&x"
#define	IEXPSTR		"9f;[1=]x"
#define	TFRD	0
#define	TFRX	1
#define	TFRY	2
#define	TFRU	3
#define	TFRS	4
#define	TFRPC	5
#define	TFRA	0x8
#define	TFRB	0x9
#define	TFRCC	0xa
#define	TFRDP	0xb
#define	TFR8BIT	0x8
#define	REGBUSTK 0x100
#define	REGBSSTK 0x200
#define	PPOSTCC	0x01
#define	PPOSTA	0x02
#define	PPOSTB	0x04
#define	PPOSTDP	0x08
#define	PPOSTX	0x10
#define	PPOSTY	0x20
#define	PPOSTS	(0x40|REGBSSTK)
#define	PPOSTU	(0x40|REGBUSTK)
#define	PPOSTPC	0x80

	long	labelloc;
	static int satsub;
	int	ifstkpt = 0;
	int	fraifskip = FALSE;

	struct symel * endsymbol = SYMNULL;

#line 142 "as6809.y"
typedef union {
	int	intv;
	long 	longv;
	char	*strng;
	struct symel *symb;
} YYSTYPE;
#line 159 "y.tab.c"
#define ACCUM 257
#define INDEX 258
#define SPECREG 259
#define PCRELATIVE 260
#define KOC_BDEF 261
#define KOC_ELSE 262
#define KOC_END 263
#define KOC_ENDI 264
#define KOC_EQU 265
#define KOC_IF 266
#define KOC_INCLUDE 267
#define KOC_ORG 268
#define KOC_RESM 269
#define KOC_SDEF 270
#define KOC_SET 271
#define KOC_WDEF 272
#define KOC_CHSET 273
#define KOC_CHDEF 274
#define KOC_CHUSE 275
#define KOC_opcode 276
#define KOC_sstkop 277
#define KOC_ustkop 278
#define KOC_tfrop 279
#define CONSTANT 280
#define EOL 281
#define KEOP_AND 282
#define KEOP_DEFINED 283
#define KEOP_EQ 284
#define KEOP_GE 285
#define KEOP_GT 286
#define KEOP_HIGH 287
#define KEOP_LE 288
#define KEOP_LOW 289
#define KEOP_LT 290
#define KEOP_MOD 291
#define KEOP_MUN 292
#define KEOP_NE 293
#define KEOP_NOT 294
#define KEOP_OR 295
#define KEOP_SHL 296
#define KEOP_SHR 297
#define KEOP_XOR 298
#define KEOP_locctr 299
#define LABEL 300
#define STRING 301
#define SYMBOL 302
#define KTK_invalid 303
#define YYERRCODE 256
short yylhs[] = {                                        -1,
    0,    0,    7,    7,    7,    8,    8,    8,    8,    8,
    8,    8,    8,    8,    8,    8,    8,    8,    8,    8,
    8,    8,    9,    9,   10,   10,   10,   10,    5,    5,
    6,    6,   10,   10,   10,   10,   10,   10,   10,   10,
   10,   10,    3,    3,    3,    3,    3,    3,    3,    3,
    3,    3,    3,    3,    1,    1,    2,    2,    2,    4,
    4,    4,    4,    4,    4,    4,    4,    4,    4,    4,
    4,    4,    4,    4,    4,    4,    4,    4,    4,    4,
    4,    4,    4,    4,    4,    4,
};
short yylen[] = {                                         2,
    2,    1,    2,    1,    2,    2,    1,    2,    3,    3,
    2,    1,    1,    1,    3,    2,    2,    1,    2,    4,
    1,    1,    2,    1,    2,    2,    2,    2,    3,    1,
    3,    1,    1,    3,    2,    2,    4,    6,    4,    2,
    2,    4,    3,    3,    2,    3,    4,    3,    4,    5,
    5,    4,    6,    6,    3,    1,    1,    1,    1,    2,
    2,    2,    2,    2,    3,    3,    3,    3,    3,    3,
    3,    3,    3,    3,    3,    3,    3,    3,    3,    3,
    2,    1,    1,    1,    1,    3,
};
short yydefred[] = {                                      0,
    0,    0,   13,    7,   14,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    4,    0,    0,
    2,    0,   22,   24,    5,   84,    0,    0,    0,    0,
   85,   82,    0,    0,   83,    0,    0,    0,    0,    8,
    0,    0,   32,    0,    0,    0,    0,    0,    0,    0,
    0,   36,    0,   57,   58,   59,    0,   56,    0,    0,
    6,    0,    0,    0,   17,   23,    1,    3,   81,    0,
    0,    0,   60,   61,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,   86,    0,    0,
    0,    0,    0,    0,   69,    0,    0,   70,   71,    0,
    0,    0,   65,   66,    0,   31,    0,   44,    0,   48,
    0,    0,    0,    0,    0,   39,   43,   37,   55,   42,
   47,   49,    0,    0,   52,    0,    0,    0,   51,    0,
    0,   50,   38,   53,   54,
};
short yydgoto[] = {                                      20,
   57,   58,   52,   37,   38,   44,   21,   22,   23,   24,
};
short yysindex[] = {                                    292,
 -259,  -15,    0,    0,    0,  -15, -262,  -15,  -15, -261,
  -15, -260,  -15,  -35, -226, -226, -226,    0,  231,  292,
    0, -239,    0,    0,    0,    0, -258,  -15,  -15,  -15,
    0,    0,  -15,  -15,    0,  -15,  138,   -1,  138,    0,
  138,  138,    0,    1,   -1,    2,  138,    8,  -41,  -15,
  -25,    0,  121,    0,    0,    0,   10,    0,   10,   13,
    0,  -15,  -15,  -15,    0,    0,    0,    0,    0,  138,
  138,  169,    0,    0,    6,  -15,  -15,  -15,  -15,  -15,
  -15,  -15,  -15,  -15,  -15,  -15,  -15,  -15,  -15,  -15,
  -15,  -15, -251,  -15, -200,   16,  -33,  138,   17,  -32,
  101, -224, -226, -226,  138,  138,  138,    0,  169,  176,
  176,  176,  176,  176,    0,  176,  155,    0,    0,  155,
   72,   72,    0,    0,  138,    0,   -1,    0,   19,    0,
 -198, -194,  -27,   25, -223,    0,    0,    0,    0,    0,
    0,    0,  -22,   29,    0, -184,  -17,  -16,    0,  -14,
  -12,    0,    0,    0,    0,
};
short yyrindex[] = {                                      0,
    0,    0,    0,    0,    0, -203,    0,    0,    0,    0,
    0,    0, -196, -195,    0,    0,    0,    0, -193,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,  -43, -259, -192,    0,
 -190, -189,    0, -187, -185,    0, -181,    0,    0,    0,
    0,    0, -178,    0,    0,    0, -175,    0, -174,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,  -30,
  -18,  -38,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0, -172,    0, -170,    0,    0,
    0,    0,    0,    0, -169, -163, -159,    0,   49,   54,
   58,   60,   64,   69,    0,   79,  -20,    0,    0,   84,
   24,   39,    0,    0,  -42,    0, -157,    0, -155,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,
};
short yygindex[] = {                                      0,
   71,   12,    0,  455,   27,    0,   77,    0,    0,  108,
};
#define YYTABLESIZE 592
short yytable[] = {                                      50,
   30,   29,   62,   97,   36,   62,   35,   33,   49,   34,
   63,  131,  134,   63,   36,  144,   35,   33,  100,   34,
   79,   25,   64,   79,   36,   64,   35,   33,   60,   34,
   54,   55,   56,  137,  147,  138,  148,   45,   40,   43,
   46,   68,   92,   69,   93,   94,  108,   90,   88,  126,
   89,   95,   91,  103,   62,   51,  104,  128,  129,  142,
  132,  141,   63,  143,   67,  145,   67,   67,   67,  146,
  149,  150,   79,  151,   64,  152,  153,   12,  154,   68,
  155,   68,   68,   68,   18,   33,   59,   21,   11,   78,
   16,   28,   78,   26,   77,   27,   67,   77,   73,   19,
   72,   73,   35,   72,   75,   40,   41,   75,   45,   74,
   34,    9,   74,   90,  139,  140,   67,   15,   91,   76,
  127,   10,   76,   20,   80,   46,   66,   80,    0,    0,
    0,   68,    0,    0,    0,    0,    0,    0,    0,    0,
    0,   78,   90,   88,  135,   89,   77,   91,    0,    0,
   73,    0,   72,    0,    0,    0,   75,    0,    0,    0,
    0,   74,   90,   88,  102,   89,    0,   91,    0,    0,
    0,   76,    0,    0,    0,    0,   80,    0,    0,   90,
   88,    0,   89,    0,   91,    0,    0,    0,    0,    0,
    0,    0,    0,  136,    0,    0,   90,   88,    0,   89,
    0,   91,    0,    0,    0,    0,    0,    0,    0,    0,
   90,   88,    0,   89,    0,   91,   96,   90,   88,    0,
   89,   48,   91,    0,  130,  133,    0,    0,    0,    0,
    0,   99,    0,    0,    0,    0,    0,   30,   29,    0,
    0,    0,   62,   62,   26,    0,    0,   27,    0,    0,
   63,   28,    0,   29,   26,    0,   62,   27,   30,   62,
   79,   28,   64,   29,   26,   31,   32,   27,   30,    0,
    0,   28,    0,   29,   79,   31,   32,   79,   30,    0,
    0,    0,    0,    0,    0,   31,   32,   76,    0,   77,
   78,   79,    0,   80,    0,   81,   82,    0,   83,    0,
   84,   85,   86,   87,   67,   67,    0,   67,   67,   67,
    0,   67,    0,   67,    0,    0,   67,    0,   67,   68,
   68,   67,   68,   68,   68,    0,   68,    0,   68,   78,
   78,   68,    0,   68,   77,   77,   68,    0,   73,   73,
   72,   72,    0,   78,   75,   75,   78,    0,   77,   74,
   74,   77,   73,    0,   72,   73,    0,   72,   75,   76,
   76,   75,   82,   74,   80,    0,   74,   85,   86,    0,
    0,    0,    0,   76,    0,    0,   76,    0,   80,    0,
    0,   80,   76,    0,   77,   78,   79,    0,   80,    0,
   81,   82,    0,   83,    0,   84,   85,   86,   87,    0,
    0,    0,   76,    0,   77,   78,   79,    0,   80,    0,
   81,   82,    0,   83,    0,   84,   85,   86,   87,   76,
    0,   77,   78,   79,    0,   80,    0,   81,   82,    0,
   83,    0,   84,   85,   86,   87,   76,    0,   77,   78,
   79,    0,   80,    0,   81,   82,    0,   83,    0,    0,
   85,   86,   77,   78,   79,    0,   80,    0,   81,   82,
   39,   83,   41,   42,   85,   86,   82,   47,   53,    0,
    0,   85,   86,    0,    0,    0,    0,    0,    0,    0,
    0,    0,   70,   71,   72,    0,    0,   73,   74,    0,
   75,    2,    0,   61,    0,   62,    0,    0,   63,    9,
   10,   64,   11,   65,   98,  101,   14,   15,   16,   17,
    0,    0,    0,    0,    0,    0,  105,  106,  107,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
  109,  110,  111,  112,  113,  114,  115,  116,  117,  118,
  119,  120,  121,  122,  123,  124,  125,    1,    0,    0,
    0,    0,    2,    3,    4,    5,    0,    6,    7,    8,
    9,   10,    0,   11,    0,   12,   13,   14,   15,   16,
   17,    0,   18,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,   19,
};
short yycheck[] = {                                      35,
   44,   44,   41,   45,   40,   44,   42,   43,   44,   45,
   41,   45,   45,   44,   40,   43,   42,   43,   44,   45,
   41,  281,   41,   44,   40,   44,   42,   43,   17,   45,
  257,  258,  259,  258,  258,  260,  260,   11,  301,  301,
  301,  281,   44,  302,   44,   44,   41,   42,   43,  301,
   45,   44,   47,   44,   93,   91,   44,  258,   43,  258,
   44,   43,   93,  258,   41,   93,   43,   44,   45,   45,
   93,   43,   93,  258,   93,   93,   93,  281,   93,   41,
   93,   43,   44,   45,  281,  281,   16,  281,  281,   41,
  281,  281,   44,  281,   41,  281,   20,   44,   41,  281,
   41,   44,  281,   44,   41,  281,  281,   44,  281,   41,
  281,  281,   44,   42,  103,  104,   93,  281,   47,   41,
   94,  281,   44,  281,   41,  281,   19,   44,   -1,   -1,
   -1,   93,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,
   -1,   93,   42,   43,   44,   45,   93,   47,   -1,   -1,
   93,   -1,   93,   -1,   -1,   -1,   93,   -1,   -1,   -1,
   -1,   93,   42,   43,   44,   45,   -1,   47,   -1,   -1,
   -1,   93,   -1,   -1,   -1,   -1,   93,   -1,   -1,   42,
   43,   -1,   45,   -1,   47,   -1,   -1,   -1,   -1,   -1,
   -1,   -1,   -1,   93,   -1,   -1,   42,   43,   -1,   45,
   -1,   47,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,
   42,   43,   -1,   45,   -1,   47,  258,   42,   43,   -1,
   45,  257,   47,   -1,  258,  258,   -1,   -1,   -1,   -1,
   -1,  257,   -1,   -1,   -1,   -1,   -1,  281,  281,   -1,
   -1,   -1,  281,  282,  280,   -1,   -1,  283,   -1,   -1,
  281,  287,   -1,  289,  280,   -1,  295,  283,  294,  298,
  281,  287,  281,  289,  280,  301,  302,  283,  294,   -1,
   -1,  287,   -1,  289,  295,  301,  302,  298,  294,   -1,
   -1,   -1,   -1,   -1,   -1,  301,  302,  282,   -1,  284,
  285,  286,   -1,  288,   -1,  290,  291,   -1,  293,   -1,
  295,  296,  297,  298,  281,  282,   -1,  284,  285,  286,
   -1,  288,   -1,  290,   -1,   -1,  293,   -1,  295,  281,
  282,  298,  284,  285,  286,   -1,  288,   -1,  290,  281,
  282,  293,   -1,  295,  281,  282,  298,   -1,  281,  282,
  281,  282,   -1,  295,  281,  282,  298,   -1,  295,  281,
  282,  298,  295,   -1,  295,  298,   -1,  298,  295,  281,
  282,  298,  291,  295,  281,   -1,  298,  296,  297,   -1,
   -1,   -1,   -1,  295,   -1,   -1,  298,   -1,  295,   -1,
   -1,  298,  282,   -1,  284,  285,  286,   -1,  288,   -1,
  290,  291,   -1,  293,   -1,  295,  296,  297,  298,   -1,
   -1,   -1,  282,   -1,  284,  285,  286,   -1,  288,   -1,
  290,  291,   -1,  293,   -1,  295,  296,  297,  298,  282,
   -1,  284,  285,  286,   -1,  288,   -1,  290,  291,   -1,
  293,   -1,  295,  296,  297,  298,  282,   -1,  284,  285,
  286,   -1,  288,   -1,  290,  291,   -1,  293,   -1,   -1,
  296,  297,  284,  285,  286,   -1,  288,   -1,  290,  291,
    6,  293,    8,    9,  296,  297,  291,   13,   14,   -1,
   -1,  296,  297,   -1,   -1,   -1,   -1,   -1,   -1,   -1,
   -1,   -1,   28,   29,   30,   -1,   -1,   33,   34,   -1,
   36,  261,   -1,  263,   -1,  265,   -1,   -1,  268,  269,
  270,  271,  272,  273,   50,   51,  276,  277,  278,  279,
   -1,   -1,   -1,   -1,   -1,   -1,   62,   63,   64,   -1,
   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,
   76,   77,   78,   79,   80,   81,   82,   83,   84,   85,
   86,   87,   88,   89,   90,   91,   92,  256,   -1,   -1,
   -1,   -1,  261,  262,  263,  264,   -1,  266,  267,  268,
  269,  270,   -1,  272,   -1,  274,  275,  276,  277,  278,
  279,   -1,  281,   -1,   -1,   -1,   -1,   -1,   -1,   -1,
   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,
   -1,  300,
};
#define YYFINAL 20
#ifndef YYDEBUG
#define YYDEBUG 0
#endif
#define YYMAXTOKEN 303
#if YYDEBUG
char *yyname[] = {
"end-of-file",0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,"'#'",0,0,0,0,"'('","')'","'*'","'+'","','","'-'",0,"'/'",0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,"'['",0,"']'",
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,"ACCUM","INDEX","SPECREG","PCRELATIVE","KOC_BDEF","KOC_ELSE","KOC_END",
"KOC_ENDI","KOC_EQU","KOC_IF","KOC_INCLUDE","KOC_ORG","KOC_RESM","KOC_SDEF",
"KOC_SET","KOC_WDEF","KOC_CHSET","KOC_CHDEF","KOC_CHUSE","KOC_opcode",
"KOC_sstkop","KOC_ustkop","KOC_tfrop","CONSTANT","EOL","KEOP_AND",
"KEOP_DEFINED","KEOP_EQ","KEOP_GE","KEOP_GT","KEOP_HIGH","KEOP_LE","KEOP_LOW",
"KEOP_LT","KEOP_MOD","KEOP_MUN","KEOP_NE","KEOP_NOT","KEOP_OR","KEOP_SHL",
"KEOP_SHR","KEOP_XOR","KEOP_locctr","LABEL","STRING","SYMBOL","KTK_invalid",
};
char *yyrule[] = {
"$accept : file",
"file : file allline",
"file : allline",
"allline : line EOL",
"allline : EOL",
"allline : error EOL",
"line : LABEL KOC_END",
"line : KOC_END",
"line : KOC_INCLUDE STRING",
"line : LABEL KOC_EQU expr",
"line : LABEL KOC_SET expr",
"line : KOC_IF expr",
"line : KOC_IF",
"line : KOC_ELSE",
"line : KOC_ENDI",
"line : LABEL KOC_ORG expr",
"line : KOC_ORG expr",
"line : LABEL KOC_CHSET",
"line : KOC_CHUSE",
"line : KOC_CHUSE expr",
"line : KOC_CHDEF STRING ',' exprlist",
"line : LABEL",
"line : labeledline",
"labeledline : LABEL genline",
"labeledline : genline",
"genline : KOC_BDEF exprlist",
"genline : KOC_SDEF stringlist",
"genline : KOC_WDEF exprlist",
"genline : KOC_RESM expr",
"exprlist : exprlist ',' expr",
"exprlist : expr",
"stringlist : stringlist ',' STRING",
"stringlist : STRING",
"genline : KOC_opcode",
"genline : KOC_opcode '#' expr",
"genline : KOC_opcode expr",
"genline : KOC_opcode indexed",
"genline : KOC_opcode expr ',' PCRELATIVE",
"genline : KOC_opcode '[' expr ',' PCRELATIVE ']'",
"genline : KOC_opcode '[' expr ']'",
"genline : KOC_sstkop regbits",
"genline : KOC_ustkop regbits",
"genline : KOC_tfrop register ',' register",
"indexed : expr ',' INDEX",
"indexed : ACCUM ',' INDEX",
"indexed : ',' INDEX",
"indexed : ',' INDEX '+'",
"indexed : ',' INDEX '+' '+'",
"indexed : ',' '-' INDEX",
"indexed : ',' '-' '-' INDEX",
"indexed : '[' expr ',' INDEX ']'",
"indexed : '[' ACCUM ',' INDEX ']'",
"indexed : '[' ',' INDEX ']'",
"indexed : '[' ',' INDEX '+' '+' ']'",
"indexed : '[' ',' '-' '-' INDEX ']'",
"regbits : regbits ',' register",
"regbits : register",
"register : ACCUM",
"register : INDEX",
"register : SPECREG",
"expr : '+' expr",
"expr : '-' expr",
"expr : KEOP_NOT expr",
"expr : KEOP_HIGH expr",
"expr : KEOP_LOW expr",
"expr : expr '*' expr",
"expr : expr '/' expr",
"expr : expr '+' expr",
"expr : expr '-' expr",
"expr : expr KEOP_MOD expr",
"expr : expr KEOP_SHL expr",
"expr : expr KEOP_SHR expr",
"expr : expr KEOP_GT expr",
"expr : expr KEOP_GE expr",
"expr : expr KEOP_LT expr",
"expr : expr KEOP_LE expr",
"expr : expr KEOP_NE expr",
"expr : expr KEOP_EQ expr",
"expr : expr KEOP_AND expr",
"expr : expr KEOP_OR expr",
"expr : expr KEOP_XOR expr",
"expr : KEOP_DEFINED SYMBOL",
"expr : SYMBOL",
"expr : '*'",
"expr : CONSTANT",
"expr : STRING",
"expr : '(' expr ')'",
};
#endif
#ifdef YYSTACKSIZE
#undef YYMAXDEPTH
#define YYMAXDEPTH YYSTACKSIZE
#else
#ifdef YYMAXDEPTH
#define YYSTACKSIZE YYMAXDEPTH
#else
#define YYSTACKSIZE 500
#define YYMAXDEPTH 500
#endif
#endif
int yydebug;
int yynerrs;
int yyerrflag;
int yychar;
short *yyssp;
YYSTYPE *yyvsp;
YYSTYPE yyval;
YYSTYPE yylval;
short yyss[YYSTACKSIZE];
YYSTYPE yyvs[YYSTACKSIZE];
#define yystacksize YYSTACKSIZE
#line 1123 "as6809.y"

lexintercept()
/*
	description	intercept the call to yylex (the lexical analyzer)
			and filter out all unnecessary tokens when skipping
			the input between a failed IF and its matching ENDI or
			ELSE
	globals 	fraifskip	the enable flag
*/
{
#undef yylex

	int rv;

	if(fraifskip)
	{
		for(;;)
		{

			switch(rv = yylex())

			{
			case 0:
			case KOC_END:
			case KOC_IF:
			case KOC_ELSE:
			case KOC_ENDI:
			case EOL:
				return rv;
			default:
				break;
			}
		}
	}
	else
		return yylex();
#define yylex lexintercept
}



setreserved()
{

	reservedsym("and", KEOP_AND, 0);
	reservedsym("defined", KEOP_DEFINED,0);
	reservedsym("eq", KEOP_EQ, 0);
	reservedsym("ge", KEOP_GE, 0);
	reservedsym("gt", KEOP_GT, 0);
	reservedsym("high", KEOP_HIGH, 0);
	reservedsym("le", KEOP_LE, 0);
	reservedsym("low", KEOP_LOW, 0);
	reservedsym("lt", KEOP_LT, 0);
	reservedsym("mod", KEOP_MOD, 0);
	reservedsym("ne", KEOP_NE, 0);
	reservedsym("not", KEOP_NOT, 0);
	reservedsym("or", KEOP_OR, 0);
	reservedsym("shl", KEOP_SHL, 0);
	reservedsym("shr", KEOP_SHR, 0);
	reservedsym("xor", KEOP_XOR, 0);
	reservedsym("AND", KEOP_AND, 0);
	reservedsym("DEFINED", KEOP_DEFINED,0);
	reservedsym("EQ", KEOP_EQ, 0);
	reservedsym("GE", KEOP_GE, 0);
	reservedsym("GT", KEOP_GT, 0);
	reservedsym("HIGH", KEOP_HIGH, 0);
	reservedsym("LE", KEOP_LE, 0);
	reservedsym("LOW", KEOP_LOW, 0);
	reservedsym("LT", KEOP_LT, 0);
	reservedsym("MOD", KEOP_MOD, 0);
	reservedsym("NE", KEOP_NE, 0);
	reservedsym("NOT", KEOP_NOT, 0);
	reservedsym("OR", KEOP_OR, 0);
	reservedsym("SHL", KEOP_SHL, 0);
	reservedsym("SHR", KEOP_SHR, 0);
	reservedsym("XOR", KEOP_XOR, 0);

	/* machine specific token definitions */
	reservedsym("a", ACCUM, TFRA);
	reservedsym("b", ACCUM, TFRB);
	reservedsym("cc", SPECREG, TFRCC);
	reservedsym("dp", SPECREG, TFRDP);
	reservedsym("d", ACCUM, TFRD);
	reservedsym("x", INDEX, TFRX);
	reservedsym("y", INDEX, TFRY);
	reservedsym("u", INDEX, TFRU);
	reservedsym("s", INDEX, TFRS);
	reservedsym("pc", SPECREG, TFRPC);
	reservedsym("pcr", PCRELATIVE, 0);
	reservedsym("A", ACCUM, TFRA);
	reservedsym("B", ACCUM, TFRB);
	reservedsym("CC", SPECREG, TFRCC);
	reservedsym("DP", SPECREG, TFRDP);
	reservedsym("D", ACCUM, TFRD);
	reservedsym("X", INDEX, TFRX);
	reservedsym("Y", INDEX, TFRY);
	reservedsym("U", INDEX, TFRU);
	reservedsym("S", INDEX, TFRS);
	reservedsym("PC", SPECREG, TFRPC);
	reservedsym("PCR", PCRELATIVE, 0);
}

cpumatch(str)
	char * str;
{
	return TRUE;
}

/*
	description	Opcode and Instruction generation tables
	usage		Unix, framework crossassembler
	history		September 25, 1987
*/

#define NUMOPCODE 163
#define NUMSYNBLK 226
#define NUMDIFFOP 279

int gnumopcode = NUMOPCODE;

int ophashlnk[NUMOPCODE];

struct opsym optab[NUMOPCODE+1]
	= {
	{"invalid", KOC_opcode, 2, 0 },
	{"ABX", KOC_opcode, 1, 2 },
	{"ADCA", KOC_opcode, 3, 3 },
	{"ADCB", KOC_opcode, 3, 6 },
	{"ADDA", KOC_opcode, 3, 9 },
	{"ADDB", KOC_opcode, 3, 12 },
	{"ADDD", KOC_opcode, 3, 15 },
	{"ANDA", KOC_opcode, 3, 18 },
	{"ANDB", KOC_opcode, 3, 21 },
	{"ANDCC", KOC_opcode, 1, 24 },
	{"ASL", KOC_opcode, 2, 25 },
	{"ASLA", KOC_opcode, 1, 27 },
	{"ASLB", KOC_opcode, 1, 28 },
	{"ASR", KOC_opcode, 2, 29 },
	{"ASRA", KOC_opcode, 1, 31 },
	{"ASRB", KOC_opcode, 1, 32 },
	{"BCC", KOC_opcode, 1, 33 },
	{"BCS", KOC_opcode, 1, 34 },
	{"BEQ", KOC_opcode, 1, 35 },
	{"BGE", KOC_opcode, 1, 36 },
	{"BGT", KOC_opcode, 1, 37 },
	{"BHI", KOC_opcode, 1, 38 },
	{"BHS", KOC_opcode, 1, 39 },
	{"BITA", KOC_opcode, 3, 40 },
	{"BITB", KOC_opcode, 3, 43 },
	{"BLE", KOC_opcode, 1, 46 },
	{"BLO", KOC_opcode, 1, 47 },
	{"BLS", KOC_opcode, 1, 48 },
	{"BLT", KOC_opcode, 1, 49 },
	{"BMI", KOC_opcode, 1, 50 },
	{"BNE", KOC_opcode, 1, 51 },
	{"BPL", KOC_opcode, 1, 52 },
	{"BRA", KOC_opcode, 1, 53 },
	{"BRN", KOC_opcode, 1, 54 },
	{"BSR", KOC_opcode, 1, 55 },
	{"BVC", KOC_opcode, 1, 56 },
	{"BVS", KOC_opcode, 1, 57 },
	{"BYTE", KOC_BDEF, 0, 0 },
	{"CHARDEF", KOC_CHDEF, 0, 0 },
	{"CHARSET", KOC_CHSET, 0, 0 },
	{"CHARUSE", KOC_CHUSE, 0, 0 },
	{"CHD", KOC_CHDEF, 0, 0 },
	{"CLR", KOC_opcode, 2, 58 },
	{"CLRA", KOC_opcode, 1, 60 },
	{"CLRB", KOC_opcode, 1, 61 },
	{"CMPA", KOC_opcode, 3, 62 },
	{"CMPB", KOC_opcode, 3, 65 },
	{"CMPD", KOC_opcode, 3, 68 },
	{"CMPS", KOC_opcode, 3, 71 },
	{"CMPU", KOC_opcode, 3, 74 },
	{"CMPX", KOC_opcode, 3, 77 },
	{"CMPY", KOC_opcode, 3, 80 },
	{"COM", KOC_opcode, 2, 83 },
	{"COMA", KOC_opcode, 1, 85 },
	{"COMB", KOC_opcode, 1, 86 },
	{"CWAI", KOC_opcode, 1, 87 },
	{"DAA", KOC_opcode, 1, 88 },
	{"DB", KOC_BDEF, 0, 0 },
	{"DEC", KOC_opcode, 2, 89 },
	{"DECA", KOC_opcode, 1, 91 },
	{"DECB", KOC_opcode, 1, 92 },
	{"DW", KOC_WDEF, 0, 0 },
	{"ELSE", KOC_ELSE, 0, 0 },
	{"END", KOC_END, 0, 0 },
	{"ENDI", KOC_ENDI, 0, 0 },
	{"EORA", KOC_opcode, 3, 93 },
	{"EORB", KOC_opcode, 3, 96 },
	{"EQU", KOC_EQU, 0, 0 },
	{"EXG", KOC_tfrop, 1, 99 },
	{"FCB", KOC_BDEF, 0, 0 },
	{"FCC", KOC_SDEF, 0, 0 },
	{"FDB", KOC_WDEF, 0, 0 },
	{"IF", KOC_IF, 0, 0 },
	{"INC", KOC_opcode, 2, 100 },
	{"INCA", KOC_opcode, 1, 102 },
	{"INCB", KOC_opcode, 1, 103 },
	{"INCL", KOC_INCLUDE, 0, 0 },
	{"INCLUDE", KOC_INCLUDE, 0, 0 },
	{"JMP", KOC_opcode, 2, 104 },
	{"JSR", KOC_opcode, 2, 106 },
	{"LBCC", KOC_opcode, 1, 108 },
	{"LBCS", KOC_opcode, 1, 109 },
	{"LBEQ", KOC_opcode, 1, 110 },
	{"LBGE", KOC_opcode, 1, 111 },
	{"LBGT", KOC_opcode, 1, 112 },
	{"LBHI", KOC_opcode, 1, 113 },
	{"LBHS", KOC_opcode, 1, 114 },
	{"LBLE", KOC_opcode, 1, 115 },
	{"LBLO", KOC_opcode, 1, 116 },
	{"LBLS", KOC_opcode, 1, 117 },
	{"LBLT", KOC_opcode, 1, 118 },
	{"LBMI", KOC_opcode, 1, 119 },
	{"LBNE", KOC_opcode, 1, 120 },
	{"LBPL", KOC_opcode, 1, 121 },
	{"LBRA", KOC_opcode, 1, 122 },
	{"LBRN", KOC_opcode, 1, 123 },
	{"LBSR", KOC_opcode, 1, 124 },
	{"LBVC", KOC_opcode, 1, 125 },
	{"LBVS", KOC_opcode, 1, 126 },
	{"LDA", KOC_opcode, 3, 127 },
	{"LDB", KOC_opcode, 3, 130 },
	{"LDD", KOC_opcode, 3, 133 },
	{"LDS", KOC_opcode, 3, 136 },
	{"LDU", KOC_opcode, 3, 139 },
	{"LDX", KOC_opcode, 3, 142 },
	{"LDY", KOC_opcode, 3, 145 },
	{"LEAS", KOC_opcode, 1, 148 },
	{"LEAU", KOC_opcode, 1, 149 },
	{"LEAX", KOC_opcode, 1, 150 },
	{"LEAY", KOC_opcode, 1, 151 },
	{"LSL", KOC_opcode, 2, 152 },
	{"LSLA", KOC_opcode, 1, 154 },
	{"LSLB", KOC_opcode, 1, 155 },
	{"LSR", KOC_opcode, 2, 156 },
	{"LSRA", KOC_opcode, 1, 158 },
	{"LSRB", KOC_opcode, 1, 159 },
	{"MUL", KOC_opcode, 1, 160 },
	{"NEG", KOC_opcode, 2, 161 },
	{"NEGA", KOC_opcode, 1, 163 },
	{"NEGB", KOC_opcode, 1, 164 },
	{"NOP", KOC_opcode, 1, 165 },
	{"ORA", KOC_opcode, 3, 166 },
	{"ORB", KOC_opcode, 3, 169 },
	{"ORCC", KOC_opcode, 1, 172 },
	{"ORG", KOC_ORG, 0, 0 },
	{"PSHS", KOC_sstkop, 1, 173 },
	{"PSHU", KOC_ustkop, 1, 174 },
	{"PULS", KOC_sstkop, 1, 175 },
	{"PULU", KOC_ustkop, 1, 176 },
	{"RESERVE", KOC_RESM, 0, 0 },
	{"RMB", KOC_RESM, 0, 0 },
	{"ROL", KOC_opcode, 2, 177 },
	{"ROLA", KOC_opcode, 1, 179 },
	{"ROLB", KOC_opcode, 1, 180 },
	{"ROR", KOC_opcode, 2, 181 },
	{"RORA", KOC_opcode, 1, 183 },
	{"RORB", KOC_opcode, 1, 184 },
	{"RTI", KOC_opcode, 1, 185 },
	{"RTS", KOC_opcode, 1, 186 },
	{"SBCA", KOC_opcode, 3, 187 },
	{"SBCB", KOC_opcode, 3, 190 },
	{"SET", KOC_SET, 0, 0 },
	{"SEX", KOC_opcode, 1, 193 },
	{"STA", KOC_opcode, 2, 194 },
	{"STB", KOC_opcode, 2, 196 },
	{"STD", KOC_opcode, 2, 198 },
	{"STRING", KOC_SDEF, 0, 0 },
	{"STS", KOC_opcode, 2, 200 },
	{"STU", KOC_opcode, 2, 202 },
	{"STX", KOC_opcode, 2, 204 },
	{"STY", KOC_opcode, 2, 206 },
	{"SUBA", KOC_opcode, 3, 208 },
	{"SUBB", KOC_opcode, 3, 211 },
	{"SUBD", KOC_opcode, 3, 214 },
	{"SWI2", KOC_opcode, 1, 217 },
	{"SWI3", KOC_opcode, 1, 218 },
	{"SWI", KOC_opcode, 1, 219 },
	{"SYNC", KOC_opcode, 1, 220 },
	{"TFR", KOC_tfrop, 1, 221 },
	{"TST", KOC_opcode, 2, 222 },
	{"TSTA", KOC_opcode, 1, 224 },
	{"TSTB", KOC_opcode, 1, 225 },
	{"WORD", KOC_WDEF, 0, 0 },
	{ "", 0, 0, 0 }};

struct opsynt ostab[NUMSYNBLK+1]
	= {
/* invalid 0 */ { 0, 1, 0 },
/* invalid 1 */ { 0xffff, 1, 1 },
/* ABX 2 */ { ST_INH, 1, 2 },
/* ADCA 3 */ { ST_EXP, 2, 3 },
/* ADCA 4 */ { ST_IMM, 1, 5 },
/* ADCA 5 */ { ST_IND, 1, 6 },
/* ADCB 6 */ { ST_EXP, 2, 7 },
/* ADCB 7 */ { ST_IMM, 1, 9 },
/* ADCB 8 */ { ST_IND, 1, 10 },
/* ADDA 9 */ { ST_EXP, 2, 11 },
/* ADDA 10 */ { ST_IMM, 1, 13 },
/* ADDA 11 */ { ST_IND, 1, 14 },
/* ADDB 12 */ { ST_EXP, 2, 15 },
/* ADDB 13 */ { ST_IMM, 1, 17 },
/* ADDB 14 */ { ST_IND, 1, 18 },
/* ADDD 15 */ { ST_EXP, 2, 19 },
/* ADDD 16 */ { ST_IMM, 1, 21 },
/* ADDD 17 */ { ST_IND, 1, 22 },
/* ANDA 18 */ { ST_EXP, 2, 23 },
/* ANDA 19 */ { ST_IMM, 1, 25 },
/* ANDA 20 */ { ST_IND, 1, 26 },
/* ANDB 21 */ { ST_EXP, 2, 27 },
/* ANDB 22 */ { ST_IMM, 1, 29 },
/* ANDB 23 */ { ST_IND, 1, 30 },
/* ANDCC 24 */ { ST_IMM, 1, 31 },
/* ASL 25 */ { ST_EXP, 2, 32 },
/* ASL 26 */ { ST_IND, 1, 34 },
/* ASLA 27 */ { ST_INH, 1, 35 },
/* ASLB 28 */ { ST_INH, 1, 36 },
/* ASR 29 */ { ST_EXP, 2, 37 },
/* ASR 30 */ { ST_IND, 1, 39 },
/* ASRA 31 */ { ST_INH, 1, 40 },
/* ASRB 32 */ { ST_INH, 1, 41 },
/* BCC 33 */ { ST_EXP, 1, 42 },
/* BCS 34 */ { ST_EXP, 1, 43 },
/* BEQ 35 */ { ST_EXP, 1, 44 },
/* BGE 36 */ { ST_EXP, 1, 45 },
/* BGT 37 */ { ST_EXP, 1, 46 },
/* BHI 38 */ { ST_EXP, 1, 47 },
/* BHS 39 */ { ST_EXP, 1, 48 },
/* BITA 40 */ { ST_EXP, 2, 49 },
/* BITA 41 */ { ST_IMM, 1, 51 },
/* BITA 42 */ { ST_IND, 1, 52 },
/* BITB 43 */ { ST_EXP, 2, 53 },
/* BITB 44 */ { ST_IMM, 1, 55 },
/* BITB 45 */ { ST_IND, 1, 56 },
/* BLE 46 */ { ST_EXP, 1, 57 },
/* BLO 47 */ { ST_EXP, 1, 58 },
/* BLS 48 */ { ST_EXP, 1, 59 },
/* BLT 49 */ { ST_EXP, 1, 60 },
/* BMI 50 */ { ST_EXP, 1, 61 },
/* BNE 51 */ { ST_EXP, 1, 62 },
/* BPL 52 */ { ST_EXP, 1, 63 },
/* BRA 53 */ { ST_EXP, 1, 64 },
/* BRN 54 */ { ST_EXP, 1, 65 },
/* BSR 55 */ { ST_EXP, 1, 66 },
/* BVC 56 */ { ST_EXP, 1, 67 },
/* BVS 57 */ { ST_EXP, 1, 68 },
/* CLR 58 */ { ST_EXP, 2, 69 },
/* CLR 59 */ { ST_IND, 1, 71 },
/* CLRA 60 */ { ST_INH, 1, 72 },
/* CLRB 61 */ { ST_INH, 1, 73 },
/* CMPA 62 */ { ST_EXP, 2, 74 },
/* CMPA 63 */ { ST_IMM, 1, 76 },
/* CMPA 64 */ { ST_IND, 1, 77 },
/* CMPB 65 */ { ST_EXP, 2, 78 },
/* CMPB 66 */ { ST_IMM, 1, 80 },
/* CMPB 67 */ { ST_IND, 1, 81 },
/* CMPD 68 */ { ST_EXP, 2, 82 },
/* CMPD 69 */ { ST_IMM, 1, 84 },
/* CMPD 70 */ { ST_IND, 1, 85 },
/* CMPS 71 */ { ST_EXP, 2, 86 },
/* CMPS 72 */ { ST_IMM, 1, 88 },
/* CMPS 73 */ { ST_IND, 1, 89 },
/* CMPU 74 */ { ST_EXP, 2, 90 },
/* CMPU 75 */ { ST_IMM, 1, 92 },
/* CMPU 76 */ { ST_IND, 1, 93 },
/* CMPX 77 */ { ST_EXP, 2, 94 },
/* CMPX 78 */ { ST_IMM, 1, 96 },
/* CMPX 79 */ { ST_IND, 1, 97 },
/* CMPY 80 */ { ST_EXP, 2, 98 },
/* CMPY 81 */ { ST_IMM, 1, 100 },
/* CMPY 82 */ { ST_IND, 1, 101 },
/* COM 83 */ { ST_EXP, 2, 102 },
/* COM 84 */ { ST_IND, 1, 104 },
/* COMA 85 */ { ST_INH, 1, 105 },
/* COMB 86 */ { ST_INH, 1, 106 },
/* CWAI 87 */ { ST_IMM, 1, 107 },
/* DAA 88 */ { ST_INH, 1, 108 },
/* DEC 89 */ { ST_EXP, 2, 109 },
/* DEC 90 */ { ST_IND, 1, 111 },
/* DECA 91 */ { ST_INH, 1, 112 },
/* DECB 92 */ { ST_INH, 1, 113 },
/* EORA 93 */ { ST_EXP, 2, 114 },
/* EORA 94 */ { ST_IMM, 1, 116 },
/* EORA 95 */ { ST_IND, 1, 117 },
/* EORB 96 */ { ST_EXP, 2, 118 },
/* EORB 97 */ { ST_IMM, 1, 120 },
/* EORB 98 */ { ST_IND, 1, 121 },
/* EXG 99 */ { ST_TFR, 1, 122 },
/* INC 100 */ { ST_EXP, 2, 123 },
/* INC 101 */ { ST_IND, 1, 125 },
/* INCA 102 */ { ST_INH, 1, 126 },
/* INCB 103 */ { ST_INH, 1, 127 },
/* JMP 104 */ { ST_EXP, 2, 128 },
/* JMP 105 */ { ST_IND, 1, 130 },
/* JSR 106 */ { ST_EXP, 2, 131 },
/* JSR 107 */ { ST_IND, 1, 133 },
/* LBCC 108 */ { ST_EXP, 1, 134 },
/* LBCS 109 */ { ST_EXP, 1, 135 },
/* LBEQ 110 */ { ST_EXP, 1, 136 },
/* LBGE 111 */ { ST_EXP, 1, 137 },
/* LBGT 112 */ { ST_EXP, 1, 138 },
/* LBHI 113 */ { ST_EXP, 1, 139 },
/* LBHS 114 */ { ST_EXP, 1, 140 },
/* LBLE 115 */ { ST_EXP, 1, 141 },
/* LBLO 116 */ { ST_EXP, 1, 142 },
/* LBLS 117 */ { ST_EXP, 1, 143 },
/* LBLT 118 */ { ST_EXP, 1, 144 },
/* LBMI 119 */ { ST_EXP, 1, 145 },
/* LBNE 120 */ { ST_EXP, 1, 146 },
/* LBPL 121 */ { ST_EXP, 1, 147 },
/* LBRA 122 */ { ST_EXP, 1, 148 },
/* LBRN 123 */ { ST_EXP, 1, 149 },
/* LBSR 124 */ { ST_EXP, 1, 150 },
/* LBVC 125 */ { ST_EXP, 1, 151 },
/* LBVS 126 */ { ST_EXP, 1, 152 },
/* LDA 127 */ { ST_EXP, 2, 153 },
/* LDA 128 */ { ST_IMM, 1, 155 },
/* LDA 129 */ { ST_IND, 1, 156 },
/* LDB 130 */ { ST_EXP, 2, 157 },
/* LDB 131 */ { ST_IMM, 1, 159 },
/* LDB 132 */ { ST_IND, 1, 160 },
/* LDD 133 */ { ST_EXP, 2, 161 },
/* LDD 134 */ { ST_IMM, 1, 163 },
/* LDD 135 */ { ST_IND, 1, 164 },
/* LDS 136 */ { ST_EXP, 2, 165 },
/* LDS 137 */ { ST_IMM, 1, 167 },
/* LDS 138 */ { ST_IND, 1, 168 },
/* LDU 139 */ { ST_EXP, 2, 169 },
/* LDU 140 */ { ST_IMM, 1, 171 },
/* LDU 141 */ { ST_IND, 1, 172 },
/* LDX 142 */ { ST_EXP, 2, 173 },
/* LDX 143 */ { ST_IMM, 1, 175 },
/* LDX 144 */ { ST_IND, 1, 176 },
/* LDY 145 */ { ST_EXP, 2, 177 },
/* LDY 146 */ { ST_IMM, 1, 179 },
/* LDY 147 */ { ST_IND, 1, 180 },
/* LEAS 148 */ { ST_IND, 1, 181 },
/* LEAU 149 */ { ST_IND, 1, 182 },
/* LEAX 150 */ { ST_IND, 1, 183 },
/* LEAY 151 */ { ST_IND, 1, 184 },
/* LSL 152 */ { ST_EXP, 2, 185 },
/* LSL 153 */ { ST_IND, 1, 187 },
/* LSLA 154 */ { ST_INH, 1, 188 },
/* LSLB 155 */ { ST_INH, 1, 189 },
/* LSR 156 */ { ST_EXP, 2, 190 },
/* LSR 157 */ { ST_IND, 1, 192 },
/* LSRA 158 */ { ST_INH, 1, 193 },
/* LSRB 159 */ { ST_INH, 1, 194 },
/* MUL 160 */ { ST_INH, 1, 195 },
/* NEG 161 */ { ST_EXP, 2, 196 },
/* NEG 162 */ { ST_IND, 1, 198 },
/* NEGA 163 */ { ST_INH, 1, 199 },
/* NEGB 164 */ { ST_INH, 1, 200 },
/* NOP 165 */ { ST_INH, 1, 201 },
/* ORA 166 */ { ST_EXP, 2, 202 },
/* ORA 167 */ { ST_IMM, 1, 204 },
/* ORA 168 */ { ST_IND, 1, 205 },
/* ORB 169 */ { ST_EXP, 2, 206 },
/* ORB 170 */ { ST_IMM, 1, 208 },
/* ORB 171 */ { ST_IND, 1, 209 },
/* ORCC 172 */ { ST_IMM, 1, 210 },
/* PSHS 173 */ { ST_SPSH, 1, 211 },
/* PSHU 174 */ { ST_UPSH, 1, 212 },
/* PULS 175 */ { ST_SPSH, 1, 213 },
/* PULU 176 */ { ST_UPSH, 1, 214 },
/* ROL 177 */ { ST_EXP, 2, 215 },
/* ROL 178 */ { ST_IND, 1, 217 },
/* ROLA 179 */ { ST_INH, 1, 218 },
/* ROLB 180 */ { ST_INH, 1, 219 },
/* ROR 181 */ { ST_EXP, 2, 220 },
/* ROR 182 */ { ST_IND, 1, 222 },
/* RORA 183 */ { ST_INH, 1, 223 },
/* RORB 184 */ { ST_INH, 1, 224 },
/* RTI 185 */ { ST_INH, 1, 225 },
/* RTS 186 */ { ST_INH, 1, 226 },
/* SBCA 187 */ { ST_EXP, 2, 227 },
/* SBCA 188 */ { ST_IMM, 1, 229 },
/* SBCA 189 */ { ST_IND, 1, 230 },
/* SBCB 190 */ { ST_EXP, 2, 231 },
/* SBCB 191 */ { ST_IMM, 1, 233 },
/* SBCB 192 */ { ST_IND, 1, 234 },
/* SEX 193 */ { ST_INH, 1, 235 },
/* STA 194 */ { ST_EXP, 2, 236 },
/* STA 195 */ { ST_IND, 1, 238 },
/* STB 196 */ { ST_EXP, 2, 239 },
/* STB 197 */ { ST_IND, 1, 241 },
/* STD 198 */ { ST_EXP, 2, 242 },
/* STD 199 */ { ST_IND, 1, 244 },
/* STS 200 */ { ST_EXP, 2, 245 },
/* STS 201 */ { ST_IND, 1, 247 },
/* STU 202 */ { ST_EXP, 2, 248 },
/* STU 203 */ { ST_IND, 1, 250 },
/* STX 204 */ { ST_EXP, 2, 251 },
/* STX 205 */ { ST_IND, 1, 253 },
/* STY 206 */ { ST_EXP, 2, 254 },
/* STY 207 */ { ST_IND, 1, 256 },
/* SUBA 208 */ { ST_EXP, 2, 257 },
/* SUBA 209 */ { ST_IMM, 1, 259 },
/* SUBA 210 */ { ST_IND, 1, 260 },
/* SUBB 211 */ { ST_EXP, 2, 261 },
/* SUBB 212 */ { ST_IMM, 1, 263 },
/* SUBB 213 */ { ST_IND, 1, 264 },
/* SUBD 214 */ { ST_EXP, 2, 265 },
/* SUBD 215 */ { ST_IMM, 1, 267 },
/* SUBD 216 */ { ST_IND, 1, 268 },
/* SWI2 217 */ { ST_INH, 1, 269 },
/* SWI3 218 */ { ST_INH, 1, 270 },
/* SWI 219 */ { ST_INH, 1, 271 },
/* SYNC 220 */ { ST_INH, 1, 272 },
/* TFR 221 */ { ST_TFR, 1, 273 },
/* TST 222 */ { ST_EXP, 2, 274 },
/* TST 223 */ { ST_IND, 1, 276 },
/* TSTA 224 */ { ST_INH, 1, 277 },
/* TSTB 225 */ { ST_INH, 1, 278 },
	{ 0, 0, 0 } };

struct igel igtab[NUMDIFFOP+1]
	= {
/* invalid 0 */   { 0 , 0, 
		"[Xnullentry" },
/* invalid 1 */   { 0 , 0, 
		"[Xinvalid opcode" },
/* ABX 2 */   { 0 , 0, 
		"3a;" },
/* ADCA 3 */   { ADDR , DIRECT, 
		"99;[1=];" },
/* ADCA 4 */   { ADDR , EXTENDED, 
		"b9;[1=]x" },
/* ADCA 5 */   { 0 , 0, 
		"89;[1=];" },
/* ADCA 6 */   { 0 , 0, 
		"a9;" },
/* ADCB 7 */   { ADDR , DIRECT, 
		"d9;[1=];" },
/* ADCB 8 */   { ADDR , EXTENDED, 
		"f9;[1=]x" },
/* ADCB 9 */   { 0 , 0, 
		"c9;[1=];" },
/* ADCB 10 */   { 0 , 0, 
		"e9;" },
/* ADDA 11 */   { ADDR , DIRECT, 
		"9b;[1=];" },
/* ADDA 12 */   { ADDR , EXTENDED, 
		"bb;[1=]x" },
/* ADDA 13 */   { 0 , 0, 
		"8b;[1=];" },
/* ADDA 14 */   { 0 , 0, 
		"ab;" },
/* ADDB 15 */   { ADDR , DIRECT, 
		"db;[1=];" },
/* ADDB 16 */   { ADDR , EXTENDED, 
		"fb;[1=]x" },
/* ADDB 17 */   { 0 , 0, 
		"cb;[1=];" },
/* ADDB 18 */   { 0 , 0, 
		"eb;" },
/* ADDD 19 */   { ADDR , DIRECT, 
		"d3;[1=];" },
/* ADDD 20 */   { ADDR , EXTENDED, 
		"f3;[1=]x" },
/* ADDD 21 */   { 0 , 0, 
		"c3;[1=]x" },
/* ADDD 22 */   { 0 , 0, 
		"e3;" },
/* ANDA 23 */   { ADDR , DIRECT, 
		"94;[1=];" },
/* ANDA 24 */   { ADDR , EXTENDED, 
		"b4;[1=]x" },
/* ANDA 25 */   { 0 , 0, 
		"84;[1=];" },
/* ANDA 26 */   { 0 , 0, 
		"a4;" },
/* ANDB 27 */   { ADDR , DIRECT, 
		"d4;[1=];" },
/* ANDB 28 */   { ADDR , EXTENDED, 
		"f4;[1=]x" },
/* ANDB 29 */   { 0 , 0, 
		"c4;[1=];" },
/* ANDB 30 */   { 0 , 0, 
		"e4;" },
/* ANDCC 31 */   { 0 , 0, 
		"1c;[1=];" },
/* ASL 32 */   { ADDR , DIRECT, 
		"08;[1=];" },
/* ASL 33 */   { ADDR , EXTENDED, 
		"78;[1=]x" },
/* ASL 34 */   { 0 , 0, 
		"68;" },
/* ASLA 35 */   { 0 , 0, 
		"48;" },
/* ASLB 36 */   { 0 , 0, 
		"58;" },
/* ASR 37 */   { ADDR , DIRECT, 
		"07;[1=];" },
/* ASR 38 */   { ADDR , EXTENDED, 
		"77;[1=]x" },
/* ASR 39 */   { 0 , 0, 
		"67;" },
/* ASRA 40 */   { 0 , 0, 
		"47;" },
/* ASRB 41 */   { 0 , 0, 
		"57;" },
/* BCC 42 */   { 0 , 0, 
		"24;[1=].Q.1+-r" },
/* BCS 43 */   { 0 , 0, 
		"25;[1=].Q.1+-r" },
/* BEQ 44 */   { 0 , 0, 
		"27;[1=].Q.1+-r" },
/* BGE 45 */   { 0 , 0, 
		"2c;[1=].Q.1+-r" },
/* BGT 46 */   { 0 , 0, 
		"2e;[1=].Q.1+-r" },
/* BHI 47 */   { 0 , 0, 
		"22;[1=].Q.1+-r" },
/* BHS 48 */   { 0 , 0, 
		"24;[1=].Q.1+-r" },
/* BITA 49 */   { ADDR , DIRECT, 
		"95;[1=];" },
/* BITA 50 */   { ADDR , EXTENDED, 
		"b5;[1=]x" },
/* BITA 51 */   { 0 , 0, 
		"85;[1=];" },
/* BITA 52 */   { 0 , 0, 
		"a5;" },
/* BITB 53 */   { ADDR , DIRECT, 
		"d5;[1=];" },
/* BITB 54 */   { ADDR , EXTENDED, 
		"f5;[1=]x" },
/* BITB 55 */   { 0 , 0, 
		"c5;[1=];" },
/* BITB 56 */   { 0 , 0, 
		"e5;" },
/* BLE 57 */   { 0 , 0, 
		"2f;[1=].Q.1+-r" },
/* BLO 58 */   { 0 , 0, 
		"25;[1=].Q.1+-r" },
/* BLS 59 */   { 0 , 0, 
		"23;[1=].Q.1+-r" },
/* BLT 60 */   { 0 , 0, 
		"2d;[1=].Q.1+-r" },
/* BMI 61 */   { 0 , 0, 
		"2b;[1=].Q.1+-r" },
/* BNE 62 */   { 0 , 0, 
		"26;[1=].Q.1+-r" },
/* BPL 63 */   { 0 , 0, 
		"2a;[1=].Q.1+-r" },
/* BRA 64 */   { 0 , 0, 
		"20;[1=].Q.1+-r" },
/* BRN 65 */   { 0 , 0, 
		"21;[1=].Q.1+-r" },
/* BSR 66 */   { 0 , 0, 
		"8d;[1=].Q.1+-r" },
/* BVC 67 */   { 0 , 0, 
		"28;[1=].Q.1+-r" },
/* BVS 68 */   { 0 , 0, 
		"29;[1=].Q.1+-r" },
/* CLR 69 */   { ADDR , DIRECT, 
		"0f;[1=];" },
/* CLR 70 */   { ADDR , EXTENDED, 
		"7f;[1=]x" },
/* CLR 71 */   { 0 , 0, 
		"6f;" },
/* CLRA 72 */   { 0 , 0, 
		"4f;" },
/* CLRB 73 */   { 0 , 0, 
		"5f;" },
/* CMPA 74 */   { ADDR , DIRECT, 
		"91;[1=];" },
/* CMPA 75 */   { ADDR , EXTENDED, 
		"b1;[1=]x" },
/* CMPA 76 */   { 0 , 0, 
		"81;[1=];" },
/* CMPA 77 */   { 0 , 0, 
		"a1;" },
/* CMPB 78 */   { ADDR , DIRECT, 
		"d1;[1=];" },
/* CMPB 79 */   { ADDR , EXTENDED, 
		"f1;[1=]x" },
/* CMPB 80 */   { 0 , 0, 
		"c1;[1=];" },
/* CMPB 81 */   { 0 , 0, 
		"e1;" },
/* CMPD 82 */   { ADDR , DIRECT, 
		"10;93;[1=];" },
/* CMPD 83 */   { ADDR , EXTENDED, 
		"10;b3;[1=]x" },
/* CMPD 84 */   { 0 , 0, 
		"10;83;[1=]x" },
/* CMPD 85 */   { 0 , 0, 
		"10;a3;" },
/* CMPS 86 */   { ADDR , DIRECT, 
		"11;9c;[1=];" },
/* CMPS 87 */   { ADDR , EXTENDED, 
		"11;bc;[1=]x" },
/* CMPS 88 */   { 0 , 0, 
		"11;8c;[1=]x" },
/* CMPS 89 */   { 0 , 0, 
		"11;ac;" },
/* CMPU 90 */   { ADDR , DIRECT, 
		"11;93;[1=];" },
/* CMPU 91 */   { ADDR , EXTENDED, 
		"11;b3;[1=]x" },
/* CMPU 92 */   { 0 , 0, 
		"11;83;[1=]x" },
/* CMPU 93 */   { 0 , 0, 
		"11;a3;" },
/* CMPX 94 */   { ADDR , DIRECT, 
		"9c;[1=];" },
/* CMPX 95 */   { ADDR , EXTENDED, 
		"bc;[1=]x" },
/* CMPX 96 */   { 0 , 0, 
		"8c;[1=]x" },
/* CMPX 97 */   { 0 , 0, 
		"ac;" },
/* CMPY 98 */   { ADDR , DIRECT, 
		"10;9c;[1=];" },
/* CMPY 99 */   { ADDR , EXTENDED, 
		"10;bc;[1=]x" },
/* CMPY 100 */   { 0 , 0, 
		"10;8c;[1=]x" },
/* CMPY 101 */   { 0 , 0, 
		"10;ac;" },
/* COM 102 */   { ADDR , DIRECT, 
		"03;[1=];" },
/* COM 103 */   { ADDR , EXTENDED, 
		"73;[1=]x" },
/* COM 104 */   { 0 , 0, 
		"63;" },
/* COMA 105 */   { 0 , 0, 
		"43;" },
/* COMB 106 */   { 0 , 0, 
		"53;" },
/* CWAI 107 */   { 0 , 0, 
		"3c;[1=];" },
/* DAA 108 */   { 0 , 0, 
		"19;" },
/* DEC 109 */   { ADDR , DIRECT, 
		"0a;[1=];" },
/* DEC 110 */   { ADDR , EXTENDED, 
		"7a;[1=]x" },
/* DEC 111 */   { 0 , 0, 
		"6a;" },
/* DECA 112 */   { 0 , 0, 
		"4a;" },
/* DECB 113 */   { 0 , 0, 
		"5a;" },
/* EORA 114 */   { ADDR , DIRECT, 
		"98;[1=];" },
/* EORA 115 */   { ADDR , EXTENDED, 
		"b8;[1=]x" },
/* EORA 116 */   { 0 , 0, 
		"88;[1=];" },
/* EORA 117 */   { 0 , 0, 
		"a8;" },
/* EORB 118 */   { ADDR , DIRECT, 
		"d8;[1=];" },
/* EORB 119 */   { ADDR , EXTENDED, 
		"f8;[1=]x" },
/* EORB 120 */   { 0 , 0, 
		"c8;[1=];" },
/* EORB 121 */   { 0 , 0, 
		"e8;" },
/* EXG 122 */   { 0 , 0, 
		"1e;[1#2#];" },
/* INC 123 */   { ADDR , DIRECT, 
		"0c;[1=];" },
/* INC 124 */   { ADDR , EXTENDED, 
		"7c;[1=]x" },
/* INC 125 */   { 0 , 0, 
		"6c;" },
/* INCA 126 */   { 0 , 0, 
		"4c;" },
/* INCB 127 */   { 0 , 0, 
		"5c;" },
/* JMP 128 */   { ADDR , DIRECT, 
		"0e;[1=];" },
/* JMP 129 */   { ADDR , EXTENDED, 
		"7e;[1=]x" },
/* JMP 130 */   { 0 , 0, 
		"6e;" },
/* JSR 131 */   { ADDR , DIRECT, 
		"9d;[1=];" },
/* JSR 132 */   { ADDR , EXTENDED, 
		"bd;[1=]x" },
/* JSR 133 */   { 0 , 0, 
		"ad;" },
/* LBCC 134 */   { 0 , 0, 
		"10;24;[1=].Q.2+-.ffff&x" },
/* LBCS 135 */   { 0 , 0, 
		"10;25;[1=].Q.2+-.ffff&x" },
/* LBEQ 136 */   { 0 , 0, 
		"10;27;[1=].Q.2+-.ffff&x" },
/* LBGE 137 */   { 0 , 0, 
		"10;2c;[1=].Q.2+-.ffff&x" },
/* LBGT 138 */   { 0 , 0, 
		"10;2e;[1=].Q.2+-.ffff&x" },
/* LBHI 139 */   { 0 , 0, 
		"10;22;[1=].Q.2+-.ffff&x" },
/* LBHS 140 */   { 0 , 0, 
		"10;24;[1=].Q.2+-.ffff&x" },
/* LBLE 141 */   { 0 , 0, 
		"10;2f;[1=].Q.2+-.ffff&x" },
/* LBLO 142 */   { 0 , 0, 
		"10;25;[1=].Q.2+-.ffff&x" },
/* LBLS 143 */   { 0 , 0, 
		"10;23;[1=].Q.2+-.ffff&x" },
/* LBLT 144 */   { 0 , 0, 
		"10;2d;[1=].Q.2+-.ffff&x" },
/* LBMI 145 */   { 0 , 0, 
		"10;2b;[1=].Q.2+-.ffff&x" },
/* LBNE 146 */   { 0 , 0, 
		"10;26;[1=].Q.2+-.ffff&x" },
/* LBPL 147 */   { 0 , 0, 
		"10;2a;[1=].Q.2+-.ffff&x" },
/* LBRA 148 */   { 0 , 0, 
		"16;[1=].Q.2+-.ffff&x" },
/* LBRN 149 */   { 0 , 0, 
		"10;21;[1=].Q.2+-.ffff&x" },
/* LBSR 150 */   { 0 , 0, 
		"17;[1=].Q.2+-.ffff&x" },
/* LBVC 151 */   { 0 , 0, 
		"10;28;[1=].Q.2+-.ffff&x" },
/* LBVS 152 */   { 0 , 0, 
		"10;29;[1=].Q.2+-.ffff&x" },
/* LDA 153 */   { ADDR , DIRECT, 
		"96;[1=];" },
/* LDA 154 */   { ADDR , EXTENDED, 
		"b6;[1=]x" },
/* LDA 155 */   { 0 , 0, 
		"86;[1=];" },
/* LDA 156 */   { 0 , 0, 
		"a6;" },
/* LDB 157 */   { ADDR , DIRECT, 
		"d6;[1=];" },
/* LDB 158 */   { ADDR , EXTENDED, 
		"f6;[1=]x" },
/* LDB 159 */   { 0 , 0, 
		"c6;[1=];" },
/* LDB 160 */   { 0 , 0, 
		"e6;" },
/* LDD 161 */   { ADDR , DIRECT, 
		"dc;[1=];" },
/* LDD 162 */   { ADDR , EXTENDED, 
		"fc;[1=]x" },
/* LDD 163 */   { 0 , 0, 
		"cc;[1=]x" },
/* LDD 164 */   { 0 , 0, 
		"ec;" },
/* LDS 165 */   { ADDR , DIRECT, 
		"10;de;[1=];" },
/* LDS 166 */   { ADDR , EXTENDED, 
		"10;fe;[1=]x" },
/* LDS 167 */   { 0 , 0, 
		"10;ce;[1=]x" },
/* LDS 168 */   { 0 , 0, 
		"10;ee;" },
/* LDU 169 */   { ADDR , DIRECT, 
		"de;[1=];" },
/* LDU 170 */   { ADDR , EXTENDED, 
		"fe;[1=]x" },
/* LDU 171 */   { 0 , 0, 
		"ce;[1=]x" },
/* LDU 172 */   { 0 , 0, 
		"ee;" },
/* LDX 173 */   { ADDR , DIRECT, 
		"9e;[1=];" },
/* LDX 174 */   { ADDR , EXTENDED, 
		"be;[1=]x" },
/* LDX 175 */   { 0 , 0, 
		"8e;[1=]x" },
/* LDX 176 */   { 0 , 0, 
		"ae;" },
/* LDY 177 */   { ADDR , DIRECT, 
		"10;9e;[1=];" },
/* LDY 178 */   { ADDR , EXTENDED, 
		"10;be;[1=]x" },
/* LDY 179 */   { 0 , 0, 
		"10;8e;[1=]x" },
/* LDY 180 */   { 0 , 0, 
		"10;ae;" },
/* LEAS 181 */   { 0 , 0, 
		"32;" },
/* LEAU 182 */   { 0 , 0, 
		"33;" },
/* LEAX 183 */   { 0 , 0, 
		"30;" },
/* LEAY 184 */   { 0 , 0, 
		"31;" },
/* LSL 185 */   { ADDR , DIRECT, 
		"08;[1=];" },
/* LSL 186 */   { ADDR , EXTENDED, 
		"78;[1=]x" },
/* LSL 187 */   { 0 , 0, 
		"68;" },
/* LSLA 188 */   { 0 , 0, 
		"48;" },
/* LSLB 189 */   { 0 , 0, 
		"58;" },
/* LSR 190 */   { ADDR , DIRECT, 
		"04;[1=];" },
/* LSR 191 */   { ADDR , EXTENDED, 
		"74;[1=]x" },
/* LSR 192 */   { 0 , 0, 
		"64;" },
/* LSRA 193 */   { 0 , 0, 
		"44;" },
/* LSRB 194 */   { 0 , 0, 
		"54;" },
/* MUL 195 */   { 0 , 0, 
		"3d;" },
/* NEG 196 */   { ADDR , DIRECT, 
		"00;[1=];" },
/* NEG 197 */   { ADDR , EXTENDED, 
		"70;[1=]x" },
/* NEG 198 */   { 0 , 0, 
		"60;" },
/* NEGA 199 */   { 0 , 0, 
		"40;" },
/* NEGB 200 */   { 0 , 0, 
		"50;" },
/* NOP 201 */   { 0 , 0, 
		"12;" },
/* ORA 202 */   { ADDR , DIRECT, 
		"9a;[1=];" },
/* ORA 203 */   { ADDR , EXTENDED, 
		"ba;[1=]x" },
/* ORA 204 */   { 0 , 0, 
		"8a;[1=];" },
/* ORA 205 */   { 0 , 0, 
		"aa;" },
/* ORB 206 */   { ADDR , DIRECT, 
		"da;[1=];" },
/* ORB 207 */   { ADDR , EXTENDED, 
		"fa;[1=]x" },
/* ORB 208 */   { 0 , 0, 
		"ca;[1=];" },
/* ORB 209 */   { 0 , 0, 
		"ea;" },
/* ORCC 210 */   { 0 , 0, 
		"1a;[1=];" },
/* PSHS 211 */   { 0 , 0, 
		"34;[1#];" },
/* PSHU 212 */   { 0 , 0, 
		"36;[1#];" },
/* PULS 213 */   { 0 , 0, 
		"35;[1#];" },
/* PULU 214 */   { 0 , 0, 
		"37;[1#];" },
/* ROL 215 */   { ADDR , DIRECT, 
		"09;[1=];" },
/* ROL 216 */   { ADDR , EXTENDED, 
		"79;[1=]x" },
/* ROL 217 */   { 0 , 0, 
		"69;" },
/* ROLA 218 */   { 0 , 0, 
		"49;" },
/* ROLB 219 */   { 0 , 0, 
		"59;" },
/* ROR 220 */   { ADDR , DIRECT, 
		"06;[1=];" },
/* ROR 221 */   { ADDR , EXTENDED, 
		"76;[1=]x" },
/* ROR 222 */   { 0 , 0, 
		"66;" },
/* RORA 223 */   { 0 , 0, 
		"46;" },
/* RORB 224 */   { 0 , 0, 
		"56;" },
/* RTI 225 */   { 0 , 0, 
		"3b;" },
/* RTS 226 */   { 0 , 0, 
		"39;" },
/* SBCA 227 */   { ADDR , DIRECT, 
		"92;[1=];" },
/* SBCA 228 */   { ADDR , EXTENDED, 
		"b2;[1=]x" },
/* SBCA 229 */   { 0 , 0, 
		"82;[1=];" },
/* SBCA 230 */   { 0 , 0, 
		"a2;" },
/* SBCB 231 */   { ADDR , DIRECT, 
		"d2;[1=];" },
/* SBCB 232 */   { ADDR , EXTENDED, 
		"f2;[1=]x" },
/* SBCB 233 */   { 0 , 0, 
		"c2;[1=];" },
/* SBCB 234 */   { 0 , 0, 
		"e2;" },
/* SEX 235 */   { 0 , 0, 
		"1d;" },
/* STA 236 */   { ADDR , DIRECT, 
		"97;[1=];" },
/* STA 237 */   { ADDR , EXTENDED, 
		"b7;[1=]x" },
/* STA 238 */   { 0 , 0, 
		"a7;" },
/* STB 239 */   { ADDR , DIRECT, 
		"d7;[1=];" },
/* STB 240 */   { ADDR , EXTENDED, 
		"f7;[1=]x" },
/* STB 241 */   { 0 , 0, 
		"e7;" },
/* STD 242 */   { ADDR , DIRECT, 
		"dd;[1=];" },
/* STD 243 */   { ADDR , EXTENDED, 
		"fd;[1=]x" },
/* STD 244 */   { 0 , 0, 
		"ed;" },
/* STS 245 */   { ADDR , DIRECT, 
		"10;df;[1=];" },
/* STS 246 */   { ADDR , EXTENDED, 
		"10;ff;[1=]x" },
/* STS 247 */   { 0 , 0, 
		"10;ef;" },
/* STU 248 */   { ADDR , DIRECT, 
		"df;[1=];" },
/* STU 249 */   { ADDR , EXTENDED, 
		"ff;[1=]x" },
/* STU 250 */   { 0 , 0, 
		"ef;" },
/* STX 251 */   { ADDR , DIRECT, 
		"9f;[1=];" },
/* STX 252 */   { ADDR , EXTENDED, 
		"bf;[1=]x" },
/* STX 253 */   { 0 , 0, 
		"af;" },
/* STY 254 */   { ADDR , DIRECT, 
		"10;9f;[1=];" },
/* STY 255 */   { ADDR , EXTENDED, 
		"10;bf;[1=]x" },
/* STY 256 */   { 0 , 0, 
		"10;af;" },
/* SUBA 257 */   { ADDR , DIRECT, 
		"90;[1=];" },
/* SUBA 258 */   { ADDR , EXTENDED, 
		"b0;[1=]x" },
/* SUBA 259 */   { 0 , 0, 
		"80;[1=];" },
/* SUBA 260 */   { 0 , 0, 
		"a0;" },
/* SUBB 261 */   { ADDR , DIRECT, 
		"d0;[1=];" },
/* SUBB 262 */   { ADDR , EXTENDED, 
		"f0;[1=]x" },
/* SUBB 263 */   { 0 , 0, 
		"c0;[1=];" },
/* SUBB 264 */   { 0 , 0, 
		"e0;" },
/* SUBD 265 */   { ADDR , DIRECT, 
		"93;[1=];" },
/* SUBD 266 */   { ADDR , EXTENDED, 
		"b3;[1=]x" },
/* SUBD 267 */   { 0 , 0, 
		"83;[1=]x" },
/* SUBD 268 */   { 0 , 0, 
		"a3;" },
/* SWI2 269 */   { 0 , 0, 
		"10;3f;" },
/* SWI3 270 */   { 0 , 0, 
		"11;3f;" },
/* SWI 271 */   { 0 , 0, 
		"3f;" },
/* SYNC 272 */   { 0 , 0, 
		"13;" },
/* TFR 273 */   { 0 , 0, 
		"1f;[1#2#];" },
/* TST 274 */   { ADDR , DIRECT, 
		"0d;[1=];" },
/* TST 275 */   { ADDR , EXTENDED, 
		"7d;[1=]x" },
/* TST 276 */   { 0 , 0, 
		"6d;" },
/* TSTA 277 */   { 0 , 0, 
		"4d;" },
/* TSTB 278 */   { 0 , 0, 
		"5d;" },
	{ 0,0,""} };
/* end fraptabdef.c */
#line 1631 "y.tab.c"
#define YYABORT goto yyabort
#define YYREJECT goto yyabort
#define YYACCEPT goto yyaccept
#define YYERROR goto yyerrlab
int
yyparse()
{
    register int yym, yyn, yystate;
#if YYDEBUG
    register char *yys;
    extern char *getenv();

    if (yys = getenv("YYDEBUG"))
    {
        yyn = *yys;
        if (yyn >= '0' && yyn <= '9')
            yydebug = yyn - '0';
    }
#endif

    yynerrs = 0;
    yyerrflag = 0;
    yychar = (-1);

    yyssp = yyss;
    yyvsp = yyvs;
    *yyssp = yystate = 0;

yyloop:
    if (yyn = yydefred[yystate]) goto yyreduce;
    if (yychar < 0)
    {
        if ((yychar = yylex()) < 0) yychar = 0;
#if YYDEBUG
        if (yydebug)
        {
            yys = 0;
            if (yychar <= YYMAXTOKEN) yys = yyname[yychar];
            if (!yys) yys = "illegal-symbol";
            printf("%sdebug: state %d, reading %d (%s)\n",
                    YYPREFIX, yystate, yychar, yys);
        }
#endif
    }
    if ((yyn = yysindex[yystate]) && (yyn += yychar) >= 0 &&
            yyn <= YYTABLESIZE && yycheck[yyn] == yychar)
    {
#if YYDEBUG
        if (yydebug)
            printf("%sdebug: state %d, shifting to state %d\n",
                    YYPREFIX, yystate, yytable[yyn]);
#endif
        if (yyssp >= yyss + yystacksize - 1)
        {
            goto yyoverflow;
        }
        *++yyssp = yystate = yytable[yyn];
        *++yyvsp = yylval;
        yychar = (-1);
        if (yyerrflag > 0)  --yyerrflag;
        goto yyloop;
    }
    if ((yyn = yyrindex[yystate]) && (yyn += yychar) >= 0 &&
            yyn <= YYTABLESIZE && yycheck[yyn] == yychar)
    {
        yyn = yytable[yyn];
        goto yyreduce;
    }
    if (yyerrflag) goto yyinrecovery;
#ifdef lint
    goto yynewerror;
#endif
yynewerror:
    yyerror("syntax error");
#ifdef lint
    goto yyerrlab;
#endif
yyerrlab:
    ++yynerrs;
yyinrecovery:
    if (yyerrflag < 3)
    {
        yyerrflag = 3;
        for (;;)
        {
            if ((yyn = yysindex[*yyssp]) && (yyn += YYERRCODE) >= 0 &&
                    yyn <= YYTABLESIZE && yycheck[yyn] == YYERRCODE)
            {
#if YYDEBUG
                if (yydebug)
                    printf("%sdebug: state %d, error recovery shifting\
 to state %d\n", YYPREFIX, *yyssp, yytable[yyn]);
#endif
                if (yyssp >= yyss + yystacksize - 1)
                {
                    goto yyoverflow;
                }
                *++yyssp = yystate = yytable[yyn];
                *++yyvsp = yylval;
                goto yyloop;
            }
            else
            {
#if YYDEBUG
                if (yydebug)
                    printf("%sdebug: error recovery discarding state %d\n",
                            YYPREFIX, *yyssp);
#endif
                if (yyssp <= yyss) goto yyabort;
                --yyssp;
                --yyvsp;
            }
        }
    }
    else
    {
        if (yychar == 0) goto yyabort;
#if YYDEBUG
        if (yydebug)
        {
            yys = 0;
            if (yychar <= YYMAXTOKEN) yys = yyname[yychar];
            if (!yys) yys = "illegal-symbol";
            printf("%sdebug: state %d, error recovery discards token %d (%s)\n",
                    YYPREFIX, yystate, yychar, yys);
        }
#endif
        yychar = (-1);
        goto yyloop;
    }
yyreduce:
#if YYDEBUG
    if (yydebug)
        printf("%sdebug: state %d, reducing by rule %d (%s)\n",
                YYPREFIX, yystate, yyn, yyrule[yyn]);
#endif
    yym = yylen[yyn];
    yyval = yyvsp[1-yym];
    switch (yyn)
    {
case 3:
#line 222 "as6809.y"
{
				clrexpr();
			}
break;
case 5:
#line 227 "as6809.y"
{
				clrexpr();
				yyerrok;
			}
break;
case 6:
#line 234 "as6809.y"
{
				endsymbol = yyvsp[-1].symb;
				nextreadact = Nra_end;
			}
break;
case 7:
#line 239 "as6809.y"
{
				nextreadact = Nra_end;
			}
break;
case 8:
#line 243 "as6809.y"
{
		if(nextfstk >= FILESTKDPTH)
		{
			fraerror("include file nesting limit exceeded");
		}
		else
		{
			infilestk[nextfstk].fnm = savestring(yyvsp[0].strng,strlen(yyvsp[0].strng));
			if( (infilestk[nextfstk].fpt = fopen(yyvsp[0].strng,"r"))
				==(FILE *)NULL )
			{
				fraerror("cannot open include file");
			}
			else
			{
				nextreadact = Nra_new;
			}
		}
			}
break;
case 9:
#line 263 "as6809.y"
{
				if(yyvsp[-2].symb -> seg == SSG_UNDEF)
				{
					pevalexpr(0, yyvsp[0].intv);
					if(evalr[0].seg == SSG_ABS)
					{
						yyvsp[-2].symb -> seg = SSG_EQU;
						yyvsp[-2].symb -> value = evalr[0].value;
						prtequvalue("C: 0x%lx\n",
							evalr[0].value);
					}
					else
					{
						fraerror(
					"noncomputable expression for EQU");
					}
				}
				else
				{
					fraerror(
				"cannot change symbol value with EQU");
				}
			}
break;
case 10:
#line 287 "as6809.y"
{
				if(yyvsp[-2].symb -> seg == SSG_UNDEF
				   || yyvsp[-2].symb -> seg == SSG_SET)
				{
					pevalexpr(0, yyvsp[0].intv);
					if(evalr[0].seg == SSG_ABS)
					{
						yyvsp[-2].symb -> seg = SSG_SET;
						yyvsp[-2].symb -> value = evalr[0].value;
						prtequvalue("C: 0x%lx\n",
							evalr[0].value);
					}
					else
					{
						fraerror(
					"noncomputable expression for SET");
					}
				}
				else
				{
					fraerror(
				"cannot change symbol value with SET");
				}
			}
break;
case 11:
#line 312 "as6809.y"
{
		if((++ifstkpt) < IFSTKDEPTH)
		{
			pevalexpr(0, yyvsp[0].intv);
			if(evalr[0].seg == SSG_ABS)
			{
				if(evalr[0].value != 0)
				{
					elseifstk[ifstkpt] = If_Skip;
					endifstk[ifstkpt] = If_Active;
				}
				else
				{
					fraifskip = TRUE;
					elseifstk[ifstkpt] = If_Active;
					endifstk[ifstkpt] = If_Active;
				}
			}
			else
			{
				fraifskip = TRUE;
				elseifstk[ifstkpt] = If_Active;
				endifstk[ifstkpt] = If_Active;
			}
		}
		else
		{
			fraerror("IF stack overflow");
		}
			}
break;
case 12:
#line 344 "as6809.y"
{
		if(fraifskip) 
		{
			if((++ifstkpt) < IFSTKDEPTH)
			{
					elseifstk[ifstkpt] = If_Skip;
					endifstk[ifstkpt] = If_Skip;
			}
			else
			{
				fraerror("IF stack overflow");
			}
		}
		else
		{
			yyerror("syntax error");
			YYERROR;
		}
				}
break;
case 13:
#line 365 "as6809.y"
{
				switch(elseifstk[ifstkpt])
				{
				case If_Active:
					fraifskip = FALSE;
					break;
				
				case If_Skip:
					fraifskip = TRUE;
					break;
				
				case If_Err:
					fraerror("ELSE with no matching if");
					break;
				}
			}
break;
case 14:
#line 383 "as6809.y"
{
				switch(endifstk[ifstkpt])
				{
				case If_Active:
					fraifskip = FALSE;
					ifstkpt--;
					break;
				
				case If_Skip:
					fraifskip = TRUE;
					ifstkpt--;
					break;
				
				case If_Err:
					fraerror("ENDI with no matching if");
					break;
				}
			}
break;
case 15:
#line 402 "as6809.y"
{
				pevalexpr(0, yyvsp[0].intv);
				if(evalr[0].seg == SSG_ABS)
				{
					locctr = labelloc = evalr[0].value;
					if(yyvsp[-2].symb -> seg == SSG_UNDEF)
					{
						yyvsp[-2].symb -> seg = SSG_ABS;
						yyvsp[-2].symb -> value = labelloc;
					}
					else
						fraerror(
						"multiple definition of label");
					prtequvalue("C: 0x%lx\n",
						evalr[0].value);
				}
				else
				{
					fraerror(
					 "noncomputable expression for ORG");
				}
			}
break;
case 16:
#line 425 "as6809.y"
{
				pevalexpr(0, yyvsp[0].intv);
				if(evalr[0].seg == SSG_ABS)
				{
					locctr = labelloc = evalr[0].value;
					prtequvalue("C: 0x%lx\n",
						evalr[0].value);
				}
				else
				{
					fraerror(
					 "noncomputable expression for ORG");
				}
			}
break;
case 17:
#line 440 "as6809.y"
{
				if(yyvsp[-1].symb -> seg == SSG_UNDEF)
				{
					yyvsp[-1].symb -> seg = SSG_EQU;
					if( (yyvsp[-1].symb->value = chtcreate()) <= 0)
					{
		fraerror( "cannot create character translation table");
					}
					prtequvalue("C: 0x%lx\n", yyvsp[-1].symb -> value);
				}
				else
				{
			fraerror( "multiple definition of label");
				}
			}
break;
case 18:
#line 456 "as6809.y"
{
				chtcpoint = (int *) NULL;
				prtequvalue("C: 0x%lx\n", 0L);
			}
break;
case 19:
#line 461 "as6809.y"
{
				pevalexpr(0, yyvsp[0].intv);
				if( evalr[0].seg == SSG_ABS)
				{
					if( evalr[0].value == 0)
					{
						chtcpoint = (int *)NULL;
						prtequvalue("C: 0x%lx\n", 0L);
					}
					else if(evalr[0].value < chtnxalph)
					{
				chtcpoint = chtatab[evalr[0].value];
				prtequvalue("C: 0x%lx\n", evalr[0].value);
					}
					else
					{
			fraerror("nonexistent character translation table");
					}
				}
				else
				{
					fraerror("noncomputable expression");
				}
			}
break;
case 20:
#line 486 "as6809.y"
{
		int findrv, numret, *charaddr;
		char *sourcestr = yyvsp[-2].strng, *before;

		if(chtnpoint != (int *)NULL)
		{
			for(satsub = 0; satsub < yyvsp[0].intv; satsub++)
			{
				before = sourcestr;

				pevalexpr(0, exprlist[satsub]);
				findrv = chtcfind(chtnpoint, &sourcestr,
						&charaddr, &numret);
				if(findrv == CF_END)
				{
			fraerror("more expressions than characters");
					break;
				}

				if(evalr[0].seg == SSG_ABS)
				{
					switch(findrv)
					{
					case CF_UNDEF:
						{
				if(evalr[0].value < 0 ||
					evalr[0].value > 255)
				{
			frawarn("character translation value truncated");
				}
				*charaddr = evalr[0].value & 0xff;
				prtequvalue("C: 0x%lx\n", evalr[0].value);
						}
						break;

					case CF_INVALID:
					case CF_NUMBER:
				fracherror("invalid character to define", 
					before, sourcestr);
						break;

					case CF_CHAR:
				fracherror("character already defined", 
					before, sourcestr);
						break;
					}
				}
				else
				{
					fraerror("noncomputable expression");
				}
			}

			if( *sourcestr != '\0')
			{
				fraerror("more characters than expressions");
			}
		}
		else
		{
			fraerror("no CHARSET statement active");
		}
			
			}
break;
case 21:
#line 551 "as6809.y"
{
			if(yyvsp[0].symb -> seg == SSG_UNDEF)
			{
				yyvsp[0].symb -> seg = SSG_ABS;
				yyvsp[0].symb -> value = labelloc;
				prtequvalue("C: 0x%lx\n", labelloc);

			}
			else
				fraerror(
				"multiple definition of label");
			}
break;
case 23:
#line 567 "as6809.y"
{
			if(yyvsp[-1].symb -> seg == SSG_UNDEF)
			{
				yyvsp[-1].symb -> seg = SSG_ABS;
				yyvsp[-1].symb -> value = labelloc;
			}
			else
				fraerror(
				"multiple definition of label");
			labelloc = locctr;
			}
break;
case 24:
#line 580 "as6809.y"
{
				labelloc = locctr;
			}
break;
case 25:
#line 586 "as6809.y"
{
				genlocrec(currseg, labelloc);
				for( satsub = 0; satsub < yyvsp[0].intv; satsub++)
				{
					pevalexpr(1, exprlist[satsub]);
					locctr += geninstr(genbdef);
				}
			}
break;
case 26:
#line 595 "as6809.y"
{
				genlocrec(currseg, labelloc);
				for(satsub = 0; satsub < yyvsp[0].intv; satsub++)
				{
					locctr += genstring(stringlist[satsub]);
				}
			}
break;
case 27:
#line 603 "as6809.y"
{
				genlocrec(currseg, labelloc);
				for( satsub = 0; satsub < yyvsp[0].intv; satsub++)
				{
					pevalexpr(1, exprlist[satsub]);
					locctr += geninstr(genwdef);
				}
			}
break;
case 28:
#line 612 "as6809.y"
{
				pevalexpr(0, yyvsp[0].intv);
				if(evalr[0].seg == SSG_ABS)
				{
					locctr = labelloc + evalr[0].value;
					prtequvalue("C: 0x%lx\n", labelloc);
				}
				else
				{
					fraerror(
				 "noncomputable result for RMB expression");
				}
			}
break;
case 29:
#line 628 "as6809.y"
{
				exprlist[nextexprs ++ ] = yyvsp[0].intv;
				yyval.intv = nextexprs;
			}
break;
case 30:
#line 633 "as6809.y"
{
				nextexprs = 0;
				exprlist[nextexprs ++ ] = yyvsp[0].intv;
				yyval.intv = nextexprs;
			}
break;
case 31:
#line 641 "as6809.y"
{
				stringlist[nextstrs ++ ] = yyvsp[0].strng;
				yyval.intv = nextstrs;
			}
break;
case 32:
#line 646 "as6809.y"
{
				nextstrs = 0;
				stringlist[nextstrs ++ ] = yyvsp[0].strng;
				yyval.intv = nextstrs;
			}
break;
case 33:
#line 655 "as6809.y"
{
		genlocrec(currseg, labelloc);
		locctr += geninstr(findgen(yyvsp[0].intv, ST_INH, 0));
			}
break;
case 34:
#line 661 "as6809.y"
{
		pevalexpr(1, yyvsp[0].intv);
		genlocrec(currseg, labelloc);
		locctr += geninstr( findgen(yyvsp[-2].intv, ST_IMM, 0));
			}
break;
case 35:
#line 668 "as6809.y"
{
		genlocrec(currseg, labelloc);
		pevalexpr(1, yyvsp[0].intv);
		locctr += geninstr( findgen( yyvsp[-1].intv, ST_EXP, 
				  ( (evalr[1].seg == SSG_ABS 
				&& evalr[1].value >= 0
				&& evalr[1].value <= 255 )
				? DIRECT : EXTENDED ) )
				);
			}
break;
case 36:
#line 680 "as6809.y"
{
		genlocrec(currseg, labelloc);
		locctr += geninstr(findgen(yyvsp[-1].intv, ST_IND, 0));
		locctr += geninstr(yyvsp[0].strng);
			}
break;
case 37:
#line 687 "as6809.y"
{
		genlocrec(currseg, labelloc);
		pevalexpr(1, yyvsp[-2].intv);
		locctr += geninstr(findgen(yyvsp[-3].intv, ST_IND, 0));
		if(evalr[1].seg == SSG_ABS 
			&& (evalr[1].value - locctr) >= PCRNEG8M
			&& (evalr[1].value - locctr) <= PCRPLUS8M)
		{
			locctr += geninstr(PCR8STR);
		}
		else
		{
			locctr += geninstr(PCR16STR);
		}
			}
break;
case 38:
#line 704 "as6809.y"
{
		genlocrec(currseg, labelloc);
		pevalexpr(1, yyvsp[-3].intv);
		locctr += geninstr(findgen(yyvsp[-5].intv, ST_IND, 0));
		if(evalr[1].seg == SSG_ABS 
			&& (evalr[1].value - locctr) >= PCRNEG8M
			&& (evalr[1].value - locctr) <= PCRPLUS8M)
		{
			locctr += geninstr(IPCR8STR);
		}
		else
		{
			locctr += geninstr(IPCR16STR);
		}
			}
break;
case 39:
#line 721 "as6809.y"
{
		genlocrec(currseg, labelloc);
		pevalexpr(1, yyvsp[-1].intv);
		locctr += geninstr(findgen(yyvsp[-3].intv, ST_IND, 0));
		locctr += geninstr(IEXPSTR);
			}
break;
case 40:
#line 729 "as6809.y"
{
		genlocrec(currseg, labelloc);
		if(yyvsp[0].intv & REGBSSTK)
		{
			fraerror("push/pop of system stack register");
			evalr[1].value = 0;
		}
		else
		{
			evalr[1].value = yyvsp[0].intv & 0xff;
		}	
		locctr += geninstr(findgen(yyvsp[-1].intv, ST_SPSH, 0));
			}
break;
case 41:
#line 744 "as6809.y"
{
		genlocrec(currseg, labelloc);
		if(yyvsp[0].intv & REGBUSTK)
		{
			fraerror("push/pop of user stack register");
			evalr[1].value = 0;
		}
		else
		{
			evalr[1].value = yyvsp[0].intv & 0xff;
		}	
		locctr += geninstr(findgen(yyvsp[-1].intv, ST_SPSH, 0));
			}
break;
case 42:
#line 759 "as6809.y"
{
		genlocrec(currseg, labelloc);
		if((yyvsp[-2].intv & TFR8BIT) == (yyvsp[0].intv & TFR8BIT))
		{
			evalr[1].value = yyvsp[-2].intv;
			evalr[2].value = yyvsp[0].intv;
		}
		else
		{
			evalr[1].value = 0;
			evalr[2].value = 0;
			fraerror("operands are different sizes");
		}
		locctr += geninstr(findgen(yyvsp[-3].intv, ST_TFR, 0));
			}
break;
case 43:
#line 776 "as6809.y"
{
		pevalexpr(1, yyvsp[-2].intv);
		if(evalr[1].seg == SSG_ABS
			&& evalr[1].value >= -128
			&& evalr[1].value <= 127 )
		{
			if(evalr[1].value >= -16
			&& evalr[1].value <= 15)
			{
				if(evalr[1].value == 0)
					yyval.strng = indexgen [IDM104] [yyvsp[0].intv - TFRX];
				else
					yyval.strng = indexgen [IDM000] [yyvsp[0].intv - TFRX];
			}
			else
			{
				yyval.strng = indexgen [IDM108] [yyvsp[0].intv - TFRX];
			}
		}
		else
		{
			yyval.strng = indexgen [IDM109] [yyvsp[0].intv - TFRX];
		}
			}
break;
case 44:
#line 802 "as6809.y"
{
		switch(yyvsp[-2].intv)
		{
		case TFRA:
			yyval.strng = indexgen [IDM106] [yyvsp[0].intv - TFRX];
			break;
		case TFRB:
			yyval.strng = indexgen [IDM105] [yyvsp[0].intv - TFRX];
			break;
		case TFRD:
			yyval.strng = indexgen [IDM10B] [yyvsp[0].intv - TFRX];
			break;
		}
			}
break;
case 45:
#line 818 "as6809.y"
{
		yyval.strng = indexgen [IDM104] [yyvsp[0].intv - TFRX];
			}
break;
case 46:
#line 823 "as6809.y"
{
		yyval.strng = indexgen [IDM100] [yyvsp[-1].intv - TFRX];
			}
break;
case 47:
#line 828 "as6809.y"
{
		yyval.strng = indexgen [IDM101] [yyvsp[-2].intv - TFRX];
			}
break;
case 48:
#line 833 "as6809.y"
{
		yyval.strng = indexgen [IDM102] [yyvsp[0].intv - TFRX];
			}
break;
case 49:
#line 838 "as6809.y"
{
		yyval.strng = indexgen [IDM103] [yyvsp[0].intv - TFRX];
			}
break;
case 50:
#line 843 "as6809.y"
{
		pevalexpr(1, yyvsp[-3].intv);
		if(evalr[1].seg == SSG_ABS
			&& evalr[1].value >= -128
			&& evalr[1].value <= 127 )
		{
			if(evalr[1].value == 0)
				yyval.strng = indexgen [IDM114] [yyvsp[-1].intv - TFRX];
			else
				yyval.strng = indexgen [IDM118] [yyvsp[-1].intv - TFRX];
		}
		else
		{
			yyval.strng = indexgen [IDM119] [yyvsp[-1].intv - TFRX];
		}
			}
break;
case 51:
#line 861 "as6809.y"
{
		switch(yyvsp[-3].intv)
		{
		case TFRA:
			yyval.strng = indexgen [IDM116] [yyvsp[-1].intv - TFRX];
			break;
		case TFRB:
			yyval.strng = indexgen [IDM115] [yyvsp[-1].intv - TFRX];
			break;
		case TFRD:
			yyval.strng = indexgen [IDM11B] [yyvsp[-1].intv - TFRX];
			break;
		}
			}
break;
case 52:
#line 877 "as6809.y"
{
		yyval.strng = indexgen [IDM114] [yyvsp[-1].intv - TFRX];
			}
break;
case 53:
#line 882 "as6809.y"
{
		yyval.strng = indexgen [IDM111] [yyvsp[-3].intv - TFRX];
			}
break;
case 54:
#line 887 "as6809.y"
{
		yyval.strng = indexgen [IDM113] [yyvsp[-1].intv - TFRX];
			}
break;
case 55:
#line 893 "as6809.y"
{
		switch(yyvsp[0].intv)
		{
		case TFRD:
			yyval.intv = yyvsp[-2].intv |  (PPOSTA | PPOSTB);
			break;
		case TFRX:
			yyval.intv = yyvsp[-2].intv |  PPOSTX;
			break;
		case TFRY:
			yyval.intv = yyvsp[-2].intv |  PPOSTY;
			break;
		case TFRU:
			yyval.intv = yyvsp[-2].intv |  PPOSTU;
			break;
		case TFRS:
			yyval.intv = yyvsp[-2].intv |  PPOSTS;
			break;
		case TFRPC:
			yyval.intv = yyvsp[-2].intv |  PPOSTPC;
			break;
		case TFRA:
			yyval.intv = yyvsp[-2].intv |  PPOSTA;
			break;
		case TFRB:
			yyval.intv = yyvsp[-2].intv |  PPOSTB;
			break;
		case TFRCC:
			yyval.intv = yyvsp[-2].intv |  PPOSTCC;
			break;
		case TFRDP:
			yyval.intv = yyvsp[-2].intv |  PPOSTDP;
			break;
		}
			}
break;
case 56:
#line 929 "as6809.y"
{
		switch(yyvsp[0].intv)
		{
		case TFRD:
			yyval.intv = (PPOSTA | PPOSTB);
			break;
		case TFRX:
			yyval.intv = PPOSTX;
			break;
		case TFRY:
			yyval.intv = PPOSTY;
			break;
		case TFRU:
			yyval.intv = PPOSTU;
			break;
		case TFRS:
			yyval.intv = PPOSTS;
			break;
		case TFRPC:
			yyval.intv = PPOSTPC;
			break;
		case TFRA:
			yyval.intv = PPOSTA;
			break;
		case TFRB:
			yyval.intv = PPOSTB;
			break;
		case TFRCC:
			yyval.intv = PPOSTCC;
			break;
		case TFRDP:
			yyval.intv = PPOSTDP;
			break;
		}
			}
break;
case 60:
#line 971 "as6809.y"
{
				yyval.intv = yyvsp[0].intv;
			}
break;
case 61:
#line 975 "as6809.y"
{
				yyval.intv = exprnode(PCCASE_UN,yyvsp[0].intv,IFC_NEG,0,0L,
					SYMNULL);
			}
break;
case 62:
#line 980 "as6809.y"
{
				yyval.intv = exprnode(PCCASE_UN,yyvsp[0].intv,IFC_NOT,0,0L,
					SYMNULL);
			}
break;
case 63:
#line 985 "as6809.y"
{
				yyval.intv = exprnode(PCCASE_UN,yyvsp[0].intv,IFC_HIGH,0,0L,
					SYMNULL);
			}
break;
case 64:
#line 990 "as6809.y"
{
				yyval.intv = exprnode(PCCASE_UN,yyvsp[0].intv,IFC_LOW,0,0L,
					SYMNULL);
			}
break;
case 65:
#line 995 "as6809.y"
{
				yyval.intv = exprnode(PCCASE_BIN,yyvsp[-2].intv,IFC_MUL,yyvsp[0].intv,0L,
					SYMNULL);
			}
break;
case 66:
#line 1000 "as6809.y"
{
				yyval.intv = exprnode(PCCASE_BIN,yyvsp[-2].intv,IFC_DIV,yyvsp[0].intv,0L,
					SYMNULL);
			}
break;
case 67:
#line 1005 "as6809.y"
{
				yyval.intv = exprnode(PCCASE_BIN,yyvsp[-2].intv,IFC_ADD,yyvsp[0].intv,0L,
					SYMNULL);
			}
break;
case 68:
#line 1010 "as6809.y"
{
				yyval.intv = exprnode(PCCASE_BIN,yyvsp[-2].intv,IFC_SUB,yyvsp[0].intv,0L,
					SYMNULL);
			}
break;
case 69:
#line 1015 "as6809.y"
{
				yyval.intv = exprnode(PCCASE_BIN,yyvsp[-2].intv,IFC_MOD,yyvsp[0].intv,0L,
					SYMNULL);
			}
break;
case 70:
#line 1020 "as6809.y"
{
				yyval.intv = exprnode(PCCASE_BIN,yyvsp[-2].intv,IFC_SHL,yyvsp[0].intv,0L,
					SYMNULL);
			}
break;
case 71:
#line 1025 "as6809.y"
{
				yyval.intv = exprnode(PCCASE_BIN,yyvsp[-2].intv,IFC_SHR,yyvsp[0].intv,0L,
					SYMNULL);
			}
break;
case 72:
#line 1030 "as6809.y"
{
				yyval.intv = exprnode(PCCASE_BIN,yyvsp[-2].intv,IFC_GT,yyvsp[0].intv,0L,
					SYMNULL);
			}
break;
case 73:
#line 1035 "as6809.y"
{
				yyval.intv = exprnode(PCCASE_BIN,yyvsp[-2].intv,IFC_GE,yyvsp[0].intv,0L,
					SYMNULL);
			}
break;
case 74:
#line 1040 "as6809.y"
{
				yyval.intv = exprnode(PCCASE_BIN,yyvsp[-2].intv,IFC_LT,yyvsp[0].intv,0L,
					SYMNULL);
			}
break;
case 75:
#line 1045 "as6809.y"
{
				yyval.intv = exprnode(PCCASE_BIN,yyvsp[-2].intv,IFC_LE,yyvsp[0].intv,0L,
					SYMNULL);
			}
break;
case 76:
#line 1050 "as6809.y"
{
				yyval.intv = exprnode(PCCASE_BIN,yyvsp[-2].intv,IFC_NE,yyvsp[0].intv,0L,
					SYMNULL);
			}
break;
case 77:
#line 1055 "as6809.y"
{
				yyval.intv = exprnode(PCCASE_BIN,yyvsp[-2].intv,IFC_EQ,yyvsp[0].intv,0L,
					SYMNULL);
			}
break;
case 78:
#line 1060 "as6809.y"
{
				yyval.intv = exprnode(PCCASE_BIN,yyvsp[-2].intv,IFC_AND,yyvsp[0].intv,0L,
					SYMNULL);
			}
break;
case 79:
#line 1065 "as6809.y"
{
				yyval.intv = exprnode(PCCASE_BIN,yyvsp[-2].intv,IFC_OR,yyvsp[0].intv,0L,
					SYMNULL);
			}
break;
case 80:
#line 1070 "as6809.y"
{
				yyval.intv = exprnode(PCCASE_BIN,yyvsp[-2].intv,IFC_XOR,yyvsp[0].intv,0L,
					SYMNULL);
			}
break;
case 81:
#line 1075 "as6809.y"
{
				yyval.intv = exprnode(PCCASE_DEF,0,IGP_DEFINED,0,0L,yyvsp[0].symb);
			}
break;
case 82:
#line 1079 "as6809.y"
{
				yyval.intv = exprnode(PCCASE_SYMB,0,IFC_SYMB,0,0L,yyvsp[0].symb);
			}
break;
case 83:
#line 1083 "as6809.y"
{
				yyval.intv = exprnode(PCCASE_PROGC,0,IFC_PROGCTR,0,
					labelloc, SYMNULL);
			}
break;
case 84:
#line 1088 "as6809.y"
{
				yyval.intv = exprnode(PCCASE_CONS,0,IGP_CONSTANT,0,yyvsp[0].longv,
					SYMNULL);
			}
break;
case 85:
#line 1093 "as6809.y"
{
				char *sourcestr = yyvsp[0].strng;
				long accval = 0;

				if(strlen(yyvsp[0].strng) > 0)
				{
					accval = chtran(&sourcestr);
					if(*sourcestr != '\0')
					{
						accval = (accval << 8) +
							chtran(&sourcestr);
					}

					if( *sourcestr != '\0')
					{
	frawarn("string constant in expression more than 2 characters long");
					}
				}
				yyval.intv = exprnode(PCCASE_CONS, 0, IGP_CONSTANT, 0,
					accval, SYMNULL);
			}
break;
case 86:
#line 1115 "as6809.y"
{
				yyval.intv = yyvsp[-1].intv;
			}
break;
#line 2779 "y.tab.c"
    }
    yyssp -= yym;
    yystate = *yyssp;
    yyvsp -= yym;
    yym = yylhs[yyn];
    if (yystate == 0 && yym == 0)
    {
#if YYDEBUG
        if (yydebug)
            printf("%sdebug: after reduction, shifting from state 0 to\
 state %d\n", YYPREFIX, YYFINAL);
#endif
        yystate = YYFINAL;
        *++yyssp = YYFINAL;
        *++yyvsp = yyval;
        if (yychar < 0)
        {
            if ((yychar = yylex()) < 0) yychar = 0;
#if YYDEBUG
            if (yydebug)
            {
                yys = 0;
                if (yychar <= YYMAXTOKEN) yys = yyname[yychar];
                if (!yys) yys = "illegal-symbol";
                printf("%sdebug: state %d, reading %d (%s)\n",
                        YYPREFIX, YYFINAL, yychar, yys);
            }
#endif
        }
        if (yychar == 0) goto yyaccept;
        goto yyloop;
    }
    if ((yyn = yygindex[yym]) && (yyn += yystate) >= 0 &&
            yyn <= YYTABLESIZE && yycheck[yyn] == yystate)
        yystate = yytable[yyn];
    else
        yystate = yydgoto[yym];
#if YYDEBUG
    if (yydebug)
        printf("%sdebug: after reduction, shifting from state %d \
to state %d\n", YYPREFIX, *yyssp, yystate);
#endif
    if (yyssp >= yyss + yystacksize - 1)
    {
        goto yyoverflow;
    }
    *++yyssp = yystate;
    *++yyvsp = yyval;
    goto yyloop;
yyoverflow:
    yyerror("yacc stack overflow");
yyabort:
    return (1);
yyaccept:
    return (0);
}
