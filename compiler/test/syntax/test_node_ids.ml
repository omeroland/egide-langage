(* Tests for Node_id and the ids stored in the AST (T-1006, docs/architecture.md §2 invariants 3 to 5).
   [ids_of_file] walks the whole tree and lists the id of every node that carries one; it is the test oracle for
   "unique within a parsed file". It must be extended when a node gains an id (ast.mli lists them). *)

open Egide_syntax
open Ast

let parse ?gen src =
  match Parse.file ?gen ~file:"t.egd" src with Some f, _ -> f | None, _ -> failwith "parse failed"

(* ---------- the oracle: every id of a tree, in visiting order ---------- *)

let ids_of_file (f : file) =
  let acc = ref [] in
  let add id = acc := id :: !acc in
  let opt g = Option.iter g in
  let ident (i : ident) = add i.id in
  let path (p : path) =
    add p.id;
    List.iter ident p.segments
  in
  let rec expr (x : expr) =
    add x.id;
    match x.expr with
    | Lit l -> literal l
    | Path p -> path p
    | Self | Self_type -> ()
    | Paren e | Try e -> expr e
    | Tuple es | List es | Set es -> List.iter expr es
    | Map ms -> List.iter map_entry ms
    | Comprehension { kind; clauses } ->
        (match kind with
        | Comp_list e | Comp_set e | Comp_iter e -> expr e
        | Comp_map m -> map_entry m);
        List.iter
          (function
            | Comp_for { pat; iter; _ } ->
                pattern pat;
                expr iter
            | Comp_if { cond; _ } -> expr cond)
          clauses
    | If { branches; else_ } ->
        List.iter
          (fun (b : if_branch) ->
            expr b.cond;
            block b.body)
          branches;
        opt block else_
    | Match { scrutinee; arms } ->
        expr scrutinee;
        List.iter
          (fun (a : case_arm) ->
            pattern a.pat;
            opt expr a.guard;
            block a.body)
          arms
    | Loop b -> block b
    | With { items; body } ->
        List.iter
          (fun (w : with_item) ->
            opt ident w.name;
            expr w.value)
          items;
        block body
    | Given { caps; body } ->
        List.iter expr caps;
        block body
    | Unsafe { body; _ } -> block body
    | Call { callee; args } ->
        expr callee;
        List.iter arg args
    | Index { target; args } ->
        expr target;
        List.iter gen_arg args
    | Field { target; name } ->
        expr target;
        ident name
    | Unary { operand; _ } -> expr operand
    | Binary { lhs; rhs; _ } ->
        expr lhs;
        expr rhs
    | Compare { first; rest } ->
        expr first;
        List.iter (fun (_, e) -> expr e) rest
    | Range { lo; hi } ->
        opt expr lo;
        opt expr hi
    | Range_incl { lo; hi } ->
        opt expr lo;
        expr hi
    | Cond { cond; then_; else_ } ->
        expr cond;
        expr then_;
        expr else_
    | Lambda { params; body } ->
        List.iter lambda_param params;
        expr body
    | Fn_lit { params; ret; body } ->
        List.iter lambda_param params;
        opt ty ret;
        block body
    | Trailing_call { callee; args; params; ret; body } ->
        expr callee;
        List.iter arg args;
        List.iter lambda_param params;
        opt ty ret;
        block body
  and literal = function
    | Template { prefix; parts } ->
        ident prefix;
        List.iter (function Text _ -> () | Interp e -> expr e) parts
    (* The other literals hold only text, numbers or characters: no node, no id. *)
    | Int _ | Float _ | Duration _ | String _ | Raw_string _ | Bytes _ | Char _ | Bool _ -> ()
  and map_entry (m : map_entry) =
    expr m.key;
    expr m.value
  and arg (a : arg) =
    add a.id;
    match a.arg with
    | Arg_plain { label; value } | Arg_inout { label; value } ->
        opt ident label;
        expr value
    | Arg_using (n, v) ->
        ident n;
        expr v
  and gen_arg = function Ga_expr e -> expr e | Ga_type_only t -> ty t
  and bound (b : bound) =
    add b.id;
    path b.path;
    List.iter gen_arg b.args
  and lambda_param (p : lambda_param) =
    ident p.name;
    opt ty p.ty
  and block (b : block) =
    add b.id;
    List.iter stmt b.stmts
  and stmt (st : stmt) =
    add st.id;
    match st.stmt with
    | Expr e | Defer e | Yield e -> expr e
    | Let { pat; ty = t; value; else_ } ->
        pattern pat;
        opt ty t;
        expr value;
        opt block else_
    | Var { name; ty = t; value } | Comptime_let { name; ty = t; value } ->
        ident name;
        opt ty t;
        expr value
    | Assign { target; value; _ } ->
        expr target;
        expr value
    | Return e | Break e -> opt expr e
    | Continue -> ()
    | For { pat; iter; body } ->
        pattern pat;
        expr iter;
        block body
    | While { cond; body } ->
        expr cond;
        block body
  and pattern (p : pattern) =
    add p.id;
    match p.pat with
    | Pat_wild -> ()
    | Pat_bind i -> ident i
    | Pat_const pa -> path pa
    | Pat_lit lp -> literal lp.lit
    | Pat_range { lo; hi; _ } ->
        literal lo.lit;
        literal hi.lit
    | Pat_ctor { path = pa; fields } ->
        path pa;
        List.iter
          (function
            | Fp_field { label; pat; _ } ->
                opt ident label;
                pattern pat
            | Fp_rest _ -> ())
          fields
    | Pat_tuple ps | Pat_or ps -> List.iter pattern ps
    | Pat_list lps ->
        List.iter (function Lp_elem p -> pattern p | Lp_rest { name; _ } -> opt ident name) lps
    | Pat_as { pat; name } ->
        pattern pat;
        ident name
  and ty (t : ty) =
    add t.id;
    match t.ty with
    | Ty_path { path = pa; args } ->
        path pa;
        List.iter gen_arg args
    | Ty_tuple ts -> List.iter ty ts
    | Ty_fn { params; ret; using } ->
        List.iter ty params;
        opt ty ret;
        List.iter bound using
    | Ty_dyn bs -> List.iter bound bs
    | Ty_self -> ()
    | Ty_optional t -> ty t
  in
  let attribute (a : attribute) =
    ident a.name;
    opt (List.iter expr) a.args
  in
  let generic (g : generic) =
    add g.id;
    ident g.name;
    List.iter bound g.bounds
  in
  let typed (ti : typed_ident) =
    ident ti.name;
    ty ti.ty
  in
  let param (p : param) =
    add p.id;
    match p.kind with
    | Param_self -> ()
    | Param_named { name; ty = t; default } ->
        ident name;
        ty t;
        opt expr default
  in
  let fn_sig (sg : fn_sig) =
    ident sg.name;
    List.iter generic sg.generics;
    List.iter param sg.params;
    opt ty sg.ret;
    List.iter typed sg.using
  in
  let fn_decl (fd : fn_decl) =
    add fd.id;
    fn_sig fd.sig_;
    block fd.body
  in
  let field (fl : field) =
    add fl.id;
    List.iter attribute fl.attrs;
    ident fl.name;
    ty fl.ty;
    opt expr fl.default
  in
  let variant (v : variant) =
    add v.id;
    ident v.name;
    match v.fields with
    | Vf_none -> ()
    | Vf_positional ts -> List.iter ty ts
    | Vf_named tis -> List.iter typed tis
  in
  let trait_item (ti : trait_item) =
    add ti.id;
    match ti.item with
    | Ti_sig sg -> fn_sig sg
    | Ti_fn fd -> fn_decl fd
    | Ti_type { name; bound = b } ->
        ident name;
        opt bound b
  in
  let impl_item (ii : impl_item) =
    add ii.id;
    match ii.item with
    | Ii_fn { attrs; fn_; _ } ->
        List.iter attribute attrs;
        fn_decl fn_
    | Ii_type { name; ty = t } ->
        ident name;
        ty t
  in
  let decl (d : decl) =
    add d.id;
    List.iter attribute d.attrs;
    match d.decl with
    | Fn fd -> fn_decl fd
    | Struct { name; generics; fields } ->
        ident name;
        List.iter generic generics;
        List.iter field fields
    | Enum { name; generics; variants } ->
        ident name;
        List.iter generic generics;
        List.iter variant variants
    | Trait { name; generics; supertraits; items } ->
        ident name;
        List.iter generic generics;
        List.iter bound supertraits;
        List.iter trait_item items
    | Impl { generics; trait_; self_ty; items } ->
        List.iter generic generics;
        opt ty trait_;
        ty self_ty;
        List.iter impl_item items
    | Type { name; generics; def } -> (
        ident name;
        List.iter generic generics;
        match def with
        | Alias t -> ty t
        | Newtype { ty = t; where_ } ->
            ty t;
            opt expr where_)
    | Const { name; ty = t; value } ->
        ident name;
        opt ty t;
        expr value
  in
  let import (im : import) =
    match im.import with
    | Import { path = p; form } -> (
        path p;
        match form with
        | Whole -> ()
        | Alias_as a -> ident a
        | Items its ->
            List.iter
              (fun (it : import_item) ->
                ident it.name;
                opt ident it.alias)
              its)
    | Import_go { alias; _ } -> ident alias
  in
  path f.module_path;
  List.iter import f.imports;
  List.iter decl f.decls;
  List.rev !acc

