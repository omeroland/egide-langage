(* Unit tests for Ast and Print (T-0008). The parser only covers the seed subset, so most trees are built by hand:
   each test reproduces a spec example or EBNF production and snapshots its S-expression rendering. *)

open Egide_syntax
open Ast

let sp = Egide_source.Span.dummy

(* ---------- builders ---------- *)

let id name : ident = { name; span = sp }
let path s : path = { segments = List.map id (String.split_on_char '.' s); span = sp }
let e expr : expr = { expr; span = sp }
let p pat : pattern = { pat; span = sp }
let t ty : ty = { ty; span = sp }
let s stmt : stmt = { stmt; span = sp }
let blk stmts : block = { stmts; span = sp }
let x name = e (Path (path name))
let int n = e (Lit (Int n))
let str v = e (Lit (String v))
let bool b = e (Lit (Bool b))
let tn name = t (Ty_path { path = path name; args = [] })

(* A type written as a generic argument is an expression until resolution (SYN-042): a path is a [Path], an
   application is an [Index], a type-only form stays a type. *)
let rec ga_of_ty (ty : ty) : gen_arg =
  match ty.ty with
  | Ty_path { path = pa; args = [] } -> Ga_expr (e (Path pa))
  | Ty_path { path = pa; args } -> Ga_expr (e (Index { target = e (Path pa); args }))
  | Ty_optional inner -> (
      match ga_of_ty inner with Ga_expr ex -> Ga_expr (e (Try ex)) | Ga_type_only _ as g -> g)
  | _ -> Ga_type_only ty

let tapp name args = t (Ty_path { path = path name; args = List.map ga_of_ty args })
let bound ?(args = []) name : bound = { path = path name; args; span = sp }
let bin op lhs rhs = e (Binary { op; lhs; rhs })

let arg ?label ?(inout = false) value : arg =
  let label = Option.map id label in
  { arg = (if inout then Arg_inout { label; value } else Arg_plain { label; value }); span = sp }

let using_arg name value : arg = { arg = Arg_using (id name, value); span = sp }
let call f args = e (Call { callee = f; args })
let dot target name = e (Field { target; name = id name })
let pbind n = p (Pat_bind (id n))
let lit_pat ?(negated = false) lit : lit_pattern = { negated; lit; span = sp }
let lparam ?(mode = By_read) ?ty name : lambda_param = { mode; name = id name; ty; span = sp }
let typed name ty : typed_ident = { name = id name; ty; span = sp }

let param ?(mode = By_read) ?default name ty : param =
  { mode; kind = Param_named { name = id name; ty; default }; span = sp }

let self_param mode : param = { mode; kind = Param_self; span = sp }

let fsig ?(generics = []) ?ret ?(using = []) name params : fn_sig =
  { name = id name; generics; params; ret; using; span = sp }

let fn_decl sig_ stmts : fn_decl = { sig_; body = blk stmts; span = sp }
let decl ?(attrs = []) ?(vis = Private) d : decl = { attrs; vis; decl = d; span = sp }
let attr ?args name : attribute = { name = id name; args; span = sp }

let field ?(attrs = []) ?(vis = Private) ?default name ty : field =
  { attrs; vis; name = id name; ty; default; span = sp }

let variant ?(fields = Vf_none) name : variant = { name = id name; fields; span = sp }

let generic ?(comptime = false) ?(bounds : bound list = []) name : generic =
  { comptime; name = id name; bounds; span = sp }

let file ?(imports = []) m decls : file = { module_path = path m; imports; decls; span = sp }
let import d : import = { import = d; span = sp }
let print_decl d = print_endline (Print.decl d)
let print_expr ex = print_endline (Print.expr ex)
let print_stmt st = print_endline (Print.stmt st)

(* ---------- files and imports ---------- *)

(* spec: SYN-001, SYN-002 *)
let%expect_test "file with every import form" =
  let item ?alias n : import_item = { name = id n; alias = Option.map id alias; span = sp } in
  let f =
    file "api.tenants"
      ~imports:
        [
          import (Import { path = path "std.fmt"; form = Whole });
          import
            (Import
               {
                 path = path "std.http";
                 form = Items [ item "Server"; item "Request" ~alias:"Req" ];
               });
          import (Import { path = path "egide.pg"; form = Alias_as (id "pg") });
          import
            (Import_go
               { package = "k8s.io/client-go/kubernetes"; package_span = sp; alias = id "kube" });
        ]
      [ decl (Const { name = id "LIMIT"; ty = None; value = int "10" }) ]
  in
  print_endline (Print.file f);
  [%expect
    {|
    (module api.tenants)
      (import std.fmt)
      (import std.http (items Server (Request as Req)))
      (import egide.pg as pg)
      (import-go "k8s.io/client-go/kubernetes" as kube)
      (let LIMIT (int 10))
    |}]

(* ---------- declarations ---------- *)

