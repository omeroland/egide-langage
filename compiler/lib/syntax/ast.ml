(* Types: see ast.mli for the documentation of every node and the EBNF production it represents. *)

type span = Egide_source.Span.t
type ident = { name : string; span : span }
type path = { segments : ident list; span : span }
type duration_unit = Ns | Us | Ms | S | Min | H
type mode = By_read | Inout | Take | Comptime
type unary_op = Neg | Bit_not | Not

type binary_op =
  | Pipe
  | Or
  | And
  | Bit_or
  | Bit_xor
  | Bit_and
  | Shl
  | Shr
  | Add
  | Sub
  | Mul
  | Div
  | Rem
  | Pow

type cmp_op = Eq | Ne | Lt | Le | Gt | Ge

type assign_op =
  | Simple_assign
  | Add_assign
  | Sub_assign
  | Mul_assign
  | Div_assign
  | Rem_assign
  | Bit_and_assign
  | Bit_or_assign
  | Bit_xor_assign
  | Shl_assign
  | Shr_assign

type literal =
  | Int of string
  | Float of string
  | Duration of { amount : string; unit : duration_unit }
  | String of string
  | Raw_string of string
  | Bytes of string
  | Char of Uchar.t
  | Template of { prefix : ident; parts : template_part list }
  | Bool of bool

and template_part = Text of { text : string; span : span } | Interp of expr
and expr = { expr : expr_desc; span : span }

and expr_desc =
  | Lit of literal
  | Path of path
  | Self
  | Self_type
  | Paren of expr
  | Tuple of expr list
  | List of expr list
  | Set of expr list
  | Map of map_entry list
  | Comprehension of { kind : comp_kind; clauses : comp_clause list }
  | If of { branches : if_branch list; else_ : block option }
  | Match of { scrutinee : expr; arms : case_arm list }
  | Loop of block
  | With of { items : with_item list; body : block }
  | Given of { caps : expr list; body : block }
  | Unsafe of { reason : string; reason_span : span; body : block }
  | Call of { callee : expr; args : arg list }
  | Index of { target : expr; args : gen_arg list }
  | Field of { target : expr; name : ident }
  | Try of expr
  | Unary of { op : unary_op; operand : expr }
  | Binary of { op : binary_op; lhs : expr; rhs : expr }
  | Compare of { first : expr; rest : (cmp_op * expr) list }
  | Range of { lo : expr option; hi : expr option }
  | Range_incl of { lo : expr option; hi : expr }
  | Cond of { cond : expr; then_ : expr; else_ : expr }
  | Lambda of { params : lambda_param list; body : expr }
  | Fn_lit of { params : lambda_param list; ret : ty option; body : block }
  | Trailing_call of {
      callee : expr;
      args : arg list;
      params : lambda_param list;
      ret : ty option;
      body : block;
    }

and map_entry = { key : expr; value : expr; span : span }
and comp_kind = Comp_list of expr | Comp_set of expr | Comp_map of map_entry | Comp_iter of expr

and comp_clause =
  | Comp_for of { pat : pattern; iter : expr; span : span }
  | Comp_if of { cond : expr; span : span }

and if_branch = { cond : expr; body : block; span : span }
and case_arm = { pat : pattern; guard : expr option; body : block; span : span }
and arg = { arg : arg_desc; span : span }

and arg_desc =
  | Arg_plain of { label : ident option; value : expr }
  | Arg_inout of { label : ident option; value : expr }
  | Arg_using of ident * expr

and gen_arg = Ga_expr of expr | Ga_type_only of ty
and bound = { path : path; args : gen_arg list; span : span }
and lambda_param = { mode : mode; name : ident; ty : ty option; span : span }
and block = { stmts : stmt list; span : span }
and stmt = { stmt : stmt_desc; span : span }

and stmt_desc =
  | Expr of expr
  | Let of { pat : pattern; ty : ty option; value : expr; else_ : block option }
  | Var of { name : ident; ty : ty option; value : expr }
  | Comptime_let of { name : ident; ty : ty option; value : expr }
  | Assign of { target : expr; op : assign_op; value : expr }
  | Return of expr option
  | Break of expr option
  | Continue
  | Defer of expr
  | Yield of expr
  | For of { pat : pattern; iter : expr; body : block }
  | While of { cond : expr; body : block }