let ints ids = List.map Node_id.to_int ids
let sorted ids = List.sort compare (ints ids)
let below_count gen ids = List.for_all (fun id -> Node_id.to_int id < Node_id.Gen.count gen) ids
let all_distinct ids = List.length (List.sort_uniq compare (ints ids)) = List.length ids

(* ---------- Node_id and its generator ---------- *)

let%expect_test "generator: sequential ids from 0, independent generators" =
  let g = Node_id.Gen.create () and h = Node_id.Gen.create () in
  let a = Node_id.Gen.fresh g in
  let b = Node_id.Gen.fresh g in
  let c = Node_id.Gen.fresh g in
  let h0 = Node_id.Gen.fresh h in
  Printf.printf "ints: %d %d %d, other generator: %d, count: %d %d\n" (Node_id.to_int a)
    (Node_id.to_int b) (Node_id.to_int c) (Node_id.to_int h0) (Node_id.Gen.count g)
    (Node_id.Gen.count h);
  Printf.printf "equal: %b %b, compare: %d %d %d\n" (Node_id.equal a a) (Node_id.equal a b)
    (Node_id.compare a b) (Node_id.compare b a) (Node_id.compare c c);
  Printf.printf "hash agrees with equal: %b; pp: %s\n"
    (Node_id.hash a = Node_id.hash (Node_id.Gen.fresh (Node_id.Gen.create ())))
    (Format.asprintf "%a" Node_id.pp c);
  [%expect
    {|
    ints: 0 1 2, other generator: 0, count: 3 1
    equal: true false, compare: -1 1 0
    hash agrees with equal: true; pp: #2
    |}]