(* spec: SYN-003, SYN-023 — the example of spec §3.3 *)
let%expect_test "struct, enum, trait, impl and type declarations of spec 3.3" =
  print_decl
    (decl ~vis:Pub
       (Struct
          {
            name = id "Article";
            generics = [];
            fields =
              [
                field "name" (tn "str");
                field "price" (tn "Money");
                field "stock" (tn "int") ~default:(int "0");
              ];
          }));
  print_decl
    (decl ~vis:Pub
       (Enum
          {
            name = id "State";
            generics = [];
            variants =
              [
                variant "Available";
                variant "OutOfStock";
                variant "Discontinued" ~fields:(Vf_named [ typed "reason" (tn "str") ]);
              ];
          }));
  print_decl
    (decl ~vis:Pub
       (Trait
          {
            name = id "Display";
            generics = [];
            supertraits = [];
            items =
              [
                { item = Ti_sig (fsig "display" [ self_param By_read ] ~ret:(tn "str")); span = sp };
              ];
          }));
  let display_body =
    e
      (Lit
         (Template
            {
              prefix = id "f";
              parts =
                [
                  Interp (dot (e Self) "name");
                  Text { text = " ("; span = sp };
                  Interp (dot (e Self) "stock");
                  Text { text = ")"; span = sp };
                ];
            }))
  in
  print_decl
    (decl
       (Impl
          {
            generics = [];
            trait_ = Some (tn "Display");
            self_ty = tn "Article";
            items =
              [
                {
                  item =
                    Ii_fn
                      {
                        attrs = [];
                        vis = Private;
                        fn_ =
                          fn_decl
                            (fsig "display" [ self_param By_read ] ~ret:(tn "str"))
                            [ s (Expr display_body) ];
                      };
                  span = sp;
                };
              ];
          }));
  print_decl
    (decl
       (Type { name = id "UserId"; generics = []; def = Newtype { ty = tn "int"; where_ = None } }));
  let range_check = e (Compare { first = int "1"; rest = [ (Le, e Self); (Le, int "65535") ] }) in
  print_decl
    (decl
       (Type
          {
            name = id "Port";
            generics = [];
            def = Newtype { ty = tn "u16"; where_ = Some range_check };
          }));
  print_decl
    (decl
       (Type
          {
            name = id "Headers";
            generics = [];
            def = Alias (tapp "Map" [ tn "str"; tapp "List" [ tn "str" ] ]);
          }));
  [%expect
    {|
    (struct pub Article (field name str) (field price Money) (field stock int (default (int 0))))
    (enum pub State
      (variant Available)
      (variant OutOfStock)
      (variant Discontinued (named (reason str))))
    (trait pub Display (fn-sig display (params (param self)) (-> str)))
    (impl Article
      (trait Display)
      (fn display
        (params (param self))
        (-> str)
        (block (template f (dot (self) name) (text " (") (dot (self) stock) (text ")")))))
    (type new UserId int)
    (type new Port u16 (where (cmp (int 1) <= (self) <= (int 65535))))
    (type Headers (apply Map (path str) (index (path List) (path str))))
    |}]

(* spec: SYN-020, SYN-021, SYN-022, SYN-023 *)
let%expect_test "function declaration with attributes, generics, modes, defaults and using" =
  let f =
    fsig "copy_into"
      ~generics:[ generic "T" ~bounds:[ bound "Eq"; bound "Show" ]; generic ~comptime:true "N" ]
      [
        self_param Inout;
        param ~mode:Take "src" (tapp "List" [ tn "T" ]);
        param ~mode:Comptime "width" (tn "int") ~default:(int "16");
        param "label" (tn "str") ~default:(str "x");
      ]
      ~ret:(t (Ty_tuple []))
      ~using:[ typed "net" (tn "Net"); typed "clock" (tn "Clock") ]
  in
  print_decl
    (decl ~vis:Pub
       ~attrs:[ attr "test"; attr "derive" ~args:[ x "Eq"; x "Show" ]; attr "acyclic" ~args:[] ]
       (Fn (fn_decl f [ s (Return None) ])));
  print_decl
    (decl ~vis:Pub_package (Const { name = id "N"; ty = Some (tn "int"); value = int "4" }));
  [%expect
    {|
    (fn pub copy_into
      (@ test)
      (@ derive (args (path Eq) (path Show)))
      (@ acyclic (args))
      (generics (generic T Eq Show) (generic comptime N))
      (params
        (param inout self)
        (param take src (apply List (path T)))
        (param comptime width int (default (int 16)))
        (param label str (default (string "x"))))
      (-> (tuple-type))
      (using (net Net) (clock Clock))
      (block (return)))
    (let pub(package) N (: int) (int 4))
    |}]

(* spec: SYN-003 *)
let%expect_test
    "trait with supertraits, provided method and associated type; impl with associated type" =
  print_decl
    (decl
       (Trait
          {
            name = id "Collection";
            generics = [ generic "T" ];
            supertraits = [ bound "Len"; bound "Show" ];
            items =
              [
                { item = Ti_type { name = id "Item"; bound = Some (bound "Eq") }; span = sp };
                { item = Ti_type { name = id "Key"; bound = None }; span = sp };
                {
                  item =
                    Ti_fn
                      (fn_decl
                         (fsig "empty" [ self_param By_read ] ~ret:(tn "bool"))
                         [ s (Expr (bool true)) ]);
                  span = sp;
                };
              ];
          }));
  print_decl
    (decl
       (Impl
          {
            generics = [ generic "T" ];
            trait_ = None;
            self_ty = tapp "Box" [ tn "T" ];
            items =
              [
                { item = Ii_type { name = id "Item"; ty = tn "T" }; span = sp };
                {
                  item =
                    Ii_fn
                      {
                        attrs = [ attr "inline" ];
                        vis = Pub;
                        fn_ = fn_decl (fsig "get" [ self_param Take ]) [ s (Expr (x "self_value")) ];
                      };
                  span = sp;
                };
              ];
          }));
  print_decl
    (decl
       (Enum
          {
            name = id "Shape";
            generics = [ generic "N" ];
            variants =
              [
                variant "Circle" ~fields:(Vf_positional [ tn "N" ]);
                variant "Rect" ~fields:(Vf_positional [ tn "N"; tn "N" ]);
              ];
          }));
  print_decl
    (decl
       (Struct
          {
            name = id "Point";
            generics = [];
            fields = [ field ~attrs:[ attr "skip" ] ~vis:Pub "x" (tn "int") ];
          }));
  [%expect
    {|
    (trait Collection
      (generics (generic T))
      (supertraits Len Show)
      (assoc-type Item Eq)
      (assoc-type Key)
      (fn empty (params (param self)) (-> bool) (block (bool true))))
    (impl (apply Box (path T))
      (generics (generic T))
      (assoc-type Item T)
      (fn pub get (@ inline) (params (param take self)) (block (path self_value))))
    (enum Shape (generics (generic N)) (variant Circle (positional N)) (variant Rect (positional N N)))
    (struct Point (field pub x (@ skip) int))
    |}]

