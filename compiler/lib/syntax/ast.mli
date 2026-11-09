(** Abstract syntax tree of Égide (spec/03-syntax.md, spec/grammar/egide.ebnf).

    Every EBNF production maps to a type or a constructor below; the comment on each one quotes the production it
    represents. The complete production → constructor table is in the Log of T-0008
    (tasks/done/T-0008-ast-for-the-complete-grammar-with-printer.md).

    Conventions:
    - Every node carries the [span] of the source text it was parsed from (docs/architecture.md §2.1).
    - The tree is purely syntactic and immutable: no resolution or type information, no desugaring. Pipes,
      comprehensions, trailing blocks and [?] are desugared in HIR (docs/architecture.md §1).
    - Layout-only distinctions that carry no meaning (single-line vs indented block, [fn:] vs [fn():], [x => e] vs
      [(x) => e], trailing commas) are not represented; the lossless CST used by [egide fmt] keeps them.
    - Literals keep their source text where the value is checked later (integers, floats: LEX-040, LEX-041) and
      their decoded value otherwise (strings, bytes, characters).
    - Constructors are prefixed by their category ([Ty_], [Pat_], ...) because the categories share names
      (tuples, paths, ranges); expressions and declarations are unprefixed when unambiguous.

    {!Print} renders the tree as S-expressions for [egide parse] and snapshot tests. *)

type span = Egide_source.Span.t

type ident = { name : string; span : span }
(** [IDENT]. *)

type path = { segments : ident list; span : span }
(** [path = IDENT { "." IDENT }]. [segments] is never empty. *)

type duration_unit = Ns | Us | Ms | S | Min | H  (** LEX-042 *)

type mode =
  | By_read  (** no keyword: read access, the default (MEM-020) *)
  | Inout  (** [inout] (MEM-021) *)
  | Take  (** [take] (MEM-023) *)
  | Comptime  (** [comptime] (CT-010); only on [param], not on [lambda_param] *)

type unary_op =
  | Neg  (** [-] *)
  | Bit_not  (** [~] *)
  | Not  (** [not] *)

type binary_op =
  | Pipe  (** [|>] (SYN-037) *)
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
  | Pow  (** [**], right-associative (LEX-062) *)

type cmp_op = Eq | Ne | Lt | Le | Gt | Ge  (** [cmp_op] *)

type assign_op =
  | Simple_assign  (** [=] *)
  | Add_assign
  | Sub_assign
  | Mul_assign
  | Div_assign
  | Rem_assign
  | Bit_and_assign
  | Bit_or_assign
  | Bit_xor_assign
  | Shl_assign
  | Shr_assign  (** [assign_op] *)

(** {1 Expressions} *)

type literal =
  | Int of string  (** [INT], source text (LEX-040) *)
  | Float of string  (** [FLOAT], source text (LEX-041) *)
  | Duration of { amount : string; unit : duration_unit }  (** [DURATION] (LEX-042) *)
  | String of string  (** [STRING], decoded (LEX-050, LEX-051) *)
  | Raw_string of string  (** [RAW_STRING] (LEX-052) *)
  | Bytes of string  (** [BYTES], decoded (LEX-053) *)
  | Char of Uchar.t  (** [CHAR] (LEX-054) *)
  | Template of { prefix : ident; parts : template_part list }  (** [TEMPLATE] (LEX-055) *)
  | Bool of bool  (** ["true" | "false"] *)

and template_part =
  | Text of { text : string; span : span }  (** literal text, [{{]/[}}] already decoded *)
  | Interp of expr  (** [{expr}] *)

and expr = { expr : expr_desc; span : span }

