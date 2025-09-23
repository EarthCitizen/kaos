# kaos Examples

This page collects medium–to–advanced examples that demonstrate how to compose `kaos` generators for practical use cases. Each section shows a compact generator and a brief usage snippet. These are intended as inspiration; adapt sizes, distributions, and shapes to your needs.

## Random JSON Document

Generate nested JSON (objects, arrays, booleans, numbers, strings) with
depth‑aware weights to curb explosive growth. The generator builds an Erlang
term and then prints proper JSON via the stdlib json module.

```erlang
1> GenNestSize = kaos:integer(1, 4).
2> GenFloat = kaos:float(-12.0, 12.0).
3> GenInteger = kaos:integer(-12, 12).
4> GenString = kaos:string_of(kaos:integer(1, 12), kaos:integer($a, $z)).
5> GenPrimitive = kaos:choose([kaos:boolean(), GenFloat, GenInteger, GenString]).
6> GenJson =
6>   kaos:recurse(fun (Depth) ->
6>     case Depth < 3 of
6>       true -> kaos:weighted([
6>                 {3, GenPrimitive},
6>                 {2, kaos:choose([
6>                       kaos:list_of(GenNestSize, kaos:recurse(fun(_) -> GenPrimitive end)),
6>                       kaos:map_of(GenNestSize, GenString, kaos:recurse(fun(_) -> GenPrimitive end))
6>                 ])}
6>               ]);
6>       false -> GenPrimitive
6>     end
6>   end).
7> {ok, [Json]} = kaos:generate(GenJson, 909, 1).
8> io:format("~ts~n", [json:format(Json)]).
[
  {
    "aavquho": { "sitygndpvol": 2 },
    "butquytalbd": [
      [-8,{
          "mq": false,
          "zkcrikbkpb": 5.512894632507528
        }],
      "oeggzc",
      true
    ],
    "q": 6.649188725917739,
    "qb": [
      [false,false,"suzsscusndhq"],
      "ysvoe",
      "yjidecscisc"
    ]
  },
  false,
  false
]
ok
```

## Strong Password Generator

Enforce composition rules (required classes), fill remaining characters from a weighted mix, then shuffle for final randomness.

```erlang
1> GenSpecialW = {_, GenSpecialC} = kaos:weighted_from_list([$!, $@, $#, $$, $%, $^, $&, $*, $(, $), $_, $+, $-, $=]).
2> GenUpperW = {_, GenUpperC} = kaos:weighted_from_range($A, $Z).
3> GenLowerW = {_, GenLowerC} = kaos:weighted_from_range($a, $z).
4> GenNumberW = {_, GenNumberC} = kaos:weighted_from_range($0, $9).
5> GenSymbolW = kaos:weighted_from_list([$(, $), $_, $+, $-, $=, ${, $}, $[, $], $:, $;, $<, $>, $,, $., $?, $/]).
6> GenFiller = kaos:weighted([GenSpecialW, GenUpperW, GenLowerW, GenNumberW, GenSymbolW]).
7> GenAll = kaos:all([
7>   kaos:list_of(kaos:const(2), GenSpecialC),
7>   kaos:list_of(kaos:const(1), GenUpperC),
7>   kaos:list_of(kaos:const(1), GenLowerC),
7>   kaos:list_of(kaos:const(1), GenNumberC),
7>   kaos:list_of(kaos:const(12 - 5), GenFiller)
7> ]).
8> GenPass = kaos:flatmap(fun (Gs) -> kaos:shuffle(lists:flatten(Gs)) end, GenAll).
9> {ok, [Pass]} = kaos:generate(GenPass, 909, 1).
10> Pass.
"6+LP!J}vaj1sg(+K:("
```

## Arithmetic Expression Strings

Compose printable infix expressions by recursively nesting sub‑expressions with controlled depth.