(* ---------- types ---------- *)

(* spec: SYN-041 *)
let%expect_test "every type form" =
  let show ty = print_endline (Print.ty ty) in
  show (t (Ty_optional (tn "str")));
  show (t (Ty_path { path = path "std.Array"; args = [ ga_of_ty (tn "u8"); Ga_expr (int "16") ] }));
  show (t (Ty_tuple [ tn "int"; tn "str" ]));
  show (t (Ty_fn { params = [ tn "int" ]; ret = Some (tn "bool"); using = [ bound "Net" ] }));
  show (t (Ty_fn { params = []; ret = None; using = [] }));
  show (t (Ty_dyn [ bound "Display" ]));
  show (t Ty_self);
  [%expect
    {|
    (? str)
    (apply std.Array (path u8) (int 16))
    (tuple-type int str)
    (fn-type (params int) (-> bool) (using Net))
    (fn-type (params))
    (dyn Display)
    Self
    |}]

(* ---------- statements ---------- *)

(* spec: SYN-012 — one statement of each form of the table *)
let%expect_test "every statement form of SYN-012" =
  let body = blk [ s (Expr (call (x "work") [])) ] in
  List.iter print_stmt
    [
      s (Let { pat = pbind "a"; ty = Some (tn "int"); value = int "1"; else_ = None });
      s
        (Let
           {
             pat =
               p
                 (Pat_ctor
                    {
                      path = path "Some";
                      fields = [ Fp_field { label = None; pat = pbind "v"; span = sp } ];
                    });
             ty = None;
             value = x "opt";
             else_ = Some (blk [ s (Return None) ]);
           });
      s (Var { name = id "n"; ty = None; value = int "0" });
      s (Comptime_let { name = id "K"; ty = Some (tn "int"); value = int "3" });
      s (Assign { target = x "n"; op = Simple_assign; value = int "2" });
      s
        (Assign
           {
             target = e (Index { target = dot (x "t") "items"; args = [ Ga_expr (int "0") ] });
             op = Add_assign;
             value = int "1";
           });
      s (Assign { target = x "m"; op = Shr_assign; value = int "3" });
      s (Return (Some (x "n")));
      s (Break (Some (int "1")));
      s (Break None);
      s Continue;
      s (Defer (call (dot (x "f") "close") []));
      s (Yield (x "n"));
      s
        (Expr
           (e
              (If
                 {
                   branches =
                     [ { cond = x "a"; body; span = sp }; { cond = x "b"; body; span = sp } ];
                   else_ = None;
                 })));
      s (For { pat = pbind "i"; iter = x "xs"; body });
      s (While { cond = bool true; body });
      s (Expr (e (Loop body)));
      s
        (Expr
           (e
              (With
                 {
                   items =
                     [
                       {
                         name = Some (id "f");
                         value = call (x "open") [ arg (str "a") ];
                         span = sp;
                       };
                       { name = None; value = x "lock"; span = sp };
                     ];
                   body;
                 })));
      s (Expr (e (Given { caps = [ x "net"; x "clock" ]; body })));
    ];
  [%expect
    {|
    (let a (: int) (int 1))
    (let (ctor Some v) (path opt) (else (block (return))))
    (var n (int 0))
    (let comptime K (: int) (int 3))
    (= (path n) (int 2))
    (+= (index (dot (path t) items) (int 0)) (int 1))
    (>>= (path m) (int 3))
    (return (path n))
    (break (int 1))
    (break)
    (continue)
    (defer (call (dot (path f) close)))
    (yield (path n))
    (if (path a) (block (call (path work))) (elif (path b) (block (call (path work)))))
    (for i (path xs) (block (call (path work))))
    (while (bool true) (block (call (path work))))
    (loop (block (call (path work))))
    (with (bind f (call (path open) (string "a"))) (path lock) (block (call (path work))))
    (given (path net) (path clock) (block (call (path work))))
    |}]

(* ---------- expressions ---------- *)

