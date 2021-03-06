/*
 * redcloth_inline.rl
 *
 * Copyright (C) 2009 Jason Garber
 */
%%{

  machine redcloth_inline;

  # html
  start_tag_noactions = "<" Name space+ AttrSet* (AttrEnd)? ">" | "<" Name ">" ;
  empty_tag_noactions = "<" Name space+ AttrSet* (AttrEnd)? "/>" | "<" Name "/>" ;
  end_tag_noactions = "</" Name space* ">" ;
  any_tag_noactions = ( start_tag_noactions | empty_tag_noactions | end_tag_noactions ) ;
  
  start_tag = start_tag_noactions >X >A %T ;
  empty_tag = empty_tag_noactions >X >A %T ;
  end_tag = end_tag_noactions >X >A %T ;
  html_comment = ("<!--" (default+) :>> "-->") >X >A %T;
  html_break = ("<br" space* AttrSet* (AttrEnd)? "/"? ">" LF?) >X >A %T ;
  
  # links
  link_text_char = (default - [ "<>]) ;
  link_text_char_or_tag = ( link_text_char | any_tag_noactions ) ;
  link_mtext = ( link_text_char+ (mspace link_text_char+)* ) ;
  quoted_mtext = '"' link_mtext '"' ;
  link_mtext_including_tags = ( link_text_char_or_tag+ (mspace link_text_char_or_tag+)* ) ;
  mtext_including_quotes = (link_mtext ' "' link_mtext '" ' link_mtext?)+ ;
  link_says = ( C_noactions "."* " "* (quoted_mtext | mtext_including_quotes | link_mtext_including_tags ) ) >A %{ STORE("name"); } ;
  link_says_noquotes_noactions = ( C_noquotes_noactions "."* " "* ((link_mtext) -- '":') ) ;
  link = ( '"' link_says :>> '":' %A uri %{ STORE_URL("href"); } ) >X ;
  link_noquotes_noactions = ( '"' link_says_noquotes_noactions '":' uri ) ;
  bracketed_link = ( '["' link_says '":' %A uri %{ STORE("href"); } :> "]" ) >X ;
  # auto linking
  auto_link_proto_or_dubs = ( ("http" "s"? "://" ) | "www.") ;
  auto_link_url = ( auto_link_proto_or_dubs (uchar | reserved | '%')* ) ;
  auto_link_in_a_tag = ( "<" [aA] space+ AttrSet* (AttrEnd)? ">" auto_link_url :> end_tag_noactions ) %T >X ;
  auto_link = ( auto_link_url >A %{ STORE_URL("href"); } ) >X ;
  
  email_start = alnum ;
  email_domain = (alnum | "-" | "." | "_" )+;
  email_local_part = email_start ( alnum | "." | "+" | "-" )* ;
  email_address_text = email_local_part "@" email_domain ;
  email_address = ( email_address_text >A %{ STORE_URL("mailto"); } ) >X ;
  email_link_in_a_tag = ( "<" [aA] space+ AttrSet* (AttrEnd)? ">" email_address_text :> end_tag_noactions ) %T >X ;


  # images
  image_title = ( '(' mtext ')' ) ;
  image_is = ( A2 C ". "? (uri image_title?) >A %{ STORE("src"); } ) ;
  image_link = ( ":" uri >A %{ STORE_URL("href"); } ) ;
  image = ( "!" image_is :> "!" %A image_link? ) >X %SET_ATTR ;
  bracketed_image = ( "[!" image_is :> "!" %A image_link? "]" ) >X %SET_ATTR ;

  # footnotes
  footno = "[" >X %A digit+ %T "]" ;

  # markup
  end_markup_phrase = (" " | PUNCT | EOF | LF) @{ fhold; };
  code = ("@" >X mtext >A %T :> "@") | ("[@" >X default+ >A %T :>> "@]") ;
  script_tag = ( "<script" [^>]* ">" (default+ -- "</script>") "</script>" LF? ) >X >A %T ;
  strong = "["? "*" >X mtext >A %T :> "*" "]"? ;
  b = "["? "**" >X mtext >A %T :> "**" "]"? ;
  mtext_excluding_underscore = mtext -- "_" ;
  emtext = mtext_excluding_underscore ("_" mtext_excluding_underscore)*;
  em = "["? "_" >X emtext >A %T "_" "]"? ;
  i = "["? "__" >X emtext >A %T :>> ("__" "]"?) ;
  del = "[-" >X C ( mtext ) >A %T :>> "-]" ;
  emdash_parenthetical_phrase_with_spaces = " -- " mtext " -- " ;
  del_phrase = (( " " >A %{ STORE("beginning_space"); } "-" | "-" when starts_line) >X C ( mtext ) >A %T :>> ( "-" end_markup_phrase )) - emdash_parenthetical_phrase_with_spaces ;
  ins = "["? "+" >X mtext >A %T :> "+" "]"? ;
  sup = "[^" >X mtext >A %T :> "^]" ;
  sup_phrase = ( "^" when starts_phrase) >X ( mtext ) >A %T :>> ( "^" end_markup_phrase ) ;
  sub = "[~" >X mtext >A %T :> "~]" ;
  sub_phrase = ( "~" when starts_phrase) >X ( mtext ) >A %T :>> ( "~" end_markup_phrase ) ;
  span = "[%" >X mtext >A %T :> "%]" ;
  span_phrase = (("%" when starts_phrase) >X ( mtext ) >A %T :>> ( "%" end_markup_phrase )) ;
  cite = "["? "??" >X mtext >A >ATTR :>> ("?" @T ( "?" | "?" @{ STORE_ATTR("text"); } "?" %SET_ATTR ))  "]"? ;
  ignore = "["? "==" >X %A mtext %T :> "==" "]"? ;
  snip = "["? "```" >X %A mtext %T :> "```" "]"? ;
  
  # quotes
  quote1 = "'" >X %A mtext %T :> "'" ;
  non_quote_chars_or_link = (chars -- '"') | link_noquotes_noactions ;
  mtext_inside_quotes = ( non_quote_chars_or_link (mspace non_quote_chars_or_link)* ) ;
  html_tag_up_to_attribute_quote = "<" Name space+ NameAttr space* "=" space* ;
  quote2 = ('"' >X %A ( mtext_inside_quotes - (mtext_inside_quotes html_tag_up_to_attribute_quote ) ) %T :> '"' ) ;
  multi_paragraph_quote = (('"' when starts_line) >X  %A ( chars -- '"' ) %T );
  
  # glyphs
  ellipsis = ( " "? >A %T "..." ) >X ;
  emdash = "--" ;
  arrow = "->" ;
  endash = " - " ;
  acronym = ( [A-Z] >A [A-Z0-9]{1,} %T "(" default+ >A %{ STORE("title"); } :> ")" ) >X ;
  caps_noactions = upper{3,} ;
  caps = ( caps_noactions >A %*T ) >X ;
  dim_digit = [0-9.]+ ;
  prime = ("'" | '"')?;
  dim_noactions = dim_digit prime (("x" | " x ") dim_digit prime) %T (("x" | " x ") dim_digit prime)? ;
  dim = dim_noactions >X >A %T ;
  tm = [Tt] [Mm] ;
  trademark = " "? ( "[" tm "]" | "(" tm ")" ) ;
  reg = [Rr] ;
  registered = " "? ( "[" reg "]" | "(" reg ")" ) ;
  cee = [Cc] ;
  copyright = ( "[" cee "]" | "(" cee ")" ) ;
  entity = ( "&" %A ( '#' digit+ | ( alpha ( alpha | digit )+ ) ) %T ';' ) >X ;
  
  # info
  redcloth_version = "[RedCloth::VERSION]" ;

  other_phrase = phrase -- dim_noactions;

  code_tag := |*
    code_tag_end { CAT(block); fgoto main; };
    default => esc_pre;
  *|;

  main := |*
    
    image { PARSE_IMAGE_ATTR("src"); INLINE(block, "image"); };
    bracketed_image { PARSE_IMAGE_ATTR("src"); INLINE(block, "image"); };
    
    link { PARSE_LINK_ATTR("name"); PASS(block, "name", "link"); };
    bracketed_link { PARSE_LINK_ATTR("name"); PASS(block, "name", "link"); };
    
    auto_link_in_a_tag { CAT(block); };
    auto_link { INLINE(block, "auto_link"); };
    email_link_in_a_tag { CAT(block); };
    email_address { INLINE(block, "auto_link"); };


    
    code { PASS_CODE(block, "text", "code"); };
    code_tag_start { CAT(block); fgoto code_tag; };
    notextile { INLINE(block, "notextile"); };
    strong { PARSE_ATTR("text"); PASS(block, "text", "strong"); };
    b { PARSE_ATTR("text"); PASS(block, "text", "b"); };
    em { PARSE_ATTR("text"); PASS(block, "text", "em"); };
    i { PARSE_ATTR("text"); PASS(block, "text", "i"); };
    del { PASS(block, "text", "del"); };
    del_phrase { PASS(block, "text", "del_phrase"); };
    ins { PARSE_ATTR("text"); PASS(block, "text", "ins"); };
    sup { PARSE_ATTR("text"); PASS(block, "text", "sup"); };
    sup_phrase { PARSE_ATTR("text"); PASS(block, "text", "sup_phrase"); };
    sub { PARSE_ATTR("text"); PASS(block, "text", "sub"); };
    sub_phrase { PARSE_ATTR("text"); PASS(block, "text", "sub_phrase"); };
    span { PARSE_ATTR("text"); PASS(block, "text", "span"); };
    span_phrase { PARSE_ATTR("text"); PASS(block, "text", "span_phrase"); };
    cite { PARSE_ATTR("text"); PASS(block, "text", "cite"); };
    ignore => ignore;
    snip { PASS(block, "text", "snip"); };
    quote1 { PASS(block, "text", "quote1"); };
    quote2 { PASS(block, "text", "quote2"); };
    multi_paragraph_quote { PASS(block, "text", "multi_paragraph_quote"); };
    
    ellipsis { INLINE(block, "ellipsis"); };
    emdash { INLINE(block, "emdash"); };
    endash { INLINE(block, "endash"); };
    arrow { INLINE(block, "arrow"); };
    caps { INLINE(block, "caps"); };
    acronym { INLINE(block, "acronym"); };
    dim { INLINE(block, "dim"); };
    trademark { INLINE(block, "trademark"); };
    registered { INLINE(block, "registered"); };
    copyright { INLINE(block, "copyright"); };
    footno { PASS(block, "text", "footno"); };
    entity { INLINE(block, "entity"); };
    
    script_tag { INLINE(block, "inline_html"); };
    start_tag { INLINE(block, "inline_html"); };
    end_tag { INLINE(block, "inline_html"); };
    empty_tag { INLINE(block, "inline_html"); };
    html_comment { INLINE(block, "inline_html"); };
    html_break { INLINE(block, "inline_html"); };
    
    redcloth_version { INLINE(block, "inline_redcloth_version"); };
    
    other_phrase => esc;
    PUNCT => esc;
    space => esc;
    
    EOF;
    
  *|;

}%%;
