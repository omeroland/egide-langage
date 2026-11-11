let print s = Out_channel.output_string stdout (Escape.neutralize s)

let println s =
  print s;
  Out_channel.output_char stdout '\n'

let eprintln s =
  Out_channel.output_string stderr (Escape.neutralize s);
  Out_channel.output_char stderr '\n'