(* spec: SYN-030, SYN-033, SYN-034, SYN-035, SYN-036, SYN-037, SYN-040, SYN-100 *)
let%expect_test "operators, calls, postfix forms, slices, conditional and pipe" =
  List.iter print_expr
    [
      call (x "send")
        [
          arg (x "msg");
          arg ~label:"urgent" (bool true);
          arg ~inout:true (x "buf");
          arg ~label:"out" ~inout:true (x "o");
        ];
      e (Try (call (dot (x "db") "ping") []));
      e (Index { target = x "xs"; args = [ Ga_expr (int "0") ] });
      e
        (Index
           {
             target = x "xs";
             args = [ Ga_expr (e (Range { lo = Some (x "a"); hi = Some (x "b") })) ];
           });
      e (Index { target = x "xs"; args = [ Ga_expr (e (Range_incl { lo = None; hi = x "b" })) ] });
      e (Index { target = x "xs"; args = [ Ga_expr (e (Range { lo = Some (x "a"); hi = None })) ] });
      e (Range { lo = None; hi = None });
      bin Pow (x "a") (bin Pow (x "b") (x "c"));
      e (Unary { op = Neg; operand = e (Unary { op = Bit_not; operand = x "a" }) });
      e (Unary { op = Not; operand = x "ok" });
      bin Add
        (bin Mul (x "a") (x "b"))
        (bin Rem (x "c") (bin Div (x "d") (bin Sub (x "e") (x "f"))));
      bin Bit_or
        (bin Bit_xor (x "a") (bin Bit_and (x "b") (bin Shl (x "c") (bin Shr (x "d") (x "e")))))
        (x "f");
      bin Or (bin And (x "a") (x "b")) (x "c");
      e
        (Compare
           {
             first = x "a";
             rest = [ (Lt, x "b"); (Le, x "c"); (Eq, x "d"); (Ne, x "e"); (Gt, x "f"); (Ge, x "g") ];
           });
      e (Paren (bin Bit_and (x "a") (x "b")));
      e (Cond { cond = x "c"; then_ = x "a"; else_ = x "b" });
      bin Pipe (x "x") (call (x "f") [ arg (x "a") ]);
      e Self_type;
    ];
  [%expect
    {|
    (call (path send) (path msg) (label urgent (bool true)) (& (path buf)) (label out (& (path o))))
    (? (call (dot (path db) ping)))
    (index (path xs) (int 0))
    (index (path xs) (.. (path a) (path b)))
    (index (path xs) (..= _ (path b)))
    (index (path xs) (.. (path a) _))
    (.. _ _)
    (** (path a) (** (path b) (path c)))
    (- (~ (path a)))
    (not (path ok))
    (+ (* (path a) (path b)) (% (path c) (/ (path d) (- (path e) (path f)))))
    (| (^ (path a) (& (path b) (<< (path c) (>> (path d) (path e))))) (path f))
    (or (and (path a) (path b)) (path c))
    (cmp (path a) < (path b) <= (path c) == (path d) != (path e) > (path f) >= (path g))
    (paren (& (path a) (path b)))
    (cond (path c) (path a) (path b))
    (|> (path x) (call (path f) (path a)))
    (Self)
    |}]

(* spec: SYN-038, SYN-039, LEX-040..LEX-055 *)
let%expect_test "literals, collections and comprehensions" =
  let entry k v : map_entry = { key = k; value = v; span = sp } in
  let for_ pat iter = Comp_for { pat; iter; span = sp } in
  let if_ cond = Comp_if { cond; span = sp } in
  List.iter print_expr
    [
      e (Lit (Float "2.5e-3"));
      e (Lit (Duration { amount = "500"; unit = Ms }));
      e (Lit (Duration { amount = "30"; unit = Min }));
      str "quote \" backslash \\ newline \n tab \t nul \000 é";
      e (Lit (Raw_string "C:\\dir"));
      e (Lit (Bytes "\x00\xff"));
      e (Lit (Char (Uchar.of_int 0xE9)));
      e (Lit (Char (Uchar.of_int 0x0A)));
      e
        (Lit
           (Template
              {
                prefix = id "sql";
                parts = [ Text { text = "select {"; span = sp }; Interp (x "q") ];
              }));
      bool false;
      e (Tuple []);
      e (Tuple [ x "a" ]);
      e (List [ int "1"; int "2" ]);
      e (Set [ int "1" ]);
      e (Map []);
      e (Map [ entry (str "a") (int "1") ]);
      e
        (Comprehension
           {
             kind = Comp_list (x "e");
             clauses = [ for_ (pbind "p") (x "xs"); if_ (x "c"); for_ (pbind "q") (x "ys") ];
           });
      e (Comprehension { kind = Comp_set (x "e"); clauses = [ for_ (pbind "p") (x "xs") ] });
      e
        (Comprehension
           { kind = Comp_map (entry (x "k") (x "v")); clauses = [ for_ (pbind "p") (x "xs") ] });
      e (Comprehension { kind = Comp_iter (x "e"); clauses = [ for_ (pbind "p") (x "xs") ] });
    ];
  [%expect
    {|
    (float 2.5e-3)
    (duration 500 ms)
    (duration 30 min)
    (string "quote \" backslash \\ newline \n tab \t nul \u{0} é")
    (raw "C:\\dir")
    (bytes "\x00\xff")
    (char "é")
    (char "\n")
    (template sql (text "select {") (path q))
    (bool false)
    (tuple)
    (tuple (path a))
    (list (int 1) (int 2))
    (set (int 1))
    (map)
    (map (entry (string "a") (int 1)))
    (comp list (path e) (for p (path xs)) (if (path c)) (for q (path ys)))
    (comp set (path e) (for p (path xs)))
    (comp map (entry (path k) (path v)) (for p (path xs)))
    (comp iter (path e) (for p (path xs)))
    |}]

