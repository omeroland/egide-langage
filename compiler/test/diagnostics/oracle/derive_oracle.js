// Re-derives the literal range lists of forbidden_oracle.ml (T-1033). Needs Node.js with ICU; NOT run in CI (the
// oracle is deliberately independent of the build, and its host Unicode version may differ from 16.0.0: Node 22 with
// ICU 78 is Unicode 17, which equals 16.0.0 for these properties; check any diff against the pinned upstream files).
// Usage: node derive_oracle.js > lists.ml   then compare with the lists in forbidden_oracle.ml (the committed file
// adds comments and sorts them in the order cf, cc, dicp, vs, ncp, zs, formatted by hand).
const props={Cf:"\\p{Cf}",Cc:"\\p{Cc}",DICP:"\\p{Default_Ignorable_Code_Point}",VS:"\\p{Variation_Selector}",NCP:"\\p{Noncharacter_Code_Point}",Zs:"\\p{Zs}"};
for(const [k,p] of Object.entries(props)){
 const re=new RegExp("^"+p+"$","u");const out=[];let s=-1;
 for(let c=0;c<=0x110000;c++){const m=c<0x110000&&!(c>=0xD800&&c<0xE000)&&re.test(String.fromCodePoint(c));
  if(m&&s<0)s=c; if(!m&&s>=0){out.push([s,c-1]);s=-1;}}
 console.log("let "+k.toLowerCase()+" =\n  [ "+out.map(([a,b])=>"(0x"+a.toString(16).toUpperCase()+", 0x"+b.toString(16).toUpperCase()+")").join(";\n    ")+" ]\n");
}
