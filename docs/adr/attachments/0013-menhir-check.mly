/* ADR-0013 / ADR-0014 / ADR-0015 grammar check (scratch, not part of the build).
   Menhir transcription of spec/grammar/egide.ebnf v0.3-draft (top-level `let` takes const_block, ADR-0017): simplified only in that semantic actions are empty
   and the lexer terminals are abstract tokens. Trailing commas use tcl(X) because `{ "," x } [ "," ]` needs two
   tokens of lookahead in Menhir's list combinators.
   Run:  menhir --explain egide.mly   -> no conflict warning, empty egide.conflicts
   (menhir then stops with "type of every nonterminal unknown": irrelevant, conflicts are reported before that.)
   Interpreter checks:  echo "MODULE IDENT NEWLINE FN IDENT LPAREN RPAREN COLON INDENT LET IDENT EQ INT PLUS MATCH ..." \
     | menhir --interpret egide.mly   (1 + match ...: REJECT, SYN-015) */
%token <string> IDENT INT FLOAT DURATION STRING RAW_STRING BYTES CHAR TEMPLATE
%token NEWLINE INDENT DEDENT EOF
%token MODULE IMPORT GO FN STRUCT ENUM TRAIT IMPL TYPE LET VAR COMPTIME PUB RETURN BREAK CONTINUE DEFER YIELD
%token IF ELIF ELSE MATCH CASE FOR IN WHILE LOOP WITH GIVEN UNSAFE NOT AND OR SELF SELFT DYN NEW WHERE AS TRUE FALSE
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
top_decl: list(terminated(attribute, NEWLINE)) top_body {}
top_body: option(visibility) item_decl {} | impl_decl {}
item_decl: fn_decl | struct_decl | enum_decl | trait_decl | type_decl NEWLINE | const_decl {}
visibility: PUB option(delimited(LPAREN, IDENT, RPAREN)) {}
attribute: AT IDENT option(delimited(LPAREN, option(expr_list), RPAREN)) {}
fn_decl: fn_sig COLON suite {}
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
struct_decl: STRUCT IDENT option(generics) COLON INDENT nonempty_list(terminated(field, NEWLINE)) DEDENT {}
  | STRUCT IDENT option(generics) NEWLINE {}
field: list(terminated(attribute, NEWLINE)) option(visibility) IDENT COLON ty option(preceded(EQ, expr)) {}
enum_decl: ENUM IDENT option(generics) COLON INDENT nonempty_list(terminated(variant, NEWLINE)) DEDENT {}
variant: IDENT option(delimited(LPAREN, variant_fields, RPAREN)) {}
variant_fields: separated_nonempty_list(COMMA, ty) {} | separated_nonempty_list(COMMA, named_field) {}
named_field: IDENT COLON ty {}
trait_decl: TRAIT IDENT option(generics) COLON INDENT nonempty_list(trait_item) DEDENT {}
  | TRAIT IDENT option(generics) COLON bounds COLON INDENT nonempty_list(trait_item) DEDENT {}
trait_item: fn_sig NEWLINE | fn_decl | TYPE IDENT option(preceded(COLON, bound)) NEWLINE {}
impl_decl: IMPL option(generics) ty impl_rest {}
impl_rest: COLON impl_body {} | FOR ty COLON impl_body {} | FOR ty NEWLINE {}
impl_body: INDENT nonempty_list(impl_item) DEDENT {}
impl_item: list(terminated(attribute, NEWLINE)) option(visibility) fn_decl {} | TYPE IDENT EQ ty NEWLINE {}
type_decl: TYPE IDENT option(generics) EQ NEW ty option(preceded(WHERE, expr)) {}
  | TYPE IDENT option(generics) EQ ty {}
const_decl: LET IDENT option(preceded(COLON, ty)) EQ expr NEWLINE {}
  | LET IDENT option(preceded(COLON, ty)) EQ const_block {}
const_block: if_expr | match_expr | loop_expr | fn_lambda | trailing_call {}
ty: ret_type | fn_type {}
ret_type: simple_type option(QUESTION) {}
simple_type: path option(delimited(LBRACKET, gen_args, RBRACKET)) {}
  | LPAREN RPAREN {} | LPAREN ty RPAREN {} | LPAREN ty COMMA option(tys_tail) RPAREN {}
  | DYN bounds {} | SELFT {}
tys_tail: tcl(ty) {}
fn_type: FN LPAREN separated_list(COMMA, ty) RPAREN option(preceded(ARROW, ret_type)) option(preceded(USING, bounds)) {}
gen_args: tcl(gen_arg) {}
gen_arg: expr | fn_type | DYN bounds {}
suite: single_stmt NEWLINE {} | INDENT nonempty_list(stmt) DEDENT {}
stmt: simple_stmt NEWLINE {} | block_stmt {}
single_stmt: expr {} | postfix assign_op expr {}
  | RETURN option(expr) {} | BREAK option(expr) {} | CONTINUE {} | DEFER expr {} | YIELD expr {}
simple_stmt: single_stmt {}
  | LET pattern option(preceded(COLON, ty)) EQ expr {}
  | VAR IDENT option(preceded(COLON, ty)) EQ expr {}
  | COMPTIME LET IDENT option(preceded(COLON, ty)) EQ expr {}
block_stmt: block_expr {}
  | LET pattern option(preceded(COLON, ty)) EQ block_expr {}
  | LET pattern option(preceded(COLON, ty)) EQ expr ELSE COLON suite {}
  | VAR IDENT option(preceded(COLON, ty)) EQ block_expr {}
  | postfix assign_op block_expr {}
  | FOR pattern IN expr COLON suite {}
  | WHILE expr COLON suite {}
assign_op: EQ | PLUSEQ | MINUSEQ | STAREQ | SLASHEQ | PERCENTEQ | AMPEQ | PIPEEQ | CARETEQ | SHLEQ | SHREQ {}
block_expr: if_expr | match_expr | loop_expr | with_expr | given_expr | fn_lambda | trailing_call | unsafe_expr {}
if_expr: IF expr COLON suite list(elif) option(preceded(ELSE, preceded(COLON, suite))) {}
elif: ELIF expr COLON suite {}
match_expr: MATCH expr COLON INDENT nonempty_list(case_arm) DEDENT {}
case_arm: CASE pattern option(preceded(IF, expr)) COLON suite {}
loop_expr: LOOP COLON suite {}
with_expr: WITH separated_nonempty_list(COMMA, with_item) COLON suite {}
with_item: expr {} | IDENT EQ expr {}
given_expr: GIVEN separated_nonempty_list(COMMA, expr) COLON suite {}
fn_head: FN {} | FN LPAREN option(lambda_params) RPAREN option(preceded(ARROW, ret_type)) {}
fn_lambda: fn_head COLON suite {}
trailing_call: postfix LPAREN option(args) RPAREN fn_head COLON suite {}
unsafe_expr: UNSAFE LPAREN IDENT COLON STRING RPAREN COLON suite {}
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
range: bitor {} | bitor DOTDOT {} | bitor DOTDOT bitor {} | bitor DOTDOTEQ bitor {}
  | DOTDOT {} | DOTDOT bitor {} | DOTDOTEQ bitor {}
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
cover_item: expr option(preceded(COLON, ty)) {} | mode2 expr option(preceded(COLON, ty)) {}
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