(* spec: SYN-013, SYN-051 *)
let%expect_test "if expression with else, match with guards and unsafe block" =
  let one ex = blk [ s (Expr ex) ] in
  print_expr
    (e
       (If
          {
            branches =
              [
                { cond = x "a"; body = one (int "1"); span = sp };
                { cond = x "b"; body = one (int "2"); span = sp };
              ];
            else_ = Some (one (int "3"));
          }));
  print_expr
    (e
       (Match
          {
            scrutinee = x "v";
            arms =
              [
                {
                  pat = pbind "n";
                  guard = Some (e (Compare { first = x "n"; rest = [ (Gt, int "0") ] }));
                  body = one (x "n");
                  span = sp;
                };
                { pat = p Pat_wild; guard = None; body = one (int "0"); span = sp };
              ];
          }));
  print_expr
    (e (Unsafe { reason = "FFI handle"; reason_span = sp; body = one (call (x "raw") []) }));
  [%expect
    {|
    (if (path a) (block (int 1)) (elif (path b) (block (int 2))) (else (block (int 3))))
    (match (path v) (case n (guard (cmp (path n) > (int 0))) (block (path n))) (case _ (block (int 0))))
    (unsafe "FFI handle" (block (call (path raw))))
    |}]

(* spec: SYN-060, SYN-062, SYN-064 — the examples of spec §3.6 *)
let%expect_test "short lambdas, function literals and trailing blocks" =
  print_expr (e (Lambda { params = [ lparam "x" ]; body = bin Mul (x "x") (int "2") }));
  print_expr (e (Lambda { params = [ lparam "a"; lparam "b" ]; body = bin Add (x "a") (x "b") }));
  print_expr (e (Lambda { params = []; body = call (x "now") [] }));
  print_expr (e (Lambda { params = [ lparam "x" ~ty:(tn "int") ]; body = x "x" }));
  print_expr
    (e (Lambda { params = [ lparam ~mode:Inout "acc"; lparam ~mode:Take "v" ]; body = x "acc" }));
  print_expr
    (e
       (Fn_lit
          {
            params = [ lparam "req" ~ty:(tn "Request") ];
            ret = Some (tn "Response");
            body = blk [ s (Expr (call (x "ok") [])) ];
          }));
  (* server.get("/health") fn(req): … *)
  print_expr
    (e
       (Trailing_call
          {
            callee = dot (x "server") "get";
            args = [ arg (str "/health") ];
            params = [ lparam "req" ];
            ret = None;
            body =
              blk
                [
                  s
                    (Let
                       {
                         pat = pbind "ok";
                         ty = None;
                         value = call (dot (call (dot (x "db") "ping") []) "is_ok") [];
                         else_ = None;
                       });
                  s
                    (Expr
                       (call
                          (dot (x "Response") "json")
                          [ arg (e (Map [ { key = str "ok"; value = x "ok"; span = sp } ])) ]));
                ];
          }));
  (* retry(attempts: 3, delay: 200.ms) fn: … *)
  print_expr
    (e
       (Trailing_call
          {
            callee = x "retry";
            args =
              [
                arg ~label:"attempts" (int "3");
                arg ~label:"delay" (e (Lit (Duration { amount = "200"; unit = Ms })));
              ];
            params = [];
            ret = None;
            body =
              blk
                [
                  s
                    (Expr
                       (call
                          (dot (x "api") "put")
                          [ arg (str "/tenants"); arg ~label:"json" (x "t") ]));
                ];
          }));
  [%expect
    {|
    (lambda (params (param x)) (* (path x) (int 2)))
    (lambda (params (param a) (param b)) (+ (path a) (path b)))
    (lambda (params) (call (path now)))
    (lambda (params (param x int)) (path x))
    (lambda (params (param inout acc) (param take v)) (path acc))
    (fn (params (param req Request)) (-> Response) (block (call (path ok))))
    (trailing-call (dot (path server) get)
      (args (string "/health"))
      (params (param req))
      (block
        (let ok (call (dot (call (dot (path db) ping)) is_ok)))
        (call (dot (path Response) json) (map (entry (string "ok") (path ok))))))
    (trailing-call (path retry)
      (args (label attempts (int 3)) (label delay (duration 200 ms)))
      (params)
      (block (call (dot (path api) put) (string "/tenants") (label json (path t)))))
    |}]

(* ---------- patterns ---------- *)