```erlang
1> GenVal = kaos:map(fun (I) -> lists:flatten(io_lib:format("~p", [I])) end, kaos:integer(-100, 100)).
2> GenOp  = kaos:choose([kaos:const($+), kaos:const($-), kaos:const($/), kaos:const($*)]).
3> GenExpr = kaos:recurse(fun (Depth) ->
3>   case Depth < 3 of
3>     true -> kaos:weighted([
3>       {2, GenVal},
3>       {3, kaos:map(fun ([A,Op,B]) ->
3>             lists:flatten(io_lib:format("( ~s ~c ~s )", [A, Op, B]))
3>           end, kaos:all([GenVal, GenOp, GenVal]))}
3>     ]);
3>     false -> GenVal
3>   end
3> end).
4> {ok, [Expr]} = kaos:generate(GenExpr, 909, 1).
5> Expr.
"( -39 - ( ( 29 + -52 ) - ( -90 + -65 ) ) )"
```

## Synthetic CSV Dataset

Emit CSV rows with typed columns and stream lines if needed.

```erlang
1> Label = kaos:string_of(kaos:integer(3, 8), kaos:integer($a, $z)).
2> Cat   = kaos:choose_from_list(["A","B","C","D"]).
3> Id    = kaos:iterate(fun(N) -> N + 1 end, 1).
4> Flt   = kaos:float(-100.0, 100.0).
5> Row   = kaos:map(fun({I,F,L,C}) ->
5>            iolist_to_binary(io_lib:format("~B,~.4f,~s,~s", [I,F,binary_to_list(L),C]))
5>          end, kaos:tuple_of([Id, Flt, Label, Cat]) ).
6> Header = kaos:const(<<"id,value,label,category">>).
7> CSV    = kaos:map(fun({H,Rs}) -> [H | Rs] end,
7>                   kaos:tuple_of([Header, kaos:all([Row, Row, Row])]) ).
8> {ok, [Csv]} = kaos:generate(CSV, 909, 1).
9> Csv.
[<<"id,value,label,category">>,
 <<"1,6.6492,ypwcby,A">>,
 <<"2,-19.5027,kvqsd,C">>,
 <<"3,0.1000,yaj,B">>]
```

## Web Server Access Logs

Generate Apache/Nginx‑style log lines with realistic distributions.

```erlang
1> Ip = kaos:map(fun({A,B,C,D}) ->
1>        lists:flatten(io_lib:format("~B.~B.~B.~B", [A,B,C,D]))
1>      end,
1>      kaos:tuple_of([
1>        kaos:integer(1,255),
1>        kaos:integer(0,255),
1>        kaos:integer(0,255),
1>        kaos:integer(1,255)
1>      ])
1>    ).
2> Meth = kaos:weighted([
2>   {70, kaos:const("GET")},
2>   {20, kaos:const("POST")},
2>   {5,  kaos:const("PUT")},
2>   {5,  kaos:const("DELETE")}
2> ]).
3> Seg  = kaos:string_of(kaos:integer(2, 8), kaos:integer($a, $z)).
4> Path = kaos:map(
4>   fun(Segs) ->
4>     "/" ++ string:join(
4>       [binary_to_list(S) || S <- Segs], "/"
4>     )
4>   end,
4>   kaos:list_of(kaos:integer(1, 4), Seg)
4> ).
5> Code = kaos:weighted([
5>   {85, kaos:const(200)},
5>   {5,  kaos:const(301)},
5>   {5,  kaos:const(404)},
5>   {5,  kaos:const(500)}
5> ]).
6> Size = kaos:integer(0, 20000).
7> UA   = kaos:choose_from_list(["Mozilla/5.0","curl/8.0.1","Go-http-client/1.1","python-requests/2.31"]).
8> T    = kaos:integer(1_750_000_000, 1_760_000_000).
9> Line = kaos:map(
9>   fun({I,M,P,C,S,U,E}) ->
9>     iolist_to_binary(
9>       io_lib:format(
9>         "~s - - [~B] \"~s ~s HTTP/1.1\" ~B ~B \"-\" \"~s\"",
9>         [I,E,M,P,C,S,U]
9>       )
9>     )
9>   end,
9>   kaos:tuple_of([Ip, Meth, Path, Code, Size, UA, T])
9> ).
10> {ok, Lines} = kaos:generate(Line, 909, 3).
11> Lines.
[<<"51.194.27.139 - - [1750060179] \"GET /swqclnwb/eaeaokov HTTP/1.1\" 200 532 \"-\" \"curl/8.0.1\"">>,
 <<"23.84.9.78 - - [1750420890] \"GET /cozh/cikojsk HTTP/1.1\" 301 120 \"-\" \"Mozilla/5.0\"">>,
 <<"104.5.220.16 - - [1750198823] \"POST /qaf/ngdusuwj/teeswqx HTTP/1.1\" 200 2449 \"-\" \"Go-http-client/1.1\"">>]
```

