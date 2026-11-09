(* S-expression printer for the AST. The format is documented in print.mli. Two steps: the tree is converted to a
   small S-expression type, then laid out within [width]. *)

open Ast

(* When a list must be broken, its leading atoms stay on the head line, and so do its first [keep] items if they fit
   (e.g. the callee of a call: [keep] counts the head, the span atom if any, and the subject). *)
type sx = Atom of string | List of { keep : int; items : sx list }

type ctx = { spans : bool }

let width = 100

(* ---------- layout ---------- *)

let rec flat = function
  | Atom s -> s
  | List { items; _ } -> "(" ^ String.concat " " (List.map flat items) ^ ")"

let rec render buf indent sx =
  let s = flat sx in
  match sx with
  | Atom _ -> Buffer.add_string buf s
  | List _ when indent + String.length s <= width -> Buffer.add_string buf s
  | List { keep; items } ->
      let rec leading acc = function Atom a :: rest -> leading (a :: acc) rest | rest -> (List.rev acc, rest) in
      let atoms, rest = leading [] items in
      let rec kept line i = function
        | first :: rest when i < keep && indent + String.length line + 1 + String.length (flat first) <= width ->
            kept (line ^ " " ^ flat first) (i + 1) rest
        | rest -> (line, rest)
      in
      let head, rest = kept ("(" ^ String.concat " " atoms) (List.length atoms) rest in
      Buffer.add_string buf head;
      List.iter
        (fun child ->
          Buffer.add_char buf '\n';
          Buffer.add_string buf (String.make (indent + 2) ' ');
          render buf (indent + 2) child)
        rest;
      Buffer.add_char buf ')'

let to_string ?(indent = 0) sx =
  let buf = Buffer.create 256 in
  render buf indent sx;
  Buffer.contents buf

(* ---------- atoms ---------- *)

(* Strings are decoded UTF-8 (LEX-001) and printed as is, except quotes, backslashes and control characters. Byte
   strings may hold any byte: non-ASCII and control bytes are printed as [\xHH] (LEX-053). *)
let quote ?(bytes = false) s =
  let b = Buffer.create (String.length s + 2) in
  Buffer.add_char b '"';
  String.iter
    (fun ch ->
      match ch with
      | '"' -> Buffer.add_string b "\\\""
      | '\\' -> Buffer.add_string b "\\\\"
      | '\n' -> Buffer.add_string b "\\n"
      | '\t' -> Buffer.add_string b "\\t"
      | '\r' -> Buffer.add_string b "\\r"
      | c when bytes && (Char.code c < 0x20 || Char.code c >= 0x7f) -> Printf.bprintf b "\\x%02x" (Char.code c)
      | c when Char.code c < 0x20 || Char.code c = 0x7f -> Printf.bprintf b "\\u{%X}" (Char.code c)
      | c -> Buffer.add_char b c)
    s;
  Buffer.add_char b '"';
  Buffer.contents b

let utf8 u =
  let b = Buffer.create 4 in
  Buffer.add_utf_8_uchar b u;
  Buffer.contents b

let span_s (sp : span) =
  Printf.sprintf "%d:%d-%d:%d" sp.start.line sp.start.col sp.stop.line sp.stop.col

let span_atoms c sp = if c.spans then [ Atom ("@" ^ span_s sp) ] else []
let node ?(subject = false) c head sp items =
  let prefix = Atom head :: span_atoms c sp in
  List { keep = (if subject then List.length prefix + 1 else 0); items = prefix @ items }

let group ?(subject = false) head items = List { keep = (if subject then 2 else 0); items = Atom head :: items }
let named c name sp = if c.spans then Atom (name ^ "@" ^ span_s sp) else Atom name
let ident c (i : ident) = named c i.name i.span
let path_s (p : path) = String.concat "." (List.map (fun (i : ident) -> i.name) p.segments)
let path c (p : path) = named c (path_s p) p.span
let flag b s = if b then [ Atom s ] else []
let opt f = function None -> [] | Some v -> [ f v ]
let doc_atoms = opt (fun d -> group "doc" [ Atom (quote d) ])

let mode_flags = function
  | By_read -> []
  | Inout -> [ Atom "inout" ]
  | Take -> [ Atom "take" ]
  | Comptime -> [ Atom "comptime" ]

let duration_unit_s = function Ns -> "ns" | Us -> "us" | Ms -> "ms" | S -> "s" | Min -> "min" | H -> "h"
let unary_s = function Neg -> "-" | Bit_not -> "~" | Not -> "not"