(* ---------- ids of a parsed file ---------- *)

let src =
  "module api.tenants\nimport std.fmt\nimport egide.pg as pg\nlet LIMIT = 10\nlet ok = true\n"

(* spec: none (architecture §2.3); unique ids over a parsed file, all below [Gen.count]. Contiguity is deliberately not
   asserted: recovery (T-0013) and cover-grammar conversions (SYN-065) will leave holes (see node_id.mli). *)
let%expect_test "a parsed file: ids are unique and below the generator count" =
  let gen = Node_id.Gen.create () in
  let f = parse ~gen src in
  let ids = ids_of_file f in
  Printf.printf "nodes: %d, distinct: %b, all below count: %b\n" (List.length ids)
    (all_distinct ids) (below_count gen ids);
  [%expect {| nodes: 16, distinct: true, all below count: true |}]

(* spec: none (architecture §2.4); same input, same ids, in the same order *)
let%expect_test "the same source gives the same ids" =
  let a = parse src and b = parse src in
  Printf.printf "same ids: %b, structurally equal: %b\n"
    (ints (ids_of_file a) = ints (ids_of_file b))
    (equal_file a b);
  [%expect {| same ids: true, structurally equal: true |}]

(* spec: none (architecture §2.5); no global state: parsing does not depend on earlier parses *)
let%expect_test "ids do not depend on earlier parses; a shared generator continues the numbering" =
  let baseline = ints (ids_of_file (parse src)) in
  ignore (parse "module a\nlet x = 1\nlet y = 2\n");
  let again = ints (ids_of_file (parse src)) in
  Printf.printf "same ids after an unrelated parse: %b, starting at 0: %b\n" (again = baseline)
    (List.mem 0 again);
  let gen = Node_id.Gen.create () in
  let f1 = parse ~gen "module a\nlet x = 1\n" in
  let n1 = Node_id.Gen.count gen in
  let f2 = parse ~gen "module b\nlet y = 2\n" in
  let i1 = ids_of_file f1 and i2 = ids_of_file f2 in
  Printf.printf "first file: %d ids; second file ids start at %d; disjoint: %b\n" n1
    (List.hd (sorted i2))
    (all_distinct (i1 @ i2));
  [%expect
    {|
    same ids after an unrelated parse: true, starting at 0: true
    first file: 5 ids; second file ids start at 5; disjoint: true
    |}]

