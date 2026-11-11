/* ADR-0018 candidate surface syntax B (braces, TS/Rust-shaped): Menhir transcription (scratch, not part of the build).
   Derived from docs/adr/attachments/0013-menhir-check.mly (the ADR-0015 transcription of spec/grammar/egide.ebnf v0.3,
   status quo = option D, 0 conflicts). Expressions, types and patterns are unchanged apart from the points listed
   below; semantic actions are empty and lexer terminals are abstract tokens, as in ADR-0013..0015.
   B differs from D in: no INDENT/DEDENT/ELIF tokens; blocks are `{ ... }`; every logical line ends with NEWLINE under the
   Go-style rule of the ADR (lexer, not in this file; the lexer emits no NEWLINE before `)`, `]` or `}`, so a line
   break after the last element needs no trailing comma); `nl_seq(X)` is a NEWLINE-separated list; a `case` arm body is a statement list that ends at the next `case` or `}` (`arm_body`);
   `else if` replaces `elif`; `case` arms hold a statement list; a range without an upper bound
   (`a..`, `..`) is allowed only inside `[ ]` and `( )` (`open_range`): anywhere else it conflicts with a block brace
   (`for i in 0.. {`).
   Run:  python3 -I docs/adr/attachments/0018-check.py   (conflict counts and the parse of the annex programs)
         menhir --explain <this file>                    -> .conflicts file (menhir then stops: untyped nonterminals) */
%token <string> IDENT INT FLOAT DURATION STRING RAW_STRING BYTES CHAR TEMPLATE
%token NEWLINE EOF
%token MODULE IMPORT GO FN STRUCT ENUM TRAIT IMPL TYPE LET VAR COMPTIME PUB RETURN BREAK CONTINUE DEFER YIELD
%token MATCH CASE IF ELSE FOR IN WHILE LOOP WITH GIVEN UNSAFE NOT AND OR SELF SELFT DYN NEW WHERE AS TRUE FALSE
%token INOUT TAKE USING
%token LPAREN RPAREN LBRACKET RBRACKET LBRACE RBRACE COMMA COLON DOT DOTDOT DOTDOTEQ QUESTION AT AMP
%token EQ PLUSEQ MINUSEQ STAREQ SLASHEQ PERCENTEQ AMPEQ PIPEEQ CARETEQ SHLEQ SHREQ
%token ARROW FATARROW PIPEGT PLUS MINUS STAR SLASH PERCENT STARSTAR EQEQ NEQ LT LE GT GE PIPE CARET TILDE SHL SHR
%start <unit> file
%%

file: module_decl NEWLINE list(terminated(import_decl, NEWLINE)) list(top_decl) EOF {}
module_decl: MODULE path {}
path: IDENT {} | path DOT IDENT {}
import_decl: IMPORT path {}
  | IMPORT path DOT LBRACE tcl(import_item) RBRACE {}
  | IMPORT path AS IDENT {}
  | IMPORT GO STRING AS IDENT {}
import_item: IDENT option(preceded(AS, IDENT)) {}

top_decl: list(terminated(attribute, NEWLINE)) top_body NEWLINE {}
top_body: option(visibility) item_decl {} | impl_decl {}
item_decl: fn_decl | struct_decl | enum_decl | trait_decl | type_decl | const_decl {}
visibility: PUB option(delimited(LPAREN, IDENT, RPAREN)) {}
attribute: AT IDENT option(delimited(LPAREN, option(expr_list), RPAREN)) {}
fn_decl: fn_sig block {}
fn_sig: FN IDENT option(generics) LPAREN option(params) RPAREN option(preceded(ARROW, ret_type)) option(using_clause) {}
params: self_param {} | self_param COMMA {} | self_param COMMA tcl(param) {}
  | tcl(param) {}
self_param: option(mode2) SELF {}
mode2: INOUT | TAKE {}
mode3: INOUT | TAKE | COMPTIME {}
param: option(mode3) IDENT COLON ty option(preceded(EQ, expr)) {}
using_clause: USING separated_nonempty_list(COMMA, cap_param) {}
cap_param: IDENT COLON ty {}
generics: LBRACKET separated_nonempty_list(COMMA, generic) RBRACKET {}
generic: option(COMPTIME) IDENT option(preceded(COLON, bounds)) {}
bounds: bound {} | bounds PLUS bound {}
bound: path option(delimited(LBRACKET, gen_args, RBRACKET)) {}
struct_decl: STRUCT IDENT option(generics) {}
  | STRUCT IDENT option(generics) LBRACE nl_seq(field) RBRACE {}