let binary_s = function
  | Pipe -> "|>"
  | Or -> "or"
  | And -> "and"
  | Bit_or -> "|"
  | Bit_xor -> "^"
  | Bit_and -> "&"
  | Shl -> "<<"
  | Shr -> ">>"
  | Add -> "+"
  | Sub -> "-"
  | Mul -> "*"
  | Div -> "/"
  | Rem -> "%"
  | Pow -> "**"

let cmp_s = function Eq -> "==" | Ne -> "!=" | Lt -> "<" | Le -> "<=" | Gt -> ">" | Ge -> ">="

let assign_s = function
  | Simple_assign -> "="
  | Add_assign -> "+="
  | Sub_assign -> "-="
  | Mul_assign -> "*="
  | Div_assign -> "/="
  | Rem_assign -> "%="
  | Bit_and_assign -> "&="
  | Bit_or_assign -> "|="
  | Bit_xor_assign -> "^="
  | Shl_assign -> "<<="
  | Shr_assign -> ">>="

(* ---------- tree → S-expression ---------- *)

let rec literal c sp = function
  | Int s -> node c "int" sp [ Atom s ]
  | Float s -> node c "float" sp [ Atom s ]
  | Duration { amount; unit } -> node c "duration" sp [ Atom amount; Atom (duration_unit_s unit) ]
  | String s -> node c "string" sp [ Atom (quote s) ]
  | Raw_string s -> node c "raw" sp [ Atom (quote s) ]
  | Bytes s -> node c "bytes" sp [ Atom (quote ~bytes:true s) ]
  | Char u -> node c "char" sp [ Atom (quote (utf8 u)) ]
  | Template { prefix; parts } -> node c "template" sp (ident c prefix :: List.map (template_part c) parts)
  | Bool b -> node c "bool" sp [ Atom (string_of_bool b) ]

and template_part c = function
  | Text { text; span } -> node c "text" span [ Atom (quote text) ]
  | Interp e -> expr c e

and expr c (x : expr) =
  let n ?subject head items = node ?subject c head x.span items in
  match x.expr with
  | Lit l -> literal c x.span l
  | Path p -> n "path" [ path c p ]
  | Self -> n "self" []
  | Self_type -> n "Self" []
  | Paren e -> n "paren" [ expr c e ]
  | Tuple es -> n "tuple" (List.map (expr c) es)
  | List es -> n "list" (List.map (expr c) es)
  | Set es -> n "set" (List.map (expr c) es)
  | Map es -> n "map" (List.map (map_entry c) es)
  | Comprehension { kind; clauses } ->
      let k, elem =
        match kind with
        | Comp_list e -> ("list", expr c e)
        | Comp_set e -> ("set", expr c e)
        | Comp_map m -> ("map", map_entry c m)
        | Comp_iter e -> ("iter", expr c e)
      in
      n ~subject:true "comp" (Atom k :: elem :: List.map (comp_clause c) clauses)
  | If { branches; else_ } ->
      (* The first branch is the [if] itself; the others print as [(elif …)] children. *)
      let elif (b : if_branch) = node ~subject:true c "elif" b.span [ expr c b.cond; block c b.body ] in
      let first, elifs = match branches with b :: rest -> ([ expr c b.cond; block c b.body ], rest) | [] -> ([], []) in
      n ~subject:true "if" (first @ List.map elif elifs @ opt (fun b -> group "else" [ block c b ]) else_)
  | Match { scrutinee; arms } -> n ~subject:true "match" (expr c scrutinee :: List.map (case_arm c) arms)
  | Unsafe { reason; reason_span; body } -> n "unsafe" [ named c (quote reason) reason_span; block c body ]
  | Call { callee; args } -> n ~subject:true "call" (expr c callee :: List.map (arg c) args)
  | Index { target; index } -> n ~subject:true "index" [ expr c target; expr c index ]
  | Field { target; name } -> n ~subject:true "dot" [ expr c target; ident c name ]
  | Try e -> n "?" [ expr c e ]
  | Unary { op; operand } -> n (unary_s op) [ expr c operand ]
  | Binary { op; lhs; rhs } -> n ~subject:true (binary_s op) [ expr c lhs; expr c rhs ]
  | Compare { first; rest } ->
      n ~subject:true "cmp" (expr c first :: List.concat_map (fun (op, e) -> [ Atom (cmp_s op); expr c e ]) rest)
  | Range { lo; hi; inclusive } ->
      let bound = function None -> Atom "_" | Some e -> expr c e in
      n (if inclusive then "..=" else "..") [ bound lo; bound hi ]
  | Cond { cond; then_; else_ } -> n ~subject:true "cond" [ expr c cond; expr c then_; expr c else_ ]
  | Lambda { params; body } -> n ~subject:true "lambda" [ lambda_params c params; expr c body ]
  | Fn_lit { params; ret; body } ->
      n ~subject:true "fn" ((lambda_params c params :: opt (fun t -> group "->" [ ty c t ]) ret) @ [ block c body ])
  | Trailing { callee; params; body } ->
      n ~subject:true "trailing" [ expr c callee; lambda_params c params; block c body ]