(* ---------- Print ---------- *)

let%expect_test "Print omits ids by default and shows them with ~ids:true" =
  let f = parse "module m\nimport a.b as c\nlet x = 1\n" in
  Printf.printf "default = ~ids:false: %b\n" (Print.file f = Print.file ~ids:false f);
  print_endline (Print.file ~ids:true f);
  print_endline (Print.file ~spans:true ~ids:true f);
  [%expect
    {|
    default = ~ids:false: true
    (module m#1)
      (import a.b#4 as c#5)
      (let #8 x#6 (int #7 1))
    (module @1:1-3:10 m@1:8-1:9#1)
      (import @2:1-2:16 a.b@2:8-2:11#4 as c@2:15-2:16#5)
      (let @3:1-3:10 #8 x@3:5-3:6#6 (int @3:9-3:10 #7 1))
    |}]

(* ---------- every node kind carries an id, and the oracle sees it ---------- *)

(* A tree with one node of every kind that has an id, built with one generator: the oracle must list each id exactly
   once. This checks the oracle against the type (a kind it forgot would show as a missing id) and the uniqueness
   of hand-built trees; the parser itself only produces the seed subset until T-0009..T-0012. *)
let%expect_test "a hand-built tree with every id-bearing kind: one id each" =
  let gen = Node_id.Gen.create () in
  let sp = Egide_source.Span.dummy in
  let nid () = Node_id.Gen.fresh gen in
  let id n : ident = { id = nid (); name = n; span = sp } in
  let path n : path = { id = nid (); segments = [ id n ]; span = sp } in
  let e expr : expr = { id = nid (); expr; span = sp } in
  let p pat : pattern = { id = nid (); pat; span = sp } in
  let t ty : ty = { id = nid (); ty; span = sp } in
  let blk stmts : block = { id = nid (); stmts; span = sp } in
  let s stmt : stmt = { id = nid (); stmt; span = sp } in
  let bound n : bound = { id = nid (); path = path n; args = []; span = sp } in
  let tn n = t (Ty_path { path = path n; args = [] }) in
  let a : arg =
    { id = nid (); arg = Arg_plain { label = None; value = e (Path (path "x")) }; span = sp }
  in
  let fsig n params : fn_sig =
    { name = id n; generics = []; params; ret = None; using = []; span = sp }
  in
  let prm () : param = { id = nid (); mode = By_read; kind = Param_self; span = sp } in
  let fd n : fn_decl =
    { id = nid (); sig_ = fsig n [ prm () ]; body = blk [ s Continue ]; span = sp }
  in
  let gn : generic =
    { id = nid (); comptime = false; name = id "T"; bounds = [ bound "Eq" ]; span = sp }
  in
  let fl : field =
    {
      id = nid ();
      attrs = [];
      vis = Private;
      name = id "f";
      ty = tn "int";
      default = None;
      span = sp;
    }
  in
  let vr : variant = { id = nid (); name = id "V"; fields = Vf_none; span = sp } in
  let ti : trait_item = { id = nid (); item = Ti_fn (fd "m"); span = sp } in
  let ii : impl_item =
    { id = nid (); item = Ii_type { name = id "A"; ty = tn "int" }; span = sp }
  in
  let d desc : decl = { id = nid (); attrs = []; vis = Private; decl = desc; span = sp } in
  let call = e (Call { callee = e (Path (path "f")); args = [ a ] }) in
  let arm : case_arm = { pat = p (Pat_bind (id "z")); guard = None; body = blk []; span = sp } in
  let matcher = e (Match { scrutinee = e Self; arms = [ arm ] }) in
  let decls =
    [
      d (Fn (fd "main"));
      d (Struct { name = id "S"; generics = [ gn ]; fields = [ fl ] });
      d (Enum { name = id "E"; generics = []; variants = [ vr ] });
      d (Trait { name = id "Tr"; generics = []; supertraits = []; items = [ ti ] });
      d (Impl { generics = []; trait_ = None; self_ty = tn "S"; items = [ ii ] });
      d (Const { name = id "C"; ty = None; value = call });
      d (Const { name = id "K"; ty = None; value = matcher });
    ]
  in
  let f : file = { module_path = path "m"; imports = []; decls; span = sp } in
  let ids = ids_of_file f in
  Printf.printf "nodes: %d, allocated: %d, distinct: %b\n" (List.length ids) (Node_id.Gen.count gen)
    (all_distinct ids);
  [%expect {| nodes: 58, allocated: 58, distinct: true |}]

(* ---------- property: seed-subset programs ---------- *)

let gen_source =
  let open QCheck2.Gen in
  let name = map (fun n -> "x" ^ string_of_int n) (int_bound 9) in
  let dotted = map (String.concat ".") (list_size (int_range 1 4) name) in
  let* imports = list_size (int_bound 4) (pair dotted (option name)) in
  let value =
    oneof
      [
        map string_of_int (int_bound 99);
        return "true";
        return "false";
        return "1.5";
        return {|"s"|};
        dotted;
      ]
  in
  let+ consts = list_size (int_bound 6) (pair name value) in
  let imp (m, alias) = "import a." ^ m ^ match alias with None -> "" | Some al -> " as " ^ al in
  String.concat "\n"
    (("module m" :: List.map imp imports) @ List.map (fun (n, v) -> "let " ^ n ^ " = " ^ v) consts)
  ^ "\n"

let prop_ids =
  QCheck2.Test.make ~name:"ids unique, below count and deterministic on seed-subset programs"
    ~count:500
    ~print:(fun s -> s)
    gen_source
    (fun src ->
      let gen = Node_id.Gen.create () in
      let f = parse ~gen src in
      let ids = ids_of_file f in
      all_distinct ids && below_count gen ids && ints ids = ints (ids_of_file (parse src)))

(* spec: none (architecture §2.4) *)
let%expect_test "id properties" =
  QCheck2.Test.check_exn ~rand:(Random.State.make [| 11 |]) prop_ids;
  print_endline "ok";
  [%expect {| ok |}]
