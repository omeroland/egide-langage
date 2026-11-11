let write oc s =
  Out_channel.output_string oc s;
  Out_channel.output_char oc '\n'

let line s = write stdout (Escape.neutralize_line s)
let eline s = write stderr (Escape.neutralize_line s)
let block s = write stdout (Escape.neutralize s)
let eblock s = write stderr (Escape.neutralize s)
