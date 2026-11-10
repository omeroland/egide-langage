(* Line splitting shared by Header (sibling .stdout files) and Verdict (actual stdout). *)

let lines s =
  match List.rev (String.split_on_char '\n' s) with "" :: rest -> List.rev rest | l -> List.rev l
