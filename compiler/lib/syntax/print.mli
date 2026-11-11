(** S-expression rendering of the {!Ast}, used by [egide parse] and by snapshot tests.

    {b Stability.} The output is deterministic (same tree, same bytes) and stable enough for
    snapshot tests inside this repository. It is {b not} a user-facing format: it may change in any
    release without notice, and no tool outside the compiler's own tests may parse it. Users who
    need a machine-readable AST should ask for a dedicated, versioned format.

    {b Format.} Each node is a list whose head names the node kind, followed by its flags ([pub],
    [comptime], [new], [inout], [take]), its name if it has one, and its children. Leaf names, paths
    and plain types are bare atoms ([x], [api.tenants], [str]). Spans are omitted unless
    [~spans:true], in which case each node prints its span as an [@line:col-line:col] atom after its
    head, and each identifier, path and plain type is suffixed with its span. (Spans of wrapper
    records whose extent equals a printed child, such as a positional argument or a [fn_sig] inside
    a declaration, are not repeated.) A list longer than 100 bytes at its indentation is broken
    after its leading atoms (and its subject, such as the callee of a call, if it fits), each
    remaining child on its own line indented by two spaces. A file renders as its [(module …)] line
    followed by one line per import and declaration, indented by two spaces.

    The head of each node kind:
    - literals: [(int 1)] [(float 1.5)] [(duration 5 s)] [(string "…")] [(raw "…")] [(bytes "…")]
      [(char "a")] [(bool true)] [(template f (text "…") EXPR …)]
    - expressions: [(path a.b)] [(self)] [(Self)] [(paren E)] [(tuple …)] [(list …)] [(set …)]
      [(map (entry K V) …)] [(comp list|set|map|iter ELEM (for P E) (if E) …)]
      [(if C BLOCK (elif C BLOCK) … (else BLOCK))] [(match E (case P (guard E) BLOCK) …)]
      [(unsafe "reason" BLOCK)] [(loop BLOCK)] [(with ITEM … BLOCK)] with [ITEM] = [E] or
      [(bind x E)]; [(given E … BLOCK)]; [(call F ARG …)] with [ARG] = [E], [(& E)], [(using x E)]
      or [(label name ARG)]; [(index E GA …)] with [GA] an expression or a type (indexing, slicing
      and instantiation, SYN-042); [(dot E name)] [(? E)] [(- E)] [(~ E)] [(not E)] [(OP L R)] for
      binary operators written as in the source ([+], [|>], [and], …), [(cmp A < B <= C)],
      [(.. LO HI)] / [(..= LO HI)] with [_] for an absent bound, [(cond C THEN ELSE)],
      [(lambda (params …) E)], [(fn (params …) (-> T) BLOCK)],
      [(trailing-call CALLEE (args ARG …) (params …) (-> T) BLOCK)], with params
      [(param [inout|take] x [T])]
    - statements: an expression statement is its expression; [(let P (: T) E (else BLOCK))]
      [(var x (: T) E)] [(let comptime x (: T) E)] [(= TARGET E)] / [(+= TARGET E)] … ([TARGET] is
      an expression) [(return [E])] [(break [E])] [(continue)] [(defer E)] [(yield E)]
      [(for P E BLOCK)] [(while E BLOCK)] [(block S …)]
    - patterns: [_] [x] [(const Path)] literal, [(- LIT)], [(.. LO HI)] / [(..= LO HI)],
      [(ctor Path FP …)] with [FP] = [P], [(label x P)] or [..]; [(tuple P …)] [(list LP …)] with
      [LP] = [P], [..] or [(.. rest)]; [(| P Q …)] [(as P x)]
    - types: [Name] [(apply Name GA …)] [(tuple-type T …)]
      [(fn-type (params T …) (-> T) (using B …))] [(dyn B …)] [Self] [(? T)], with [B] a bound
      printed like a path type
    - declarations:
      [(fn [pub|pub(package)] name (@ attr (args E …)) (generics (generic [comptime] T BOUND …))
       (params (param [mode] x T (default E)) | (param [mode] self)) (-> T) (using (x T) …) BLOCK)],
      [(fn-sig …)] (same without block), [(struct [pub] Name … (field [pub] x T (default E)))],
      [(enum [pub] Name … (variant A) (variant B (positional T …)) (variant C (named (x T) …)))],
      [(trait [pub] Name … (supertraits T …) ITEM …)] with [(assoc-type Name [BOUND])] items,
      [(impl [pub] SELF (trait T) (generics …) ITEM …)] with [(assoc-type Name T)] items,
      [(type [pub] [new] Name (generics …) T (where E))], [(let [pub|pub(package)] NAME (: T) E)]
    - files: [(module a.b)] [(import a.b)] [(import a.b (items x (y as z)) as w)]
      [(import-go "pkg" as name)] *)

val file : ?spans:bool -> Ast.file -> string
(** The whole file, without a trailing newline. *)

val decl : ?spans:bool -> Ast.decl -> string
val stmt : ?spans:bool -> Ast.stmt -> string
val block : ?spans:bool -> Ast.block -> string
val expr : ?spans:bool -> Ast.expr -> string
val pattern : ?spans:bool -> Ast.pattern -> string
val ty : ?spans:bool -> Ast.ty -> string

(** {2 Formatters}

    [pp_x fmt v] prints [x v] (without spans). They play the role of [[@@deriving show]] (see T-0008
    Log), e.g. as Alcotest testables. *)

val pp_file : Format.formatter -> Ast.file -> unit
val pp_decl : Format.formatter -> Ast.decl -> unit
val pp_stmt : Format.formatter -> Ast.stmt -> unit
val pp_block : Format.formatter -> Ast.block -> unit
val pp_expr : Format.formatter -> Ast.expr -> unit
val pp_pattern : Format.formatter -> Ast.pattern -> unit
val pp_ty : Format.formatter -> Ast.ty -> unit
