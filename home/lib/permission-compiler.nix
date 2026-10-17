{ lib }:

# This is a bounded projection compiler, not a shell parser. Backends still own
# command splitting and matching; argv DSL and raw command globs are not equivalent.
let
  fail = message: throw "Permission compiler: ${message}";
  maxExpansions = 256;
  bounded =
    xs:
    if builtins.length xs > maxExpansions then
      fail "pattern expansion exceeds 256 alternatives"
    else
      xs;
  cartesian = prefixes: suffixes: bounded (lib.concatMap (a: map (b: a ++ b) suffixes) prefixes);
  parse =
    source:
    let
      n = builtins.stringLength source;
      at = i: builtins.substring i 1 source;
      space =
        c:
        builtins.elem c [
          " "
          "\t"
          "\n"
          "\r"
        ];
      boundary =
        i:
        i == n
        || space (at i)
        || builtins.elem (at i) [
          "["
          "]"
          "|"
        ];
      # Locate whole-value regex delimiters, including escaped slashes/classes.
      regexEnd =
        i: escaped: inClass:
        if i >= n then
          null
        else if escaped then
          regexEnd (i + 1) false inClass
        else if at i == "\\" then
          regexEnd (i + 1) true inClass
        else if at i == "[" then
          regexEnd (i + 1) false true
        else if at i == "]" then
          regexEnd (i + 1) false false
        else if at i == "/" && !inClass then
          let
            flagsEnd = j: if j < n && builtins.match "[imsxg]" (at j) != null then flagsEnd (j + 1) else j;
            end = flagsEnd (i + 1);
          in
          if boundary end then
            {
              close = i;
              inherit end;
            }
          else
            regexEnd (i + 1) false false
        else
          regexEnd (i + 1) false inClass;
      word =
        i: quote: escaped: value:
        if i == n then
          if escaped || quote != null then
            fail "unterminated quote or escape"
          else
            {
              end = i;
              inherit value;
            }
        else if escaped then
          word (i + 1) quote false (value + at i)
        else if at i == "\\" && quote != "'" then
          word (i + 1) quote true value
        else if quote != null then
          if at i == quote then word (i + 1) null false value else word (i + 1) quote false (value + at i)
        else if
          builtins.elem (at i) [
            "'"
            "\""
          ]
        then
          word (i + 1) (at i) false value
        else if boundary i then
          {
            end = i;
            inherit value;
          }
        else
          word (i + 1) null false (value + at i);
      lex =
        i:
        if i >= n then
          [ ]
        else if space (at i) then
          lex (i + 1)
        else if
          builtins.elem (at i) [
            "["
            "]"
            "|"
          ]
        then
          [ { kind = at i; } ] ++ lex (i + 1)
        else
          let
            regex = if at i == "/" then regexEnd (i + 1) false false else null;
            w = word i null false "";
            token =
              if regex != null then
                {
                  kind = "regex";
                  value = builtins.substring (i + 1) (regex.close - i - 1) source;
                  flags = builtins.substring (regex.close + 1) (regex.end - regex.close - 1) source;
                }
              else
                {
                  kind =
                    if builtins.substring i (w.end - i) source != w.value then
                      "literal"
                    else if w.value == "<arg>" then
                      "arg"
                    else if w.value == "<options>*" then
                      "options"
                    else if w.value == "..." then
                      "rest"
                    else
                      "literal";
                  value = w.value;
                };
          in
          [ token ] ++ lex (if regex != null then regex.end else w.end);
      tokens = lex 0;
      group =
        remaining: branches: current:
        if remaining == [ ] then
          fail "unclosed optional group"
        else
          let
            t = builtins.head remaining;
            tail = builtins.tail remaining;
          in
          if t.kind == "[" then
            fail "nested groups are unsupported"
          else if t.kind == "|" then
            if current == [ ] then fail "empty group alternative" else group tail (branches ++ [ current ]) [ ]
          else if t.kind == "]" then
            if current == [ ] then
              fail "empty group alternative"
            else
              {
                rest = tail;
                branches = branches ++ [ current ];
              }
          else
            group tail branches (current ++ [ t ]);
      sequence =
        remaining:
        if remaining == [ ] then
          [ ]
        else
          let
            t = builtins.head remaining;
            tail = builtins.tail remaining;
          in
          if t.kind == "[" then
            let
              g = group tail [ ] [ ];
              repeat =
                g.rest != [ ] && (builtins.head g.rest).kind == "literal" && (builtins.head g.rest).value == "*";
            in
            [
              {
                kind = "group";
                inherit (g) branches;
                inherit repeat;
              }
            ]
            ++ sequence (if repeat then builtins.tail g.rest else g.rest)
          else if
            builtins.elem t.kind [
              "]"
              "|"
            ]
          then
            fail "unexpected group delimiter"
          else
            [ t ] ++ sequence tail;
      ast = sequence tokens;
      validToken =
        t:
        if t.kind == "group" then
          builtins.all (branch: builtins.all (x: x.kind != "rest" && validToken x) branch) t.branches
        else if t.kind == "literal" then
          builtins.match ".*[<>*].*" t.value == null
        else if t.kind == "regex" then
          builtins.match "[imsx]*" t.flags != null
        else
          true;
      valid =
        ast != [ ]
        && (builtins.head ast).kind == "literal"
        && builtins.all (t: t.kind != "rest") (lib.init ast)
        && builtins.all validToken ast;
    in
    if n > 1024 || builtins.length tokens > 128 then
      fail "pattern exceeds parser limits"
    else if !valid then
      fail "unsupported or malformed DSL syntax"
    else
      ast;

  # Literal alphabet intentionally excludes shell/glob syntax and whitespace.
  safeLiteral = t: t.kind == "literal" && builtins.match "[-A-Za-z0-9_./:=+@,%~]+" t.value != null;
  regexPrefix =
    t:
    if t.flags != "" then
      ""
    else
      let
        m = builtins.match "([-A-Za-z0-9_]+)\\.[*+]" t.value;
      in
      if m == null then "" else builtins.head m;
  report =
    target: pattern: action:
    let
      ast = parse pattern;
      context = "${target} ${action} ${builtins.toJSON pattern}";
      finiteToken =
        t:
        safeLiteral t
        || t.kind == "rest"
        || (t.kind == "group" && !t.repeat && builtins.all (b: builtins.all safeLiteral b) t.branches);
      exact = builtins.all finiteToken ast;
      finite =
        t:
        if safeLiteral t then
          [ [ t.value ] ]
        else if t.kind == "rest" then
          [
            [ ]
            [ "*" ]
          ]
        else if t.kind == "group" then
          [ [ ] ]
          ++ map (branch: map (v: v.value) branch) (
            builtins.filter (branch: builtins.all safeLiteral branch) t.branches
          )
        else
          fail "${context}: cannot safely grant a required ${t.kind}";
      reduced = builtins.any (
        t: t.kind == "group" && (t.repeat || builtins.any (b: !(builtins.all safeLiteral b)) t.branches)
      ) ast;
      allows = lib.foldl' (acc: t: cartesian acc (finite t)) [ [ ] ] ast;
      # Approximate dynamic values, but retain spaces around each literal word.
      # A missing/repeated value needs separate zero-value and nonempty forms;
      # '*am*' must never stand in for the command word 'am'. These remain raw
      # text globs, not parsed-shell authorization or exact option matching.
      restriction =
        t:
        if safeLiteral t then
          [ [ t.value ] ]
        else if t.kind == "regex" then
          [ [ (regexPrefix t + "*") ] ]
        else if t.kind == "arg" then
          [ [ "*" ] ]
        else if
          builtins.elem t.kind [
            "options"
            "rest"
            "group"
          ]
        then
          [
            [ ]
            [ "*" ]
          ]
        else
          fail "${context}: literal contains unsupported shell/glob syntax";
      restrictions = lib.foldl' (acc: t: cartesian acc (restriction t)) [ [ ] ] ast;
      names =
        if action == "allow" || exact then
          map (xs: lib.concatStringsSep " " xs) allows
        else
          map (xs: "*" + lib.concatStringsSep " " xs) restrictions;
      normalize =
        s:
        let
          next = lib.replaceStrings [ "**" ] [ "*" ] s;
        in
        if next == s then s else normalize next;
      result = map (name: {
        name = normalize name;
        value = action;
      }) (lib.unique names);
    in
    builtins.addErrorContext "while compiling ${context}" (
      builtins.deepSeq ast (
        if
          !(builtins.elem target [
            "pi"
            "opencode"
          ])
        then
          fail "unknown backend ${target}"
        else
          builtins.deepSeq result {
            rules = result;
            diagnostics =
              if action == "allow" && reduced then
                [ "emitting finite literal subset; optional dynamic/repeated forms remain ungranted" ]
              else if !exact then
                [ "conservative raw-glob restriction may deny additional commands" ]
              else
                [ ];
          }
      )
    );
  compile =
    target: pattern: action:
    (report target pattern action).rules;