and with_item = { name : ident option; value : expr; span : span }
and pattern = { pat : pat_desc; span : span }

and pat_desc =
  | Pat_wild
  | Pat_bind of ident
  | Pat_const of path
  | Pat_lit of lit_pattern
  | Pat_range of { lo : lit_pattern; hi : lit_pattern; inclusive : bool }
  | Pat_ctor of { path : path; fields : field_pattern list }
  | Pat_tuple of pattern list
  | Pat_list of list_pattern list
  | Pat_or of pattern list
  | Pat_as of { pat : pattern; name : ident }

and lit_pattern = { negated : bool; lit : literal; span : span }

and field_pattern =
  | Fp_field of { label : ident option; pat : pattern; span : span }
  | Fp_rest of span

and list_pattern = Lp_elem of pattern | Lp_rest of { name : ident option; span : span }
and ty = { ty : ty_desc; span : span }

and ty_desc =
  | Ty_path of { path : path; args : gen_arg list }
  | Ty_tuple of ty list
  | Ty_fn of { params : ty list; ret : ty option; using : bound list }
  | Ty_dyn of bound list
  | Ty_self
  | Ty_optional of ty

and attribute = { name : ident; args : expr list option; span : span }
and generic = { comptime : bool; name : ident; bounds : bound list; span : span }
and param = { mode : mode; kind : param_kind; span : span }
and param_kind = Param_self | Param_named of { name : ident; ty : ty; default : expr option }
and typed_ident = { name : ident; ty : ty; span : span }

and fn_sig = {
  name : ident;
  generics : generic list;
  params : param list;
  ret : ty option;
  using : typed_ident list;
  span : span;
}

and fn_decl = { sig_ : fn_sig; body : block; span : span }

and visibility = Private | Pub | Pub_package

and field = {
  attrs : attribute list;
  vis : visibility;
  name : ident;
  ty : ty;
  default : expr option;
  span : span;
}

and variant = { name : ident; fields : variant_fields; span : span }
and variant_fields = Vf_none | Vf_positional of ty list | Vf_named of typed_ident list
and trait_item = { item : trait_item_desc; span : span }

and trait_item_desc =
  | Ti_sig of fn_sig
  | Ti_fn of fn_decl
  | Ti_type of { name : ident; bound : bound option }

and impl_item = { item : impl_item_desc; span : span }

and impl_item_desc =
  | Ii_fn of { attrs : attribute list; vis : visibility; fn_ : fn_decl }
  | Ii_type of { name : ident; ty : ty }

and decl = { attrs : attribute list; vis : visibility; decl : decl_desc; span : span }

and decl_desc =
  | Fn of fn_decl
  | Struct of { name : ident; generics : generic list; fields : field list }
  | Enum of { name : ident; generics : generic list; variants : variant list }
  | Trait of {
      name : ident;
      generics : generic list;
      supertraits : bound list;
      items : trait_item list;
    }
  | Impl of { generics : generic list; trait_ : ty option; self_ty : ty; items : impl_item list }
  | Type of { name : ident; generics : generic list; def : type_def }
  | Const of { name : ident; ty : ty option; value : expr }

and type_def = Alias of ty | Newtype of { ty : ty; where_ : expr option }

type import_item = { name : ident; alias : ident option; span : span }

type import = { import : import_desc; span : span }

and import_desc =
  | Import of { path : path; form : import_form }
  | Import_go of { package : string; package_span : span; alias : ident }

and import_form = Whole | Alias_as of ident | Items of import_item list

type file = {
  module_path : path;
  imports : import list;
  decls : decl list;
  span : span;
}

(* Equality (the role of [@@deriving eq], see T-0008 Log). Stdlib structural equality is exact here: the tree holds
   only strings, booleans, integers ([Uchar.t], span positions), options, lists, records and constructors, with no
   functional values, no floats (float literals are kept as source text) and no cycles. *)
let equal_file (a : file) b = a = b
let equal_decl (a : decl) b = a = b
let equal_stmt (a : stmt) b = a = b
let equal_block (a : block) b = a = b
let equal_expr (a : expr) b = a = b
let equal_pattern (a : pattern) b = a = b
let equal_ty (a : ty) b = a = b
