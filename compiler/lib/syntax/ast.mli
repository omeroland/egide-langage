(** Abstract syntax tree of Égide (spec/03-syntax.md, spec/grammar/egide.ebnf).

    Every EBNF production maps to a type or a constructor below; the comment on each one quotes the
    production it represents. The complete production → constructor table is in the Log of T-0008
    (tasks/done/T-0008-ast-for-the-complete-grammar-with-printer.md).

    Conventions:
    - Every node carries the [span] of the source text it was parsed from (docs/architecture.md
      §2.1).
    - Shapes follow the accepted grammar (ADR-0013 to ADR-0017): block-ended constructs are
      expressions (SYN-015), indexing and instantiation share one node (SYN-042), patterns keep
      bindings and constants apart (SYN-053), and visibility, import forms and [type] declarations
      are closed variants so that the forms the grammar forbids cannot be built.
    - Every node that a later pass annotates or scopes carries an [id : Node_id.t], unique within a
      parsed file (docs/architecture.md §2.3, T-1006): identifiers, paths, expressions, patterns,
      types, statements, blocks, declarations, call arguments ([arg]), [bound]s, [generic]s,
      [param]s (so that [self] has a key), [field]s, [variant]s, trait and impl items and
      [fn_decl]s. A wrapper whose identity is that of a child it always contains ([lambda_param],
      [typed_ident], [with_item], [case_arm], [if_branch], [map_entry], [attribute], [fn_sig],
      [import], and the pieces of a pattern or clause) has none: key a side table on the child's id.
      Ids are stored in the tree, so the derived equality ({!equal_file} and the like) compares
      them: two parses of one source are equal, two hand-built trees with distinct ids are not.
      {b Which id keys what.} Some constructs carry several ids; passes use one convention so that
      they find each other's entries. {e Binders} (a [let] or [for] variable, a parameter, a
      generic, an item name) are keyed by the [id] of their [ident] (for [Pat_bind i], [i.id], not
      the pattern's). {e References} are keyed by the [id] of the [path] ([Path p]: [p.id]; the path
      of a [Ty_path], of a [bound], of a [Pat_const] or [Pat_ctor]), or by the [ident] of a field or
      label. {e Typing and lowering results} are keyed by the [id] of the [expr], [pattern], [ty],
      [stmt] or [param] itself: the type of a variable use is stored under the [expr.id], its
      resolution under the [path.id]. A wrapper that adds nothing ([Stmt.Expr]'s [stmt], an
      unlabelled plain [arg]) is keyed only by a pass that annotates the wrapper itself. A pass that
      wants a different assignment must write it here first.
    - The tree is purely syntactic and immutable: no resolution or type information, no desugaring.
      Pipes, comprehensions, trailing blocks and [?] are desugared in HIR (docs/architecture.md §1).
    - Layout-only distinctions that carry no meaning (single-line vs indented block, [fn:] vs
      [fn():], [x => e] vs [(x) => e], trailing commas) are not represented; the lossless CST used
      by [egide fmt] keeps them.
    - Literals keep their source text where the value is checked later (integers, floats: LEX-040,
      LEX-041) and their decoded value otherwise (strings, bytes, characters).
    - Constructors are prefixed by their category ([Ty_], [Pat_], ...) because the categories share
      names (tuples, paths, ranges); expressions and declarations are unprefixed when unambiguous.

    {!Print} renders the tree as S-expressions for [egide parse] and snapshot tests. *)

type span = Egide_source.Span.t

val pp_span : Format.formatter -> span -> unit
(** [file:line:col] of the start, like {!Egide_source.Span.pp} but with the file name passed through
    [Egide_diagnostics.Escape.display] (LEX-006); the derived printers use it for every [span]. *)

val equal_span : span -> span -> bool
(** Structural: file name and both positions. *)

type ident = { id : Node_id.t; name : string; span : span } [@@deriving show, eq]
(** [IDENT]. *)

type path = { id : Node_id.t; segments : ident list; span : span } [@@deriving show, eq]
(** [path = IDENT { "." IDENT }]. [segments] is never empty. *)