and expr_desc =
  | Lit of literal  (** [literal] *)
  | Path of path  (** [primary = path] *)
  | Self  (** [primary = "self"] *)
  | Self_type  (** [primary = "Self"] *)
  | Paren of expr
      (** [primary = "(" expr ")"]; kept so that SYN-101 ("add parentheses") can be checked and the printer is
          faithful. *)
  | Tuple of expr list
      (** [primary = "(" ")"] (unit, empty list) and [primary = "(" expr "," [ expr { "," expr } [ "," ] ] ")"] *)
  | List of expr list  (** [primary = "[" [ expr_list ] "]"] *)
  | Set of expr list  (** [primary = "{" expr_list "}"] (non-empty, SYN-038) *)
  | Map of map_entry list  (** [primary = "{" [ map_entries ] "}"]; [{}] is the empty map (SYN-038) *)
  | Comprehension of { kind : comp_kind; clauses : comp_clause list }
      (** [primary = "(" expr comp_clauses ")" | "[" expr comp_clauses "]" | "{" map_entry comp_clauses "}"
          | "{" expr comp_clauses "}"] (SYN-039). [clauses] starts with a [Comp_for]. *)
  | If of { branches : if_branch list; else_ : block option }
      (** [if_expr] and [if_stmt]. [branches] holds the [if] and every [elif]; [else_] is mandatory when used as an
          expression (SYN-013). *)
  | Match of { scrutinee : expr; arms : case_arm list }  (** [match_expr] *)
  | Unsafe of { reason : string; reason_span : span; body : block }
      (** [primary = "unsafe" "(" "reason" ":" STRING ")" ":" block] *)
  | Call of { callee : expr; args : arg list }  (** [postfix_expr = primary "(" [ args ] ")"] (SYN-030) *)
  | Index of { target : expr; index : expr }
      (** [postfix_expr = primary "[" slice_or_index "]"]. A slice (SYN-040) is an [Index] whose [index] is a
          [Range]: the EBNF alternative [[ expr ] ( ".." | "..=" ) [ expr ]] is already derivable from [expr]
          through [range_expr], so the two are not distinguished. *)
  | Field of { target : expr; name : ident }  (** [postfix_expr = primary "." IDENT] *)
  | Try of expr  (** [postfix_expr = primary "?"] (SYN-034) *)
  | Unary of { op : unary_op; operand : expr }  (** [not_expr], [unary_expr] *)
  | Binary of { op : binary_op; lhs : expr; rhs : expr }
      (** [pipe_expr], [or_expr], [and_expr], [bitor_expr], [bitxor_expr], [bitand_expr], [shift_expr], [add_expr],
          [mul_expr], [pow_expr] *)
  | Compare of { first : expr; rest : (cmp_op * expr) list }
      (** [cmp_expr]; a chain [a < b <= c] is one node (SYN-036). [rest] is non-empty. *)
  | Range of { lo : expr option; hi : expr option; inclusive : bool }  (** [range_expr] *)
  | Cond of { cond : expr; then_ : expr; else_ : expr }  (** [cond_expr]: [then_ if cond else else_] (SYN-035) *)
  | Lambda of { params : lambda_param list; body : expr }  (** [lambda = lambda_head "=>" expr] (SYN-060) *)
  | Fn_lit of { params : lambda_param list; ret : ty option; body : block }
      (** [lambda = "fn" "(" [ lambda_params ] ")" [ "->" type ] ":" block] (SYN-064) *)
  | Trailing of { callee : expr; params : lambda_param list; body : block }
      (** [call_with_trailing_block = postfix_expr "fn" [ "(" [ lambda_params ] ")" ] ":" block] (SYN-062).
          Means [callee] called with one more argument [fn(params): body]; desugared in HIR. *)

and map_entry = { key : expr; value : expr; span : span }  (** [map_entry = expr ":" expr] *)

and comp_kind =
  | Comp_list of expr  (** [[e for …]] *)
  | Comp_set of expr  (** [{e for …}] *)
  | Comp_map of map_entry  (** [{k: v for …}] *)
  | Comp_iter of expr  (** [(e for …)], a lazy [Iter[T]] *)

and comp_clause =
  | Comp_for of { pat : pattern; iter : expr; span : span }  (** [comp_for = "for" pattern "in" or_expr] *)
  | Comp_if of { cond : expr; span : span }  (** [comp_clauses: "if" or_expr] *)

and if_branch = { cond : expr; body : block; span : span }  (** ["if" expr ":" block] or ["elif" expr ":" block] *)

and case_arm = { pat : pattern; guard : expr option; body : block; span : span }
(** [case_arm = "case" pattern [ "if" expr ] ":" block] *)

and arg = { label : ident option; inout : bool; value : expr; span : span }
(** [arg = [ IDENT ":" ] [ "&" ] expr] (SYN-030, SYN-033) *)

and lambda_param = { mode : mode; name : ident; ty : ty option; span : span }
(** [lambda_param = [ "inout" | "take" ] IDENT [ ":" type ]] *)

(** {1 Blocks and statements} *)

and block = { stmts : stmt list; span : span }
(** [block = NEWLINE INDENT stmt { NEWLINE stmt } NEWLINE DEDENT | simple_stmt] (SYN-010). [stmts] is non-empty. *)

and stmt = { stmt : stmt_desc; span : span }