## Procedural Dungeon/Maze Map (ASCII)

Carve a few rooms and connect them with simple L‑shaped corridors, then render
an ASCII grid: `#` for wall and `.` for floor.

```erlang
1> W = 21, H = 11.
2> RoomSize = kaos:tuple_of([kaos:integer(3, 6), kaos:integer(3, 5)]).
3> Room = kaos:flatmap(
3>   fun({Rw,Rh}) ->
3>     kaos:map(
3>       fun({X,Y}) -> {X,Y,Rw,Rh} end,
3>       kaos:tuple_of([
3>         kaos:integer(1, W - Rw - 1),
3>         kaos:integer(1, H - Rh - 1)
3>       ])
3>     )
3>   end,
3>   RoomSize
3> ).
4> Rooms = kaos:list_of(kaos:integer(3, 5), Room).
5> Dungeon = kaos:map(
5>   fun(Rs) ->
5>     Seq = fun(A,B) -> lists:seq(A,B) end,
5>     Pairs = fun(L) -> lists:zip(L, lists:nthtail(1, L)) end,
5>     Centers = [{X + (Rw div 2), Y + (Rh div 2)} || {X,Y,Rw,Rh} <- Rs],
5>     Corridor =
5>       fun({X1,Y1}, {X2,Y2}) ->
5>         Hs = [{X,Y1} || X <- Seq(min(X1,X2), max(X1,X2))],
5>         Vs = [{X2,Y} || Y <- Seq(min(Y1,Y2), max(Y1,Y2))],
5>         Hs ++ Vs
5>       end,
5>     RoomTiles =
5>       lists:flatten([
5>         [{X+DX, Y+DY} || DX <- Seq(0,Rw-1), DY <- Seq(0,Rh-1)]
5>         || {X,Y,Rw,Rh} <- Rs
5>       ]),
5>     CorrTiles =
5>       case Centers of
5>         []  -> [];
5>         [_] -> [];
5>         _   -> lists:flatten([
5>                   Corridor(A,B) || {A,B} <- Pairs(Centers)
5>                 ])
5>       end,
5>     Floors = ordsets:from_list(RoomTiles ++ CorrTiles),
5>     Xs = lists:seq(0, W-1),
5>     Ys = lists:seq(0, H-1),
5>     Lines = [
5>       iolist_to_binary([
5>         case ordsets:is_element({X,Y}, Floors) of
5>           true -> $.; false -> $#
5>         end || X <- Xs]) || Y <- Ys
5>     ],
5>     lists:join("\n", Lines)
5>   end,
5>   Rooms
5> ).
6> {ok, [Map]} = kaos:generate(Dungeon, 4242, 1).
7> io:format("~s~n", [Map]).
#####################
#.....#.....####....#
#.....#.....#..#....#
#.....#####.#..#....#
#.........#.#..#....#
###.#####.#.#..#....#
#...#...#.#.#..######
#...###.#.#.#.......#
#.......#...#.......#
#.............#.....#
#####################
ok
```

## Random HTML Document

Generate a small, valid HTML5 document with random title, paragraphs, lists,
links and images. Each element is kept short for readability.