field: list(terminated(attribute, NEWLINE)) option(visibility) IDENT COLON ty option(preceded(EQ, expr)) {}
enum_decl: ENUM IDENT option(generics) LBRACE nl_seq(variant) RBRACE {}
variant: IDENT option(delimited(LPAREN, variant_fields, RPAREN)) {}
variant_fields: separated_nonempty_list(COMMA, ty) {} | separated_nonempty_list(COMMA, named_field) {}
named_field: IDENT COLON ty {}
trait_decl: TRAIT IDENT option(generics) option(preceded(COLON, bounds)) LBRACE nl_seq(trait_item) RBRACE {}
trait_item: fn_sig {} | fn_decl {} | TYPE IDENT option(preceded(COLON, bound)) {}
impl_decl: IMPL option(generics) ty impl_rest {}
impl_rest: LBRACE nl_seq(impl_item) RBRACE {} | FOR ty LBRACE nl_seq(impl_item) RBRACE {} | FOR ty {}
impl_item: list(terminated(attribute, NEWLINE)) option(visibility) fn_decl {} | TYPE IDENT EQ ty {}
type_decl: TYPE IDENT option(generics) EQ NEW ty option(preceded(WHERE, expr)) {}
  | TYPE IDENT option(generics) EQ ty {}
const_decl: LET IDENT option(preceded(COLON, ty)) EQ expr {}
  | LET IDENT option(preceded(COLON, ty)) EQ const_block {}
const_block: if_expr | match_expr | loop_expr | fn_lambda | trailing_call {}
nl_seq(X): X {} | X NEWLINE nl_seq(X) {}
block: LBRACE RBRACE {} | LBRACE nl_seq(stmt) RBRACE {}
stmt: single_stmt {}
  | LET pattern option(preceded(COLON, ty)) EQ expr {}
  | VAR IDENT option(preceded(COLON, ty)) EQ expr {}
  | COMPTIME LET IDENT option(preceded(COLON, ty)) EQ expr {}
  | block_expr {}
  | LET pattern option(preceded(COLON, ty)) EQ block_expr {}
  | LET pattern option(preceded(COLON, ty)) EQ expr ELSE block {}
  | VAR IDENT option(preceded(COLON, ty)) EQ block_expr {}
  | postfix assign_op block_expr {}
  | FOR pattern IN expr block {}
  | WHILE expr block {}
single_stmt: expr {} | postfix assign_op expr {}
  | RETURN option(expr) {} | BREAK option(expr) {} | CONTINUE {} | DEFER expr {} | YIELD expr {}
assign_op: EQ | PLUSEQ | MINUSEQ | STAREQ | SLASHEQ | PERCENTEQ | AMPEQ | PIPEEQ | CARETEQ | SHLEQ | SHREQ {}
block_expr: if_expr | match_expr | loop_expr | with_expr | given_expr | fn_lambda | trailing_call | unsafe_expr {}
if_expr: IF expr block option(else_part) {}
else_part: ELSE block {} | ELSE if_expr {}
match_expr: MATCH expr LBRACE nonempty_list(case_arm) RBRACE {}
case_arm: CASE pattern option(preceded(IF, expr)) COLON arm_body {}
arm_body: stmt {} | stmt NEWLINE {} | stmt NEWLINE arm_body {}
loop_expr: LOOP block {}
with_expr: WITH separated_nonempty_list(COMMA, with_item) block {}
with_item: expr {} | IDENT EQ expr {}
given_expr: GIVEN separated_nonempty_list(COMMA, expr) block {}
fn_head: FN {} | FN LPAREN option(lambda_params) RPAREN option(preceded(ARROW, ret_type)) {}
fn_lambda: fn_head block {}
trailing_call: postfix LPAREN option(args) RPAREN fn_head block {}
unsafe_expr: UNSAFE LPAREN IDENT COLON STRING RPAREN block {}
ty: ret_type | fn_type {}
ret_type: simple_type option(QUESTION) {}
simple_type: path option(delimited(LBRACKET, gen_args, RBRACKET)) {}
  | LPAREN RPAREN {} | LPAREN ty RPAREN {} | LPAREN ty COMMA option(tys_tail) RPAREN {}
  | DYN bounds {} | SELFT {}