(* spec: SYN-050 — every pattern form, including the match example of spec §3.5 *)
let%expect_test "every pattern form of SYN-050" =
  let show pat = print_endline (Print.pattern pat) in
  let fp ?label pat = Fp_field { label = Option.map id label; pat; span = sp } in
  let ctor name fields = p (Pat_ctor { path = path name; fields }) in
  show (p Pat_wild);
  show (pbind "n");
  show (p (Pat_lit (lit_pat (Int "1"))));
  show (p (Pat_lit (lit_pat ~negated:true (Float "1.5"))));
  show (p (Pat_lit (lit_pat (String "a"))));
  show (p (Pat_lit (lit_pat (Char (Uchar.of_char 'z')))));
  show (p (Pat_lit (lit_pat (Bool true))));
  show (p (Pat_range { lo = lit_pat (Int "1"); hi = lit_pat (Int "9"); inclusive = true }));
  show
    (p
       (Pat_range
          { lo = lit_pat ~negated:true (Int "9"); hi = lit_pat (Int "0"); inclusive = false }));
  show (ctor "Circle" [ fp ~label:"radius" (pbind "r") ]);
  show (ctor "Circle" [ fp (p Pat_wild) ]);
  show
    (p
       (Pat_or
          [
            ctor "Rect" [ fp (pbind "w"); fp (pbind "h") ];
            ctor "Square" [ fp (p (Pat_as { pat = pbind "w"; name = id "h" })) ];
          ]));
  show (ctor "shapes.Point" [ fp ~label:"x" (pbind "x"); Fp_rest sp ]);
  show (ctor "Unit" []);
  show (p (Pat_tuple [ pbind "a"; p Pat_wild ]));
  show (p (Pat_list [ Lp_elem (pbind "first"); Lp_rest { name = Some (id "rest"); span = sp } ]));
  show (p (Pat_list [ Lp_rest { name = None; span = sp }; Lp_elem (pbind "last") ]));
  show (p (Pat_list []));
  show (p (Pat_as { pat = p (Pat_or [ pbind "a"; pbind "b" ]); name = id "c" }));
  [%expect
    {|
    _
    n
    (int 1)
    (- (float 1.5))
    (string "a")
    (char "z")
    (bool true)
    (..= (int 1) (int 9))
    (.. (- (int 9)) (int 0))
    (ctor Circle (label radius r))
    (ctor Circle _)
    (| (ctor Rect w h) (ctor Square (as w h)))
    (ctor shapes.Point (label x x) ..)
    (ctor Unit)
    (tuple a _)
    (list first (.. rest))
    (list .. last)
    (list)
    (as (| a b) c)
    |}]

(* ---------- printer behaviour ---------- *)

(* spec: SYN-001 — spans are printed on request, from a parsed file *)
let%expect_test "spans mode prints the span of every node" =
  match Parse.file ~file:"t.egd" "module api.t\nimport std.fmt as f\nlet x = 1\n" with
  | Some f, [] ->
      print_endline (Print.file ~spans:true f);
      [%expect
        {|
        (module @1:1-3:10 api.t@1:8-1:13)
          (import @2:1-2:20 std.fmt@2:8-2:15 as f@2:19-2:20)
          (let @3:1-3:10 x@3:5-3:6 (int @3:9-3:10 1))
        |}]
  | _ -> print_endline "parse failed"

(* spec: SYN-012 — span atoms do not displace the subject of a node; an assignment target is an ordinary expression *)
let%expect_test "spans mode on hand-built nodes" =
  let at l c1 c2 =
    Egide_source.Span.make ~file:"t.egd" ~start:{ line = l; col = c1 } ~stop:{ line = l; col = c2 }
  in
  let ident name sp : ident = { name; span = sp } in
  let target =
    { expr = Path { segments = [ ident "f" (at 1 1 2) ]; span = at 1 1 2 }; span = at 1 1 2 }
  in
  let callee : expr = { expr = Call { callee = target; args = [] }; span = at 1 1 4 } in
  let tgt : expr =
    {
      expr =
        Field
          {
            target =
              {
                expr = Path { segments = [ ident "t" (at 2 1 2) ]; span = at 2 1 2 };
                span = at 2 1 2;
              };
            name = ident "n" (at 2 3 4);
          };
      span = at 2 1 4;
    }
  in
  let st : stmt =
    { stmt = Assign { target = tgt; op = Add_assign; value = callee }; span = at 2 1 9 }
  in
  print_endline (Print.stmt ~spans:true st);
  [%expect
    {|
    (+= @2:1-2:9 (dot @2:1-2:4 (path @2:1-2:2 t@2:1-2:2) n@2:3-2:4)
      (call @1:1-1:4 (path @1:1-1:2 f@1:1-1:2)))
    |}]

let%expect_test "long nodes break after their leading atoms, deterministically" =
  let long = List.init 8 (fun i -> arg (x (Printf.sprintf "argument_number_%d" i))) in
  let ex = call (x "f") [ arg (call (x "g") long) ] in
  print_expr ex;
  print_endline (string_of_bool (Print.expr ex = Print.expr ex));
  [%expect
    {|
    (call (path f)
      (call (path g)
        (path argument_number_0)
        (path argument_number_1)
        (path argument_number_2)
        (path argument_number_3)
        (path argument_number_4)
        (path argument_number_5)
        (path argument_number_6)
        (path argument_number_7)))
    true
    |}]

let%expect_test "pp_* formatters print the same text as the string functions" =
  Format.printf "%a@." Print.pp_expr (bin Add (int "1") (int "2"));
  Format.printf "%a@." Print.pp_pattern (p Pat_wild);
  Format.printf "%a@." Print.pp_ty (tn "int");
  Format.printf "%a@." Print.pp_stmt (s Continue);
  Format.printf "%a@." Print.pp_block (blk [ s Continue ]);
  Format.printf "%a@." Print.pp_decl (decl (Const { name = id "A"; ty = None; value = int "1" }));
  Format.printf "%a@." Print.pp_file (file "m" []);
  [%expect
    {|
    (+ (int 1) (int 2))
    _
    int
    (continue)
    (block (continue))
    (let A (int 1))
    (module m)
    |}]

(* ---------- equality ---------- *)

