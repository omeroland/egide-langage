(* Tests of the JSON reader used for `--error-format=json` diagnostics (TOOL-042). *)

open Egide_conformance

let rec show = function
  | Json.Null -> "null"
  | Bool b -> string_of_bool b
  | Number f -> Printf.sprintf "%g" f
  | String s -> Printf.sprintf "%S" s
  | Array l -> "[" ^ String.concat "," (List.map show l) ^ "]"
  | Object l -> "{" ^ String.concat "," (List.map (fun (k, v) -> k ^ "=" ^ show v) l) ^ "}"

let p s = print_endline (match Json.parse s with Ok v -> show v | Error e -> "error: " ^ e)

let%expect_test "parses the diagnostic schema of docs/diagnostics.md" =
  p
    {|{"code":"E0022","severity":"error","rule":"LEX-032","span":{"file":"a.egd","start":{"line":8,"col":3}},"notes":[]}|};
  [%expect
    {| {code="E0022",severity="error",rule="LEX-032",span={file="a.egd",start={line=8,col=3}},notes=[]} |}]

let%expect_test "scalars, nesting and whitespace" =
  p " [1, -2.5e2, true, false, null, {\"a\": [ ]}] ";
  [%expect {| [1,-250,true,false,null,{a=[]}] |}]

let%expect_test "string escapes, including surrogate pairs" =
  p {|"a\"b\\c\/d\n\t\u00e9\ud83d\ude00"|};
  [%expect {| "a\"b\\c/d\n\t\195\169\240\159\152\128" |}]

let%expect_test "malformed input is an error, never an exception" =
  List.iter p [ ""; "{"; "{\"a\" 1}"; "[1,]"; "\"\\x\""; "tru"; "1 2"; "\"\\ud800\""; "{\"a\":1,}" ];
  [%expect
    {|
    error: unexpected end of input at offset 0
    error: unexpected end of input at offset 1
    error: expected ':' at offset 5
    error: unexpected character ']' at offset 3
    error: invalid escape at offset 2
    error: invalid literal at offset 0
    error: trailing data at offset 2
    error: unpaired surrogate at offset 1
    error: expected string at offset 7
    |}]

let%expect_test "objects_in_lines skips non-JSON lines" =
  let text =
    "egide: warning: something\n\
    \  {\"code\":\"E0001\"}  \n\
     [1]\n\
     {\"code\":\n\
     Fatal error: exception Not_found\n\
     {\"code\":\"E0002\",\"span\":{\"start\":{\"line\":1}}}"
  in
  Json.objects_in_lines text
  |> List.iter (fun o ->
         print_endline (show o);
         print_endline
           (match Json.path [ "span"; "start"; "line" ] o with Some v -> show v | None -> "-"));
  [%expect
    {|
    {code="E0001"}
    -
    {code="E0002",span={start={line=1}}}
    1
    |}]