```erlang
1> Word = kaos:string_of(kaos:integer(3, 6), kaos:integer($a, $z)).
2> Sentence = kaos:map(
2>   fun(Ws) ->
2>     Words = [binary_to_list(W) || W <- Ws],
2>     iolist_to_binary(string:join(Words, " ") ++ ".")
2>   end,
2>   kaos:list_of(kaos:integer(3, 5), Word)
2> ).
3> Para = kaos:map(
3>   fun(Ss) ->
3>     Text = string:join([
3>       binary_to_list(S) || S <- Ss
3>     ], " "),
3>     iolist_to_binary(["<p>", Text, "</p>\n"])
3>   end,
3>   kaos:list_of(kaos:integer(1, 2), Sentence)
3> ).
4> Item = kaos:map(
4>   fun(T) -> ["<li>", T, "</li>\n"] end,
4>   Sentence
4> ).
5> UList = kaos:map(
5>   fun(Is) ->
5>     iolist_to_binary(["<ul>\n", lists:flatten(Is), "</ul>\n"])
5>   end,
5>   kaos:list_of(kaos:integer(2, 3), Item)
5> ).
6> Link = kaos:map(
6>   fun(T) ->
6>     iolist_to_binary(["<a href=\"/\">", T, "</a>\n"])
6>   end,
6>   Sentence
6> ).
7> Img = kaos:map(
7>   fun(N) ->
7>     iolist_to_binary([
7>       "<img alt=\"", N,
7>       "\" src=\"/img/", N, ".png\">\n"
7>     ])
7>   end,
7>   Word
7> ).
8> Title = kaos:map(
8>   fun({A,B}) -> iolist_to_binary([A, " ", B]) end,
8>   kaos:tuple_of([Word, Word])
8> ).
9> Elem = kaos:choose([
9>   Para,
9>   UList,
9>   Link,
9>   Img,
9>   kaos:map(
9>     fun(T) -> iolist_to_binary(["<h2>", T, "</h2>\n"]) end,
9>     Sentence
9>   )
9> ]).
10> Body = kaos:map(
10>   fun(Es) -> iolist_to_binary(Es) end,
10>   kaos:list_of(kaos:integer(3, 5), Elem)
10> ).
11> Doc = kaos:map(
11>   fun({Ti,Bo}) ->
11>     iolist_to_binary([
11>       "<!DOCTYPE html>\n",
11>       "<html>\n",
11>       "<head><meta charset=\"utf-8\"><title>",
11>       Ti,
11>       "</title></head>\n",
11>       "<body>\n",
11>       Bo,
11>       "</body>\n",
11>       "</html>"
11>     ])
11>   end,
11>   kaos:tuple_of([Title, Body])
11> ).
12> {ok, [Html]} = kaos:generate(Doc, 808, 1).
13> io:format("~ts~n", [Html]).
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><title>swqclnwb eaeaokov</title></head>
<body>
<h2>cozh cikojsk.</h2>
<p>qaf ngdusuwj teeswqx.</p>
<ul>
<li>ysvoe yjidec.</li>
<li>qjf npb.</li>
</ul>
<a href="/">kvq sd.</a>
<img alt="teeswqx" src="/img/teeswqx.png">
</body>
</html>
ok
```

## Binary Protocol Frames

Assemble a frame with simple header fields, dependent payload size, and a checksum.

```erlang
1> Version = kaos:const(1).
2> Flags   = kaos:bitstring_of(kaos:const(4), kaos:bit()).
3> Len     = kaos:integer(0, 8).
4> Payload = kaos:flatmap(
4>   fun(L) -> kaos:binary_of(kaos:const(L), kaos:byte()) end,
4>   Len
4> ).
5> Frame   = kaos:map(
5>   fun({V,F,L,P}) ->
5>     C = (lists:sum(binary:bin_to_list(P)) band 255),
5>     <<V:8, F/bitstring, L:8, P/binary, C:8>>
5>   end,
5>   kaos:tuple_of([Version, Flags, Len, Payload])
5> ).
6> {ok, [Bin]} = kaos:generate(Frame, 909, 1).
7> {byte_size(Bin), Bin}.
{7,<<1,8:4,0:4,3,42,229,232,247>>}
```

## Balanced Bracket Sequences

Generate valid parentheses strings using a simple grammar: S -> "" | "(" S ")" S.