tys_tail: tcl(ty) {}
fn_type: FN LPAREN separated_list(COMMA, ty) RPAREN option(preceded(ARROW, ret_type)) option(preceded(USING, bounds)) {}
gen_args: tcl(gen_arg) {}
gen_arg: expr | fn_type | DYN bounds | open_range {}
lambda_params: separated_nonempty_list(COMMA, lambda_param) {}
lambda_param: option(mode2) IDENT option(preceded(COLON, ty)) {}
expr: lambda | pipe {}
lambda: IDENT FATARROW expr {} | paren_form FATARROW expr {}
pipe: cond {} | pipe PIPEGT cond {}
cond: or_e {} | or_e IF or_e ELSE cond {}
or_e: and_e {} | or_e OR and_e {}
and_e: not_e {} | and_e AND not_e {}
not_e: NOT not_e {} | cmp {}
cmp: range {} | cmp cmpop range {}
cmpop: EQEQ | NEQ | LT | LE | GT | GE {}
range: bitor {} | bitor DOTDOT bitor {} | bitor DOTDOTEQ bitor {}
  | DOTDOT bitor {} | DOTDOTEQ bitor {}
open_range: bitor DOTDOT {} | DOTDOT {}
bitor: bitxor {} | bitor PIPE bitxor {}
bitxor: bitand {} | bitxor CARET bitand {}
bitand: shift {} | bitand AMP shift {}
shift: add {} | shift SHL add {} | shift SHR add {}
add: mul {} | add PLUS mul {} | add MINUS mul {}
mul: unary {} | mul STAR unary {} | mul SLASH unary {} | mul PERCENT unary {}
unary: MINUS unary {} | TILDE unary {} | pow {}
pow: postfix {} | postfix STARSTAR unary {}
postfix: primary {} | postfix LPAREN option(args) RPAREN {} | postfix LBRACKET gen_args RBRACKET {}
  | postfix DOT IDENT {} | postfix QUESTION {}
args: tcl(arg) {}
arg: expr {} | AMP postfix {} | IDENT COLON expr {} | IDENT COLON AMP postfix {} | USING IDENT COLON expr {}
primary: literal {} | IDENT {} | SELF {} | SELFT {} | paren_form {}
  | LBRACKET option(expr_list) RBRACKET {} | LBRACKET expr comp_clauses RBRACKET {}
  | LBRACE RBRACE {} | LBRACE map_entries RBRACE {} | LBRACE expr_list RBRACE {}
  | LBRACE map_entry comp_clauses RBRACE {} | LBRACE expr comp_clauses RBRACE {}
paren_form: LPAREN option(cover_list) RPAREN {} | LPAREN expr comp_clauses RPAREN {}
cover_list: tcl(cover_item) {}
cover_item: expr option(preceded(COLON, ty)) {} | open_range {} | mode2 expr option(preceded(COLON, ty)) {}
expr_list: tcl(expr) {}
map_entries: tcl(map_entry) {}
map_entry: expr COLON expr {}
comp_clauses: comp_for list(comp_clause) {}
comp_clause: comp_for {} | IF or_e {}
comp_for: FOR pattern IN or_e {}
literal: INT | FLOAT | DURATION | STRING | RAW_STRING | BYTES | CHAR | TEMPLATE | TRUE | FALSE {}
pattern: or_pat {} | or_pat AS IDENT {}
or_pat: simple_pat {} | or_pat PIPE simple_pat {}
simple_pat: literal_pat {} | range_pat {}
  | path option(delimited(LPAREN, option(field_pats), RPAREN)) {}
  | LPAREN pattern COMMA option(pats_tail) RPAREN {}
  | LBRACKET option(list_pats) RBRACKET {}
pats_tail: tcl(pattern) {}
literal_pat: option(MINUS) num {} | STRING | RAW_STRING | BYTES | CHAR | TRUE | FALSE {}
num: INT | FLOAT | DURATION {}
range_pat: literal_pat DOTDOT literal_pat {} | literal_pat DOTDOTEQ literal_pat {}
field_pats: tcl(field_pat) {}
field_pat: pattern {} | IDENT COLON pattern {} | DOTDOT {}
list_pats: separated_nonempty_list(COMMA, list_pat) {}
list_pat: pattern {} | DOTDOT option(IDENT) {}

tcl(X): X {} | X COMMA {} | X COMMA tcl(X) {}