and stmt_desc =
  | Expr of expr
      (** [simple_stmt = expr]; also [if_stmt], [match_expr] and [call_with_trailing_block] used as statements *)
  | Let of { pat : pattern; ty : ty option; value : expr; else_ : block option }
      (** ["let" pattern [ ":" type ] "=" expr [ "else" ":" block ]] (let-else when [else_] is present) *)
  | Var of { name : ident; ty : ty option; value : expr }  (** ["var" IDENT [ ":" type ] "=" expr] *)
  | Comptime_let of { name : ident; ty : ty option; value : expr }
      (** ["comptime" "let" IDENT [ ":" type ] "=" expr] *)
  | Assign of { place : place; op : assign_op; value : expr }  (** [place assign_op expr] *)
  | Return of expr option
  | Break of expr option
  | Continue
  | Defer of expr  (** ERR-035 *)
  | Yield of expr  (** SYN-075 *)
  | For of { pat : pattern; iter : expr; body : block }  (** [for_stmt] *)
  | While of { cond : expr; body : block }  (** [while_stmt] *)
  | Loop of block  (** [loop_stmt] *)
  | With of { items : with_item list; body : block }  (** [with_stmt] (ERR-030) *)
  | Given of { caps : expr list; body : block }  (** [given_stmt] (CAP-031) *)

and place = { root : ident; steps : place_step list; span : span }
(** [place = IDENT { "." IDENT | "[" expr "]" }]. See tasks/blocked/Q-0008 about [self] as a root. *)

and place_step = Place_field of ident | Place_index of expr

and with_item = { name : ident option; value : expr; span : span }  (** [with_item = [ IDENT "=" ] expr] *)

(** {1 Patterns} *)

and pattern = { pat : pat_desc; span : span }

and pat_desc =
  | Pat_wild  (** ["_"] *)
  | Pat_bind of ident  (** [IDENT] *)
  | Pat_lit of lit_pattern  (** [literal_pattern] *)
  | Pat_range of { lo : lit_pattern; hi : lit_pattern; inclusive : bool }  (** [range_pattern] *)
  | Pat_ctor of { path : path; fields : field_pattern list }  (** [path "(" [ field_patterns ] ")"] *)
  | Pat_tuple of pattern list  (** ["(" pattern "," [ pattern { "," pattern } ] ")"] *)
  | Pat_list of list_pattern list  (** ["[" [ list_patterns ] "]"] *)
  | Pat_or of pattern list  (** [or_pattern] with at least two alternatives *)
  | Pat_as of { pat : pattern; name : ident }  (** [pattern = or_pattern "as" IDENT] *)

and lit_pattern = { negated : bool; lit : literal; span : span }
(** [literal_pattern = [ "-" ] ( INT | FLOAT ) | STRING | CHAR | "true" | "false"] *)

and field_pattern =
  | Fp_field of { label : ident option; pat : pattern; span : span }  (** [field_pattern = [ IDENT ":" ] pattern] *)
  | Fp_rest of span  (** [field_pattern = ".."] *)

and list_pattern =
  | Lp_elem of pattern  (** [list_pattern = pattern] *)
  | Lp_rest of { name : ident option; span : span }  (** [list_pattern = ".." [ IDENT ]] *)

(** {1 Types} *)

and ty = { ty : ty_desc; span : span }

and ty_desc =
  | Ty_path of { path : path; args : type_arg list }  (** [base_type = path [ "[" type_args "]" ]] *)
  | Ty_tuple of ty list  (** [base_type = "(" [ type { "," type } [ "," ] ] ")"]; [[]] is unit *)
  | Ty_fn of { params : ty list; ret : ty option; using : ty list }
      (** [base_type = "fn" "(" [ type { "," type } ] ")" [ "->" type ] [ "using" type { "," type } ]] *)
  | Ty_dyn of ty  (** [base_type = "dyn" bound] *)
  | Ty_self  (** [base_type = "Self"] *)
  | Ty_optional of ty  (** [type = base_type "?"] (SYN-041) *)

and type_arg =
  | Ta_type of ty  (** [type_arg = type] *)
  | Ta_expr of expr  (** [type_arg = expr], a comptime value such as [16] in [Array[u8, 16]] *)

(** {1 Declarations} *)

and attribute = { name : ident; args : expr list option; span : span }
(** [attribute = "@" IDENT [ "(" [ expr_list ] ")" ]] (SYN-023). [None]: no parentheses. *)

and generic = { comptime : bool; name : ident; bounds : ty list; span : span }
(** [generic = [ "comptime" ] IDENT [ ":" bound { "+" bound } ]] *)

and param = { mode : mode; kind : param_kind; span : span }
(** [param = [ "inout" | "take" | "comptime" ] ( "self" | IDENT ":" type [ "=" expr ] )] (SYN-021, SYN-022) *)

and param_kind = Param_self | Param_named of { name : ident; ty : ty; default : expr option }

and typed_ident = { name : ident; ty : ty; span : span }
(** [IDENT ":" type]: [cap_param] in a [using_clause], and each entry of named [variant_fields] *)