```erlang
1> F = fun Recur (Depth) ->
1>   case Depth < 4 of
1>     true ->
1>       kaos:choose([
1>         kaos:const(<<>>),
1>         kaos:map(
1>           fun({A,B}) -> iolist_to_binary([$\(, A, $\), B]) end,
1>           kaos:tuple_of([
1>             kaos:recurse(Recur),
1>             kaos:recurse(Recur)
1>           ])
1>         )
1>       ]);
1>     false -> kaos:const(<<>>)
1>   end
1> end.
2> {ok, [S]} = kaos:generate(kaos:recurse(F), 909, 1).
3> S.
<<"(()())">>
```

## Grammatical English Sentences

Generate short, grammatically correct English sentences with subject–verb
agreement, optional adjectives, and optional prepositional phrases.

```erlang
1> % Lexicon
1> DetSg = kaos:choose_from_list(["a","the","this"]).
1> DetPl = kaos:choose_from_list(["the","these","some"]).
1> Adj   = kaos:choose_from_list(["quick","happy","small","blue"]).
1> NounS = kaos:choose_from_list(["cat","dog","child","car"]).
1> NounP = kaos:choose_from_list(["cats","dogs","children","cars"]).
1> VinS  = kaos:choose_from_list(["runs","sleeps","jumps","waits"]).
1> VinP  = kaos:choose_from_list(["run","sleep","jump","wait"]).
1> VtS   = kaos:choose_from_list(["sees","likes","finds","helps"]).
1> VtP   = kaos:choose_from_list(["see","like","find","help"]).
1> Prep  = kaos:choose_from_list(["with","near","under","above"]).

2> % Noun phrase by number (sg/pl), with 0..2 adjectives
2> NP = kaos:flatmap(
2>   fun(Num) ->
2>     Det = case Num of sg -> DetSg; pl -> DetPl end,
2>     N   = case Num of sg -> NounS; pl -> NounP end,
2>     Adjs = kaos:list_of(kaos:integer(0,2), Adj),
2>     Base = kaos:map(
2>       fun({D,As,Nom}) ->
2>         Words = [D | lists:append(As) ++ [Nom]],
2>         string:join(Words, " ")
2>       end,
2>       kaos:tuple_of([Det, Adjs, N])
2>     ),
2>     MaybePP = kaos:choose([
2>       kaos:const(""),
2>       kaos:map(
2>         fun({Pr,Obj}) -> " " ++ Pr ++ " " ++ Obj end,
2>         kaos:tuple_of([Prep, kaos:flatmap(fun(_) -> NP end, kaos:const(pl))])
2>       )
2>     ]),
2>     kaos:map(fun({B,PP}) -> B ++ PP end, kaos:tuple_of([Base, MaybePP]))
2>   end,
2>   kaos:choose([kaos:const(sg), kaos:const(pl)])
2> ).

3> % Verb phrase agrees with subject number; optionally transitive
3> VP = kaos:flatmap(
3>   fun(Num) ->
3>     Vin = case Num of sg -> VinS; pl -> VinP end,
3>     Vtr = case Num of sg -> VtS;  pl -> VtP  end,
3>     Intrans = kaos:map(fun(V) -> V end, Vin),
3>     Trans   = kaos:map(
3>       fun({V,Obj}) -> V ++ " " ++ Obj end,
3>       kaos:tuple_of([Vtr, NP])
3>     ),
3>     kaos:choose([Intrans, Trans])
3>   end,
3>   kaos:choose([kaos:const(sg), kaos:const(pl)])
3> ).

4> % Sentence: subject NP + VP; capitalize and punctuate
4> Sentence = kaos:map(
4>   fun({Subj, Pred}) ->
4>     Words = Subj ++ " " ++ Pred,
4>     L = string:to_lower(Words),
4>     [H|T] = L,
4>     Cap = [string:to_upper(H) | T],
4>     list_to_binary(Cap ++ ".")
4>   end,
4>   kaos:tuple_of([
4>     kaos:flatmap(fun(_) -> NP end, kaos:const(sg)),
4>     VP
4>   ])
4> ).

5> {ok, Sents} = kaos:generate(Sentence, 2024, 3).
6> Sents.
[<<"The quick dog sees the blue cat.">>,
 <<"Some small cars run.">>,
 <<"This happy child sleeps near the car.">>]
```