and map_entry c (m : map_entry) = node ~subject:true c "entry" m.span [ expr c m.key; expr c m.value ]

and comp_clause c = function
  | Comp_for { pat; iter; span } -> node ~subject:true c "for" span [ pattern c pat; expr c iter ]
  | Comp_if { cond; span } -> node c "if" span [ expr c cond ]

and case_arm c (a : case_arm) =
  node ~subject:true c "case" a.span
    ((pattern c a.pat :: opt (fun g -> group "guard" [ expr c g ]) a.guard) @ [ block c a.body ])

and arg c (a : arg) =
  let value = if a.inout && a.label = None then node c "&" a.span [ expr c a.value ] else expr c a.value in
  match a.label with
  | None -> value
  | Some l ->
      let value = if a.inout then group "&" [ value ] else value in
      node c "label" a.span [ ident c l; value ]

and lambda_param c (p : lambda_param) =
  node c "param" p.span ((mode_flags p.mode @ [ ident c p.name ]) @ opt (ty c) p.ty)

and lambda_params c ps = group "params" (List.map (lambda_param c) ps)
and block c (b : block) = node c "block" b.span (List.map (stmt c) b.stmts)
and annot c = opt (fun t -> group ":" [ ty c t ])

and stmt c (st : stmt) =
  let n ?subject head items = node ?subject c head st.span items in
  match st.stmt with
  | Expr e -> expr c e
  | Let { pat; ty = t; value; else_ } ->
      n ~subject:true "let"
        ((pattern c pat :: annot c t) @ [ expr c value ] @ opt (fun b -> group "else" [ block c b ]) else_)
  | Var { name; ty = t; value } -> n "var" ((ident c name :: annot c t) @ [ expr c value ])
  | Comptime_let { name; ty = t; value } -> n "let" ((Atom "comptime" :: ident c name :: annot c t) @ [ expr c value ])
  | Assign { place = pl; op; value } -> n ~subject:true (assign_s op) [ place c pl; expr c value ]
  | Return e -> n "return" (opt (expr c) e)
  | Break e -> n "break" (opt (expr c) e)
  | Continue -> n "continue" []
  | Defer e -> n "defer" [ expr c e ]
  | Yield e -> n "yield" [ expr c e ]
  | For { pat; iter; body } -> n ~subject:true "for" [ pattern c pat; expr c iter; block c body ]
  | While { cond; body } -> n ~subject:true "while" [ expr c cond; block c body ]
  | Loop b -> n "loop" [ block c b ]
  | With { items; body } -> n "with" (List.map (with_item c) items @ [ block c body ])
  | Given { caps; body } -> n "given" (List.map (expr c) caps @ [ block c body ])

(* A place is printed like the equivalent expression chain; the outermost step carries the span of the place. *)
and place c (pl : place) =
  let last = List.length pl.steps in
  let step (i, acc) s =
    let mk head items = if i + 1 = last then node ~subject:true c head pl.span items else group ~subject:true head items in
    match s with
    | Place_field f -> (i + 1, mk "dot" [ acc; ident c f ])
    | Place_index e -> (i + 1, mk "index" [ acc; expr c e ])
  in
  snd (List.fold_left step (0, ident c pl.root) pl.steps)

and with_item c (w : with_item) =
  match w.name with None -> expr c w.value | Some nm -> node c "bind" w.span [ ident c nm; expr c w.value ]

and pattern c (pt : pattern) =
  let n ?subject head items = node ?subject c head pt.span items in
  match pt.pat with
  | Pat_wild -> named c "_" pt.span
  | Pat_bind i -> ident c i
  | Pat_lit lp -> lit_pattern c lp
  | Pat_range { lo; hi; inclusive } -> n (if inclusive then "..=" else "..") [ lit_pattern c lo; lit_pattern c hi ]
  | Pat_ctor { path = p; fields } -> n "ctor" (path c p :: List.map (field_pattern c) fields)
  | Pat_tuple ps -> n "tuple" (List.map (pattern c) ps)
  | Pat_list lps -> n "list" (List.map (list_pattern c) lps)
  | Pat_or ps -> n "|" (List.map (pattern c) ps)
  | Pat_as { pat; name } -> n ~subject:true "as" [ pattern c pat; ident c name ]