let%expect_test "structural equality includes spans; printed equality ignores them" =
  let parse src =
    match Parse.file ~file:"t.egd" src with Some f, _ -> f | None, _ -> assert false
  in
  let a = parse "module m\nlet x = 1\n" and b = parse "module m\nlet x = 1\n" in
  let shifted = parse "module m\n\nlet x = 1\n" and other = parse "module m\nlet x = 2\n" in
  Printf.printf "same source: %b\n" (equal_file a b);
  Printf.printf "shifted spans: %b, printed: %b\n" (equal_file a shifted)
    (Print.file a = Print.file shifted);
  Printf.printf "different value: %b, printed: %b\n" (equal_file a other)
    (Print.file a = Print.file other);
  Printf.printf "expr: %b %b\n" (equal_expr (int "1") (int "1")) (equal_expr (int "1") (int "01"));
  Printf.printf "pattern: %b, ty: %b, stmt: %b, block: %b, decl: %b\n"
    (equal_pattern (p Pat_wild) (pbind "_"))
    (equal_ty (tn "int") (tn "int"))
    (equal_stmt (s Continue) (s (Break None)))
    (equal_block (blk []) (blk []))
    (equal_decl (List.hd a.decls) (List.hd b.decls));
  [%expect
    {|
    same source: true
    shifted spans: false, printed: true
    different value: false, printed: false
    expr: true false
    pattern: false, ty: true, stmt: false, block: true, decl: true
    |}]

(* ---------- shapes added by T-1030 (ADR-0013 to ADR-0017) ---------- *)

(* spec: SYN-015, SYN-012 — block-ended constructs are expressions, so they can be the right-hand side of a binding
   and an operand of nothing else (the latter is a parse-time check, T-1031) *)
let%expect_test "block-ended expressions are expressions wrapped by Expr statements" =
  let one ex = blk [ s (Expr ex) ] in
  let if_ =
    e
      (If
         {
           branches = [ { cond = x "c"; body = one (int "1"); span = sp } ];
           else_ = Some (one (int "2"));
         })
  in
  List.iter print_stmt
    [
      s (Let { pat = pbind "v"; ty = None; value = e (Loop (one (e (Tuple [])))); else_ = None });
      s (Var { name = id "w"; ty = None; value = if_ });
      s (Assign { target = dot (x "self") "n"; op = Add_assign; value = if_ });
      s (Expr (e (Unsafe { reason = "FFI"; reason_span = sp; body = one (int "0") })));
      s
        (Expr
           (e
              (With { items = [ { name = None; value = x "l"; span = sp } ]; body = one (int "0") })));
    ];
  [%expect
    {|
    (let v (loop (block (tuple))))
    (var w (if (path c) (block (int 1)) (else (block (int 2)))))
    (+= (dot (path self) n) (if (path c) (block (int 1)) (else (block (int 2)))))
    (unsafe "FFI" (block (int 0)))
    (with (path l) (block (int 0)))
    |}]

(* spec: SYN-012 (Q-0008) — an assignment target is a postfix expression: it can start with self *)
let%expect_test "assignment target is a postfix expression" =
  print_stmt
    (s
       (Assign
          {
            target = e (Index { target = dot (e Self) "items"; args = [ Ga_expr (x "i") ] });
            op = Simple_assign;
            value = int "0";
          }));
  [%expect {| (= (index (dot (self) items) (path i)) (int 0)) |}]

(* spec: SYN-030, SYN-033, CAP-032 — inout, labelled inout and explicit capability arguments *)
let%expect_test "argument forms" =
  print_expr
    (call (x "f")
       [
         arg (x "a");
         arg ~label:"n" (int "1");
         arg ~inout:true (x "buf");
         arg ~label:"out" ~inout:true (x "o");
         using_arg "net" (x "n0");
       ]);
  [%expect
    {|
    (call (path f)
      (path a)
      (label n (int 1))
      (& (path buf))
      (label out (& (path o)))
      (using net (path n0)))
    |}]

(* spec: SYN-042, SYN-043, ADR-0014 — one node for indexing, slicing and instantiation *)
let%expect_test "generic arguments: instantiation, type-only forms, several arguments" =
  let fn_ty =
    t (Ty_fn { params = [ tn "int" ]; ret = Some (t (Ty_optional (tn "int"))); using = [] })
  in
  let map_str_int =
    e (Index { target = x "Map"; args = [ Ga_expr (x "str"); Ga_expr (x "int") ] })
  in
  List.iter print_expr
    [
      call (e (Index { target = dot (x "req") "json"; args = [ Ga_expr (x "Tenant") ] })) [];
      e (Index { target = x "cache"; args = [ Ga_expr (x "Key"); Ga_type_only fn_ty ] });
      e (Index { target = x "decode"; args = [ Ga_expr map_str_int ] });
      e
        (Index { target = x "x"; args = [ Ga_type_only (t (Ty_dyn [ bound "Show"; bound "Eq" ])) ] });
    ];
  [%expect
    {|
    (call (index (dot (path req) json) (path Tenant)))
    (index (path cache) (path Key) (fn-type (params int) (-> (? int))))
    (index (path decode) (index (path Map) (path str) (path int)))
    (index (path x) (dyn Show Eq))
    |}]

(* spec: SYN-041, TYP-006 — types are paren-free; (T,) is a distinct one-element tuple type; an optional function
   type wraps the function type *)