type duration_unit = Ns | Us | Ms | S | Min | H  (** LEX-042 *) [@@deriving show, eq]

type mode =
  | By_read  (** no keyword: read access, the default (MEM-020) *)
  | Inout  (** [inout] (MEM-021) *)
  | Take  (** [take] (MEM-023) *)
  | Comptime  (** [comptime] (CT-010); only on [param], not on [lambda_param] *)
[@@deriving show, eq]

type unary_op = Neg  (** [-] *) | Bit_not  (** [~] *) | Not  (** [not] *) [@@deriving show, eq]

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
[@@deriving show, eq]

type cmp_op = Eq | Ne | Lt | Le | Gt | Ge  (** [cmp_op] *) [@@deriving show, eq]

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
[@@deriving show, eq]

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

and expr = { id : Node_id.t; expr : expr_desc; span : span }

and expr_desc =
  | Lit of literal  (** [literal] *)
  | Path of path  (** [primary = path] *)
  | Self  (** [primary = "self"] *)
  | Self_type  (** [primary = "Self"] *)
  | Paren of expr
      (** [primary = "(" expr ")"]; kept so that SYN-101 ("add parentheses") can be checked and the
          printer is faithful. *)
  | Tuple of expr list
      (** [primary = "(" ")"] (unit, empty list) and
          [primary = "(" expr "," [ expr { "," expr } [ "," ] ] ")"] *)
  | List of expr list  (** [primary = "[" [ expr_list ] "]"] *)
  | Set of expr list  (** [primary = "{" expr_list "}"] (non-empty, SYN-038) *)
  | Map of map_entry list
      (** [primary = "{" [ map_entries ] "}"]; [{}] is the empty map (SYN-038) *)
  | Comprehension of { kind : comp_kind; clauses : comp_clause list }
      (** [primary = "(" expr comp_clauses ")" | "[" expr comp_clauses "]" | "{" map_entry
           comp_clauses "}" | "{" expr comp_clauses "}"] (SYN-039). [clauses] starts with a
          [Comp_for]. *)
  | If of { branches : if_branch list; else_ : block option }
      (** [if_expr], the only [if] node (ADR-0013). [branches] holds the [if] and every [elif]
          (never empty); [else_] is mandatory when the value is used (SYN-013). *)
  | Match of { scrutinee : expr; arms : case_arm list }  (** [match_expr] (arms never empty) *)
  | Loop of block  (** [loop_expr]; its value is given by [break expr] *)
  | With of { items : with_item list; body : block }  (** [with_expr] (ERR-030, ERR-031) *)
  | Given of { caps : expr list; body : block }  (** [given_expr] (CAP-031) *)
  | Unsafe of { reason : string; reason_span : span; body : block }
      (** [unsafe_expr = "unsafe" "(" IDENT ":" STRING ")" ":" suite]. The parser has checked that
          the IDENT is [reason] and that the string obeys SYN-018 (E0110); [reason] is the decoded
          string. *)
  | Call of { callee : expr; args : arg list }
      (** [postfix_expr = primary "(" [ args ] ")"] (SYN-030) *)
  | Index of { target : expr; args : gen_arg list }
      (** [postfix_expr = primary "[" gen_args "]"] (SYN-042, SYN-043). Indexing, slicing
          ([xs[a..b]] is one [Ga_expr] holding a [Range]) and generic instantiation share this node;
          name resolution decides which one it is. [args] is never empty. *)
  | Field of { target : expr; name : ident }  (** [postfix_expr = primary "." IDENT] *)
  | Try of expr  (** [postfix_expr = primary "?"] (SYN-034) *)
  | Unary of { op : unary_op; operand : expr }  (** [not_expr], [unary_expr] *)
  | Binary of { op : binary_op; lhs : expr; rhs : expr }
      (** [pipe_expr], [or_expr], [and_expr], [bitor_expr], [bitxor_expr], [bitand_expr],
          [shift_expr], [add_expr], [mul_expr], [pow_expr] *)
  | Compare of { first : expr; rest : (cmp_op * expr) list }
      (** [cmp_expr]; a chain [a < b <= c] is one node (SYN-036). [rest] is non-empty. *)
  | Range of { lo : expr option; hi : expr option }  (** [range_expr]: [a..b], [a..], [..b], [..] *)
  | Range_incl of { lo : expr option; hi : expr }
      (** [range_expr]: [a..=b], [..=b]. The upper bound is mandatory (SYN-040). *)
  | Cond of { cond : expr; then_ : expr; else_ : expr }
      (** [cond_expr]: [then_ if cond else else_] (SYN-035) *)
  | Lambda of { params : lambda_param list; body : expr }
      (** [lambda = ( IDENT | paren_form ) "=>" expr] (SYN-060); every item of the [paren_form] has
          been checked to be a lambda parameter (SYN-065, E0107) *)
  | Fn_lit of { params : lambda_param list; ret : ty option; body : block }
      (** [fn_lambda = fn_head ":" suite] (SYN-064). [fn:] and [fn():] are the same node. *)
  | Trailing_call of {
      callee : expr;
      args : arg list;
      params : lambda_param list;
      ret : ty option;
      body : block;
    }
      (** [trailing_call = postfix_expr "(" [ args ] ")" fn_head ":" suite] (SYN-062).
          [callee(args)] called with one more argument [fn(params) [-> ret]: body]; desugared in
          HIR. [callee] is the postfix expression before the call's own parentheses. *)

and map_entry = { key : expr; value : expr; span : span }
(** [map_entry = expr ":" expr] *)

and comp_kind =
  | Comp_list of expr  (** [[e for …]] *)
  | Comp_set of expr  (** [{e for …}] *)
  | Comp_map of map_entry  (** [{k: v for …}] *)
  | Comp_iter of expr  (** [(e for …)], a lazy [Iter[T]] *)

and comp_clause =
  | Comp_for of { pat : pattern; iter : expr; span : span }
      (** [comp_for = "for" pattern "in" or_expr] *)
  | Comp_if of { cond : expr; span : span }  (** [comp_clauses: "if" or_expr] *)

and if_branch = { cond : expr; body : block; span : span }
(** ["if" expr ":" block] or ["elif" expr ":" block] *)

and case_arm = { pat : pattern; guard : expr option; body : block; span : span }
(** [case_arm = "case" pattern [ "if" expr ] ":" block] *)

and arg = { id : Node_id.t; arg : arg_desc; span : span }

and arg_desc =
  | Arg_plain of { label : ident option; value : expr }  (** [arg = [ IDENT ":" ] expr] (SYN-030) *)
  | Arg_inout of { label : ident option; value : expr }
      (** [arg = [ IDENT ":" ] "&" postfix_expr] (SYN-033). The parser has checked that [value] is a
          place (SYN-012, E0106). *)
  | Arg_using of ident * expr
      (** [arg = "using" IDENT ":" expr]: an explicit capability, last in the list (CAP-032,
          SYN-030, E0120). *)

and gen_arg =
  | Ga_expr of expr
      (** [gen_arg = expr] (a type written as a path is an expression until resolution) *)
  | Ga_type_only of ty
      (** [gen_arg = fn_type | "dyn" bound { "+" bound }]: only a [Ty_fn] or a [Ty_dyn] (SYN-042) *)

and bound = { id : Node_id.t; path : path; args : gen_arg list; span : span }
(** [bound = path [ "[" gen_args "]" ]]: a trait or capability type (ADR-0014). *)

and lambda_param = { mode : mode; name : ident; ty : ty option; span : span }
(** [lambda_param = [ "inout" | "take" ] IDENT [ ":" type ]] *)

(** {1 Blocks and statements} *)

and block = { id : Node_id.t; stmts : stmt list; span : span }
(** [block = NEWLINE INDENT stmt { NEWLINE stmt } NEWLINE DEDENT | simple_stmt] (SYN-010). [stmts]
    is non-empty. *)

and stmt = { id : Node_id.t; stmt : stmt_desc; span : span }

and stmt_desc =
  | Expr of expr
      (** [single_stmt = expr] and [block_stmt = block_expr]: every block-ended expression used as a
          statement is wrapped here (ADR-0013, SYN-015) *)
  | Let of { pat : pattern; ty : ty option; value : expr; else_ : block option }
      (** ["let" pattern [ ":" type ] "=" expr [ "else" ":" block ]] (let-else when [else_] is
          present) *)
  | Var of { name : ident; ty : ty option; value : expr }
      (** ["var" IDENT [ ":" type ] "=" expr] *)
  | Comptime_let of { name : ident; ty : ty option; value : expr }
      (** ["comptime" "let" IDENT [ ":" type ] "=" expr] *)
  | Assign of { target : expr; op : assign_op; value : expr }
      (** [assign_target assign_op expr]. [target] is a postfix expression (Q-0008, ADR-0013); the
          parser has checked that it is a place (SYN-012, E0106). A parenthesised expression is not
          a place. *)
  | Return of expr option
  | Break of expr option
  | Continue
  | Defer of expr  (** ERR-035 *)
  | Yield of expr  (** SYN-075 *)
  | For of { pat : pattern; iter : expr; body : block }  (** [for_stmt] *)
  | While of { cond : expr; body : block }  (** [while_stmt] *)

and with_item = { name : ident option; value : expr; span : span }
(** [with_item = [ IDENT "=" ] expr] *)

(** {1 Patterns} *)

and pattern = { id : Node_id.t; pat : pat_desc; span : span }

and pat_desc =
  | Pat_wild  (** ["_"] *)
  | Pat_bind of ident  (** a lone identifier starting with a lowercase letter (SYN-053) *)
  | Pat_const of path
      (** a path of two or more segments, or a lone identifier starting with an uppercase letter,
          not followed by [(]: a variant, unit struct or constant that MUST resolve (SYN-053). The
          parser has checked that the last segment starts with an uppercase letter (E0112). *)
  | Pat_lit of lit_pattern  (** [literal_pattern] *)
  | Pat_range of { lo : lit_pattern; hi : lit_pattern; inclusive : bool }  (** [range_pattern] *)
  | Pat_ctor of { path : path; fields : field_pattern list }
      (** [path "(" [ field_patterns ] ")"]; the last segment starts with an uppercase letter
          (E0112) *)
  | Pat_tuple of pattern list  (** ["(" pattern "," [ pattern { "," pattern } ] ")"] *)
  | Pat_list of list_pattern list  (** ["[" [ list_patterns ] "]"] *)
  | Pat_or of pattern list  (** [or_pattern] with at least two alternatives *)
  | Pat_as of { pat : pattern; name : ident }  (** [pattern = or_pattern "as" IDENT] *)

and lit_pattern = { negated : bool; lit : literal; span : span }
(** [literal_pattern = [ "-" ] ( INT | FLOAT | DURATION ) | STRING | RAW_STRING | BYTES | CHAR |
     "true" | "false"] (SYN-050, ADR-0015). [lit] is never a [Template]; [negated] only with [Int],
    [Float] or [Duration]. *)

and field_pattern =
  | Fp_field of { label : ident option; pat : pattern; span : span }
      (** [field_pattern = [ IDENT ":" ] pattern] *)
  | Fp_rest of span  (** [field_pattern = ".."] *)

and list_pattern =
  | Lp_elem of pattern  (** [list_pattern = pattern] *)
  | Lp_rest of { name : ident option; span : span }  (** [list_pattern = ".." [ IDENT ]] *)

(** {1 Types} *)

and ty = { id : Node_id.t; ty : ty_desc; span : span }

and ty_desc =
  | Ty_path of { path : path; args : gen_arg list }
      (** [simple_type = path [ "[" gen_args "]" ]]; the arguments are expressions or type-only
          forms, told apart by resolution (SYN-042, ADR-0014). *)
  | Ty_tuple of ty list
      (** [simple_type = "(" ")" | "(" type "," [ type { "," type } [ "," ] ] ")"]. [[]] is the unit
          type and a singleton is the one-element tuple type [(T,)]. There is no parenthesised type
          node: [(T)] is [T] (TYP-006), so a one-element list is never ambiguous. *)
  | Ty_fn of { params : ty list; ret : ty option; using : bound list }
      (** [fn_type = "fn" "(" [ type { "," type } ] ")" [ "->" ret_type ] [ "using" fn_caps ]].
          [using] is the [+]-joined list of capability bounds, empty when absent (TYP-006). *)
  | Ty_dyn of bound list  (** [simple_type = "dyn" bound { "+" bound }] (never empty) *)
  | Ty_self  (** [simple_type = "Self"] *)
  | Ty_optional of ty
      (** [ret_type = simple_type "?"] (SYN-041, TYP-006). An optional function type is
          [Ty_optional (Ty_fn …)], written [(fn() -> T)?]. *)

(** {1 Declarations} *)

and attribute = { name : ident; args : expr list option; span : span }
(** [attribute = "@" IDENT [ "(" [ expr_list ] ")" ]] (SYN-023). [None]: no parentheses. *)

and generic = { id : Node_id.t; comptime : bool; name : ident; bounds : bound list; span : span }
(** [generic = [ "comptime" ] IDENT [ ":" bound { "+" bound } ]] *)

and param = { id : Node_id.t; mode : mode; kind : param_kind; span : span }
(** [param = [ "inout" | "take" | "comptime" ] ( "self" | IDENT ":" type [ "=" expr ] )] (SYN-021,
    SYN-022) *)

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
(** [fn_sig = "fn" IDENT [ generics ] "(" [ params ] ")" [ "->" type ] [ using_clause ]] (SYN-020)
*)

and fn_decl = { id : Node_id.t; sig_ : fn_sig; body : block; span : span }
(** [fn_decl = fn_sig ":" block] *)

and visibility =
  | Private  (** no keyword *)
  | Pub  (** [pub] *)
  | Pub_package  (** [pub(package)] (SYN-003; counts as [pub] for TYP-003 and CAP-034) *)

and field = {
  id : Node_id.t;
  attrs : attribute list;
  vis : visibility;
  name : ident;
  ty : ty;
  default : expr option;
  span : span;
}
(** [field = { attribute NEWLINE } [ visibility ] IDENT ":" type [ "=" expr ]] *)

and variant = { id : Node_id.t; name : ident; fields : variant_fields; span : span }
(** [variant = IDENT [ "(" variant_fields ")" ]] *)

and variant_fields =
  | Vf_none  (** no parentheses *)
  | Vf_positional of ty list  (** [variant_fields = type { "," type }] *)
  | Vf_named of typed_ident list  (** [variant_fields = IDENT ":" type { "," IDENT ":" type }] *)

and trait_item = { id : Node_id.t; item : trait_item_desc; span : span }

and trait_item_desc =
  | Ti_sig of fn_sig  (** [trait_item = fn_sig] (required method) *)
  | Ti_fn of fn_decl  (** [trait_item = fn_decl] (provided method) *)
  | Ti_type of { name : ident; bound : bound option }
      (** [trait_item = "type" IDENT [ ":" bound ]] *)

and impl_item = { id : Node_id.t; item : impl_item_desc; span : span }

and impl_item_desc =
  | Ii_fn of { attrs : attribute list; vis : visibility; fn_ : fn_decl }
      (** [impl_item = { attribute NEWLINE } [ visibility ] fn_decl] *)
  | Ii_type of { name : ident; ty : ty }  (** [impl_item = "type" IDENT "=" type] *)

and decl = {
  id : Node_id.t;
  attrs : attribute list;
  vis : visibility;
  decl : decl_desc;
  span : span;
}
(** [top_decl = { attribute NEWLINE } ( [ visibility ] item_decl | impl_decl )]. [vis] is [Private]
    for an [Impl] (an impl has no visibility, SYN-003). Documentation comments are not part of the
    tree: they live in the comment side table (LEX-011, ADR-0016, T-1036). *)

and decl_desc =
  | Fn of fn_decl  (** [fn_decl] *)
  | Struct of { name : ident; generics : generic list; fields : field list }
      (** [struct_decl]; [fields] is empty for [struct Name] without a body (SYN-024) *)
  | Enum of { name : ident; generics : generic list; variants : variant list }  (** [enum_decl] *)
  | Trait of {
      name : ident;
      generics : generic list;
      supertraits : bound list;
      items : trait_item list;
    }  (** [trait_decl]; [items] is never empty (SYN-024) *)
  | Impl of { generics : generic list; trait_ : ty option; self_ty : ty; items : impl_item list }
      (** [impl_decl = "impl" [ generics ] type ( ":" impl_body | "for" type ( ":" impl_body |
           NEWLINE ) )]; [trait_] is the type before [for]. [items] is empty only for a trait impl
          without a body (SYN-024). *)
  | Type of { name : ident; generics : generic list; def : type_def }
      (** [type_decl = "type" IDENT [ generics ] "=" ( "new" type [ "where" expr ] | type )] *)
  | Const of { name : ident; ty : ty option; value : expr }
      (** [const_decl = "let" IDENT [ ":" type ] "=" ( expr NEWLINE | const_block )] (SYN-003,
          SYN-015). A top-level constant is implicitly [comptime] (CT-002), so there is no flag. The
          parser has checked that a block-ended [value] is a [const_block]: never [Unsafe], [Given]
          or [With] (E0104). *)

and type_def =
  | Alias of ty  (** [type A = T] *)
  | Newtype of { ty : ty; where_ : expr option }
      (** [type A = new T [ where expr ]]; [where] exists only here (TYP-030, TYP-031, SYN-024) *)
[@@deriving show, eq]

(** {1 Files} *)

type import_item = { name : ident; alias : ident option; span : span } [@@deriving show, eq]
(** [import_item = IDENT [ "as" IDENT ]] *)

type import = { import : import_desc; span : span }

and import_desc =
  | Import of { path : path; form : import_form }
      (** [import_decl = "import" path [ "." "{" import_item { "," import_item } [ "," ] "}" | "as"
           IDENT ]] *)
  | Import_go of { package : string; package_span : span; alias : ident }
      (** [import_decl = "import" "go" STRING "as" IDENT] (GO-001) *)

and import_form =
  | Whole  (** [import a.b] *)
  | Alias_as of ident  (** [import a.b as c] (SYN-002: [as] only on a single path) *)
  | Items of import_item list  (** [import a.b.{X, Y as Z}] (never empty) *)
[@@deriving show, eq]

type file = { module_path : path; imports : import list; decls : decl list; span : span }
[@@deriving show, eq]
(** [file = module_decl NEWLINE { import_decl NEWLINE } { top_decl } EOF];
    [module_decl = "module" path] (SYN-001, SYN-002). *)

(** {1 Derived functions}

    Every type above has [[@@deriving show, eq]] (ppx_deriving, ADR-0001): [pp_x], [show_x] and
    [equal_x], for example {!pp_expr}, {!show_file}, {!equal_decl}. They are generated, so they are
    not listed here.

    - [equal_x] is structural and compares spans and node ids ({!Node_id.equal} on the [id] fields),
      as the hand-written functions it replaced did. For equality that ignores spans and ids,
      compare the {!Print} renderings, which omit both by default.
    - [pp_x] / [show_x] print OCaml record syntax with spans ([file:line:col], file name escaped) and
      ids ([#n]). They are {b reserved for tests and debugging}: they are not covered by LEX-006
      (string literal values and identifiers are printed as OCaml-escaped strings, not through
      [Escape.display]; only the span's file name is escaped), their format is {b unstable} (it
      follows the type definitions, and the numbering of ids follows the grammar), and {b no tool
      output may use them}: [egide parse], diagnostics, the formatter and the LSP print through
      {!Print} and [Output]. They are {b not} the S-expression: use [Print.pp_sexp_x] for that. A
      [Uchar.t] prints as [U+XXXX]. *)