and lit_pattern c (lp : lit_pattern) =
  let l = literal c lp.span lp.lit in
  if lp.negated then node c "-" lp.span [ l ] else l

and field_pattern c = function
  | Fp_field { label = None; pat; _ } -> pattern c pat
  | Fp_field { label = Some l; pat; span } -> node c "label" span [ ident c l; pattern c pat ]
  | Fp_rest span -> named c ".." span

and list_pattern c = function
  | Lp_elem p -> pattern c p
  | Lp_rest { name = None; span } -> named c ".." span
  | Lp_rest { name = Some nm; span } -> node c ".." span [ ident c nm ]

and ty c (t : ty) =
  let n ?subject head items = node ?subject c head t.span items in
  match t.ty with
  | Ty_path { path = p; args = [] } -> named c (path_s p) t.span
  | Ty_path { path = p; args } -> n "apply" (path c p :: List.map (type_arg c) args)
  | Ty_tuple ts -> n "tuple-type" (List.map (ty c) ts)
  | Ty_fn { params; ret; using } ->
      n "fn-type"
        ((group "params" (List.map (ty c) params) :: opt (fun r -> group "->" [ ty c r ]) ret)
        @ if using = [] then [] else [ group "using" (List.map (ty c) using) ])
  | Ty_dyn b -> n "dyn" [ ty c b ]
  | Ty_self -> named c "Self" t.span
  | Ty_optional inner -> n "?" [ ty c inner ]

and type_arg c = function Ta_type t -> ty c t | Ta_expr e -> expr c e

(* ---------- declarations ---------- *)

let attribute c (a : attribute) =
  node c "@" a.span (ident c a.name :: opt (fun args -> group "args" (List.map (expr c) args)) a.args)

let doc_attrs c doc attrs = doc_atoms doc @ List.map (attribute c) attrs

let generics c = function
  | [] -> []
  | gs ->
      let generic (g : generic) =
        node c "generic" g.span ((flag g.comptime "comptime" @ [ ident c g.name ]) @ List.map (ty c) g.bounds)
      in
      [ group "generics" (List.map generic gs) ]

let typed c (ti : typed_ident) = List { keep = 0; items = (ident c ti.name :: span_atoms c ti.span) @ [ ty c ti.ty ] }

let param c (pr : param) =
  match pr.kind with
  | Param_self -> node c "param" pr.span (mode_flags pr.mode @ [ Atom "self" ])
  | Param_named { name; ty = t; default } ->
      node c "param" pr.span
        ((mode_flags pr.mode @ [ ident c name; ty c t ]) @ opt (fun d -> group "default" [ expr c d ]) default)

(* Everything of a signature after its name and doc/attributes. *)
let fn_parts c (sg : fn_sig) =
  generics c sg.generics
  @ [ group "params" (List.map (param c) sg.params) ]
  @ opt (fun t -> group "->" [ ty c t ]) sg.ret
  @ match sg.using with [] -> [] | u -> [ group "using" (List.map (typed c) u) ]

let fn_node c ~head ~flags ~da sp (sg : fn_sig) body =
  node c head sp ((flags @ [ ident c sg.name ]) @ da @ fn_parts c sg @ opt (block c) body)

let field c (f : field) =
  node c "field" f.span
    ((flag f.pub "pub" @ [ ident c f.name ]) @ doc_attrs c f.doc f.attrs @ [ ty c f.ty ]
    @ opt (fun d -> group "default" [ expr c d ]) f.default)

let variant c (v : variant) =
  let fields =
    match v.fields with
    | Vf_none -> []
    | Vf_positional ts -> [ group "positional" (List.map (ty c) ts) ]
    | Vf_named tis -> [ group "named" (List.map (typed c) tis) ]
  in
  node c "variant" v.span ((ident c v.name :: doc_atoms v.doc) @ fields)

let trait_item c (ti : trait_item) =
  let da = doc_atoms ti.doc in
  match ti.item with
  | Ti_sig sg -> fn_node c ~head:"fn-sig" ~flags:[] ~da ti.span sg None
  | Ti_fn f -> fn_node c ~head:"fn" ~flags:[] ~da ti.span f.sig_ (Some f.body)
  | Ti_type { name; bound } -> node c "assoc-type" ti.span ((ident c name :: da) @ opt (ty c) bound)