let%expect_test "type forms of TYP-006" =
  let show ty = print_endline (Print.ty ty) in
  show (tn "T");
  show (t (Ty_tuple [ tn "T" ]));
  show (t (Ty_tuple []));
  show (t (Ty_optional (t (Ty_fn { params = []; ret = Some (tn "int"); using = [] }))));
  show (t (Ty_fn { params = []; ret = Some (t (Ty_optional (tn "int"))); using = [] }));
  show
    (t
       (Ty_fn
          {
            params = [ tn "Config" ];
            ret = None;
            using = [ bound "Client"; bound "Log" ~args:[ ga_of_ty (tn "T") ] ];
          }));
  show (t (Ty_dyn [ bound "Error"; bound "Send" ]));
  [%expect
    {|
    T
    (tuple-type T)
    (tuple-type)
    (? (fn-type (params) (-> int)))
    (fn-type (params) (-> (? int)))
    (fn-type (params Config) (using Client (apply Log (path T))))
    (dyn Error Send)
    |}]

(* spec: SYN-053, SYN-050, ADR-0015 — constants are distinct from bindings; literal patterns gain durations, raw
   strings and bytes *)
let%expect_test "pattern names and the literal patterns of ADR-0015" =
  let show pat = print_endline (Print.pattern pat) in
  show (pbind "n");
  show (p (Pat_const (path "None")));
  show (p (Pat_const (path "State.Available")));
  show (p (Pat_const (path "http.NOT_FOUND")));
  show (p (Pat_lit (lit_pat (Duration { amount = "5"; unit = S }))));
  show (p (Pat_lit (lit_pat ~negated:true (Duration { amount = "5"; unit = Ms }))));
  show (p (Pat_lit (lit_pat (Raw_string "a\\b"))));
  show (p (Pat_lit (lit_pat (Bytes "ab"))));
  show
    (p
       (Pat_range
          {
            lo = lit_pat (Duration { amount = "1"; unit = S });
            hi = lit_pat (Duration { amount = "9"; unit = S });
            inclusive = false;
          }));
  [%expect
    {|
    n
    (const None)
    (const State.Available)
    (const http.NOT_FOUND)
    (duration 5 s)
    (- (duration 5 ms))
    (raw "a\\b")
    (bytes "ab")
    (.. (duration 1 s) (duration 9 s))
    |}]

(* spec: SYN-040, ADR-0015 — [..=] always has an upper bound *)
let%expect_test "ranges" =
  List.iter print_expr
    [
      e (Range { lo = Some (x "a"); hi = None });
      e (Range { lo = None; hi = None });
      e (Range_incl { lo = None; hi = x "b" });
      e (Range_incl { lo = Some (x "a"); hi = x "b" });
    ];
  [%expect
    {|
    (.. (path a) _)
    (.. _ _)
    (..= _ (path b))
    (..= (path a) (path b))
    |}]

(* spec: SYN-062, SYN-064 — a trailing block keeps the call's own arguments and an optional return type *)
let%expect_test "trailing call with a return type" =
  print_expr
    (e
       (Trailing_call
          {
            callee = x "map";
            args = [ arg (x "xs") ];
            params = [ lparam "v" ];
            ret = Some (tn "int");
            body = blk [ s (Expr (x "v")) ];
          }));
  [%expect
    {| (trailing-call (path map) (args (path xs)) (params (param v)) (-> int) (block (path v))) |}]

(* spec: SYN-003, SYN-024 — visibility variants, bodiless struct and impl, alias versus new type *)
let%expect_test "declaration forms of SYN-003 and SYN-024" =
  List.iter print_decl
    [
      decl ~vis:Pub_package (Struct { name = id "Marker"; generics = []; fields = [] });
      decl
        (Struct
           {
             name = id "P";
             generics = [];
             fields = [ field ~vis:Pub_package "x" (tn "int"); field "y" (tn "int") ];
           });
      decl (Impl { generics = []; trait_ = Some (tn "Show"); self_ty = tn "Marker"; items = [] });
      decl (Type { name = id "A"; generics = []; def = Alias (tn "int") });
    ];
  [%expect
    {|
    (struct pub(package) Marker)
    (struct P (field pub(package) x int) (field y int))
    (impl Marker (trait Show))
    (type A int)
    |}]

(* spec: SYN-002 — an import is whole, aliased or itemised, never two of them (the type makes the third form
   unrepresentable) *)
let%expect_test "import forms are exclusive" =
  let item n : import_item = { name = id n; alias = None; span = sp } in
  List.iter
    (fun form ->
      let im = import (Import { path = path "a.b"; form }) in
      print_endline (Print.file (file "m" ~imports:[ im ] [])))
    [ Whole; Alias_as (id "c"); Items [ item "X" ] ];
  [%expect
    {|
    (module m)
      (import a.b)
    (module m)
      (import a.b as c)
    (module m)
      (import a.b (items X))
    |}]

(* spec: SYN-015, SYN-003, CT-002 — a top-level constant may be initialised by a block-ended expression *)
let%expect_test "top-level constant initialised by a match expression" =
  print_decl
    (decl
       (Const
          {
            name = id "K";
            ty = None;
            value =
              e
                (Match
                   {
                     scrutinee = x "v";
                     arms =
                       [
                         {
                           pat = p Pat_wild;
                           guard = None;
                           body = blk [ s (Expr (int "1")) ];
                           span = sp;
                         };
                       ];
                   });
          }));
  [%expect {| (let K (match (path v) (case _ (block (int 1))))) |}]