and fn_sig = {
  name : ident;
  generics : generic list;
  params : param list;
  ret : ty option;
  using : typed_ident list;  (** [using_clause = "using" cap_param { "," cap_param }] *)
  span : span;
}
(** [fn_sig = "fn" IDENT [ generics ] "(" [ params ] ")" [ "->" type ] [ using_clause ]] (SYN-020) *)

and fn_decl = { sig_ : fn_sig; body : block; span : span }  (** [fn_decl = fn_sig ":" block] *)

and field = {
  doc : string option;
  attrs : attribute list;
  pub : bool;
  name : ident;
  ty : ty;
  default : expr option;
  span : span;
}
(** [field = { attribute NEWLINE } [ "pub" ] IDENT ":" type [ "=" expr ]] *)

and variant = { doc : string option; name : ident; fields : variant_fields; span : span }
(** [variant = IDENT [ "(" variant_fields ")" ]] *)

and variant_fields =
  | Vf_none  (** no parentheses *)
  | Vf_positional of ty list  (** [variant_fields = type { "," type }] *)
  | Vf_named of typed_ident list  (** [variant_fields = IDENT ":" type { "," IDENT ":" type }] *)

and trait_item = { doc : string option; item : trait_item_desc; span : span }

and trait_item_desc =
  | Ti_sig of fn_sig  (** [trait_item = fn_sig] (required method) *)
  | Ti_fn of fn_decl  (** [trait_item = fn_decl] (provided method) *)
  | Ti_type of { name : ident; bound : ty option }  (** [trait_item = "type" IDENT [ ":" bound ]] *)

and impl_item = { doc : string option; item : impl_item_desc; span : span }

and impl_item_desc =
  | Ii_fn of { attrs : attribute list; pub : bool; fn_ : fn_decl }
      (** [impl_item = { attribute NEWLINE } [ "pub" ] fn_decl] *)
  | Ii_type of { name : ident; ty : ty }  (** [impl_item = "type" IDENT "=" type] *)

and decl = { doc : string option; attrs : attribute list; pub : bool; decl : decl_desc; span : span }
(** [top_decl = { attribute NEWLINE } [ "pub" ] ( … )]. [doc] is the [##] comment before it (LEX-011). *)

and decl_desc =
  | Fn of fn_decl  (** [fn_decl] *)
  | Struct of { name : ident; generics : generic list; fields : field list }  (** [struct_decl] *)
  | Enum of { name : ident; generics : generic list; variants : variant list }  (** [enum_decl] *)
  | Trait of { name : ident; generics : generic list; supertraits : ty list; items : trait_item list }
      (** [trait_decl] *)
  | Impl of { generics : generic list; trait_ : ty option; self_ty : ty; items : impl_item list }
      (** [impl_decl = "impl" [ generics ] [ type "for" ] type ":" …]; [trait_] is the type before [for]. *)
  | Type of { name : ident; generics : generic list; newtype : bool; ty : ty; where_ : expr option }
      (** [type_decl = "type" IDENT [ generics ] "=" [ "new" ] type [ "where" expr ]] (TYP-030, TYP-031) *)
  | Const of { comptime : bool; name : ident; ty : ty option; value : expr }
      (** [const_decl = [ "comptime" ] "let" IDENT [ ":" type ] "=" expr] *)

(** {1 Files} *)

type import_item = { name : ident; alias : ident option; span : span }  (** [import_item = IDENT [ "as" IDENT ]] *)

type import = { import : import_desc; span : span }

and import_desc =
  | Import of { path : path; items : import_item list option; alias : ident option }
      (** [import_decl = "import" path [ "." "{" import_item { "," import_item } [ "," ] "}" ] [ "as" IDENT ]].
          [items = None]: no braces. *)
  | Import_go of { package : string; package_span : span; alias : ident }
      (** [import_decl = "import" "go" STRING "as" IDENT] (GO-001) *)

type file = { doc : string option; module_path : path; imports : import list; decls : decl list; span : span }
(** [file = [ doc_comment ] module_decl { NEWLINE import_decl } { NEWLINE top_decl } [ NEWLINE ] EOF];
    [module_decl = "module" path] (SYN-001, SYN-002). *)

(** {1 Equality}

    Structural equality, spans included. These play the role of [[@@deriving eq]] (see T-0008 Log): the names are the
    ones ppx_deriving would generate so that callers do not change when it is adopted. For equality that ignores
    spans, compare the {!Print} renderings, which omit spans by default. *)

val equal_file : file -> file -> bool
val equal_decl : decl -> decl -> bool
val equal_stmt : stmt -> stmt -> bool
val equal_block : block -> block -> bool
val equal_expr : expr -> expr -> bool
val equal_pattern : pattern -> pattern -> bool
val equal_ty : ty -> ty -> bool