in
{
  inherit parse compile report;
  # Pi resolves specificity at runtime. OpenCode uses insertion order, so its
  # emitted JSON must explicitly order broad defaults before specific rules.
  toJSON =
    target: config:
    let
      specificity =
        pattern:
        (if lib.hasInfix "*" pattern then 0 else 1000)
        + builtins.stringLength (lib.replaceStrings [ "*" ] [ "" ] pattern);
      before =
        a: b:
        if specificity a != specificity b then
          specificity a < specificity b
        else if builtins.stringLength a != builtins.stringLength b then
          builtins.stringLength a < builtins.stringLength b
        else
          a > b;
      encode =
        path: value:
        if builtins.isAttrs value then
          let
            names = builtins.attrNames value;
            ordered =
              if target == "opencode" && lib.hasSuffix "/permission/bash" path then
                builtins.sort before names
              else
                names;
          in
          "{"
          + lib.concatStringsSep "," (
            map (name: builtins.toJSON name + ":" + encode (path + "/" + name) value.${name}) ordered
          )
          + "}"
        else if builtins.isList value then
          "[" + lib.concatStringsSep "," (map (encode path) value) + "]"
        else
          builtins.toJSON value;
    in
    if
      !(builtins.elem target [
        "pi"
        "opencode"
      ])
    then
      fail "unknown backend ${target}"
    else
      encode "" config;
}