let impl_item c (ii : impl_item) =
  match ii.item with
  | Ii_fn { attrs; pub; fn_ } ->
      fn_node c ~head:"fn" ~flags:(flag pub "pub") ~da:(doc_attrs c ii.doc attrs) ii.span fn_.sig_ (Some fn_.body)
  | Ii_type { name; ty = t } -> node c "assoc-type" ii.span ((ident c name :: doc_atoms ii.doc) @ [ ty c t ])

let decl c (d : decl) =
  let pub = flag d.pub "pub" and da = doc_attrs c d.doc d.attrs in
  let n ?subject head items = node ?subject c head d.span items in
  match d.decl with
  | Fn f -> fn_node c ~head:"fn" ~flags:pub ~da d.span f.sig_ (Some f.body)
  | Struct { name; generics = g; fields } ->
      n "struct" ((pub @ [ ident c name ]) @ da @ generics c g @ List.map (field c) fields)
  | Enum { name; generics = g; variants } ->
      n "enum" ((pub @ [ ident c name ]) @ da @ generics c g @ List.map (variant c) variants)
  | Trait { name; generics = g; supertraits; items } ->
      let supers = if supertraits = [] then [] else [ group "supertraits" (List.map (ty c) supertraits) ] in
      n "trait" ((pub @ [ ident c name ]) @ da @ generics c g @ supers @ List.map (trait_item c) items)
  | Impl { generics = g; trait_; self_ty; items } ->
      n ~subject:true "impl"
        ((pub @ [ ty c self_ty ]) @ da
        @ opt (fun t -> group "trait" [ ty c t ]) trait_
        @ generics c g @ List.map (impl_item c) items)
  | Type { name; generics = g; newtype; ty = t; where_ } ->
      n "type"
        ((pub @ flag newtype "new" @ [ ident c name ]) @ da @ generics c g @ [ ty c t ]
        @ opt (fun w -> group "where" [ expr c w ]) where_)
  | Const { comptime; name; ty = t; value } ->
      n "let" ((pub @ flag comptime "comptime" @ [ ident c name ]) @ da @ annot c t @ [ expr c value ])

(* ---------- files ---------- *)

let import c (im : import) =
  let alias = function None -> [] | Some a -> [ Atom "as"; ident c a ] in
  match im.import with
  | Import { path = p; items; alias = a } ->
      let item (it : import_item) =
        match it.alias with
        | None -> ident c it.name
        | Some al -> List { keep = 0; items = [ ident c it.name; Atom "as"; ident c al ] }
      in
      node c "import" im.span ((path c p :: opt (fun its -> group "items" (List.map item its)) items) @ alias a)
  | Import_go { package; package_span; alias = a } ->
      node c "import-go" im.span (named c (quote package) package_span :: alias (Some a))

let file_s c (f : file) =
  let header = node c "module" f.span (path c f.module_path :: doc_atoms f.doc) in
  let item sx = "  " ^ to_string ~indent:2 sx in
  String.concat "\n"
    ((to_string header :: List.map (fun i -> item (import c i)) f.imports) @ List.map (fun d -> item (decl c d)) f.decls)

(* ---------- public interface ---------- *)

let ctx spans = { spans }
let file ?(spans = false) f = file_s (ctx spans) f
let decl ?(spans = false) d = to_string (decl (ctx spans) d)
let stmt ?(spans = false) s = to_string (stmt (ctx spans) s)
let block ?(spans = false) b = to_string (block (ctx spans) b)
let expr ?(spans = false) e = to_string (expr (ctx spans) e)
let pattern ?(spans = false) p = to_string (pattern (ctx spans) p)
let ty ?(spans = false) t = to_string (ty (ctx spans) t)
let pp_with f fmt v = Format.pp_print_string fmt (f v)
let pp_file fmt v = pp_with (fun v -> file v) fmt v
let pp_decl fmt v = pp_with (fun v -> decl v) fmt v
let pp_stmt fmt v = pp_with (fun v -> stmt v) fmt v
let pp_block fmt v = pp_with (fun v -> block v) fmt v
let pp_expr fmt v = pp_with (fun v -> expr v) fmt v
let pp_pattern fmt v = pp_with (fun v -> pattern v) fmt v
let pp_ty fmt v = pp_with (fun v -> ty v) fmt v
