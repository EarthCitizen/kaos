<img src="images/logo.png" alt="Kaos" width="416" height="224">

Kaos
=====

A combinator library for Erlang to genrate random values and data structures.

Getting Started
---------------

Quick reference of common functions:

| Function | Description | Example |
|---|---|---|
| `kaos:all([Gen,...])` | Sequence generators to a list | `kaos:generate(kaos:all([kaos:integer(1,9), kaos:boolean()]), 42, 2)` |
| `kaos:array_of(SizeGen, ElemGen)` | array:array() from elements | `kaos:array_of(kaos:integer(1,3), kaos:byte())` |
| `kaos:ascii_char()` | Printable ASCII character code | `kaos:generate(kaos:ascii_char(), 42, 4)` |
| `kaos:binary_of(SizeGen, ByteGen)` | Binary of bytes | `kaos:binary_of(kaos:integer(1,4), kaos:byte())` |
| `kaos:bitstring_of(SizeGen)` | Bitstring of bits (0/1) | `kaos:bitstring_of(kaos:integer(1,4))` |
| `kaos:boolean()` | True/false values | `kaos:generate(kaos:boolean(), 42, 5)` |
| `kaos:byte()` | Integer 0..255 | `kaos:generate(kaos:byte(), 42, 4)` |
| `kaos:choose([Gen,...])` | Choose from generators uniformly | `kaos:generate(kaos:choose([kaos:const(a), kaos:const(b)]), 42, 4)` |
| `kaos:const(Value)` | Always returns `Value` | `kaos:generate(kaos:const(ok), 42, 1)` |
| `kaos:cycle([Gen,...])` | Cycle through generators | `kaos:generate(kaos:cycle([kaos:const(1), kaos:const(2)]), 42, 4)` |
| `kaos:dict_of(SizeGen, KeyGen, ValGen)` | dict dictionary | `kaos:dict_of(kaos:integer(1,2), kaos:byte(), kaos:boolean())` |
| `kaos:filter(Pred, Gen)` | Filter generated values | `kaos:filter(fun (X) -> X rem 2 =:= 0 end, kaos:integer(1,10))` |
| `kaos:flatmap(Fun, Gen)` | Flat-map to new generator | `kaos:flatmap(fun (N) -> kaos:integer(1,N) end, kaos:integer(1,5))` |
| `kaos:float(Min, Max)` | Float in inclusive range | `kaos:generate(kaos:float(-1.0, 1.0), 42, 2)` |
| `kaos:gb_set_of(SizeGen, ElemGen)` | gb_sets set | `kaos:gb_set_of(kaos:integer(1,3), kaos:integer(1,5))` |
| `kaos:gb_tree_of(SizeGen, KeyGen, ValGen)` | gb_trees map | `kaos:gb_tree_of(kaos:integer(1,2), kaos:byte(), kaos:boolean())` |
| `kaos:integer(Min, Max)` | Integer in inclusive range | `kaos:generate(kaos:integer(1, 10), 42, 3)` |
| `kaos:iterate(fun(Idx,Prev)->Gen end)` | Stateful iteration | `kaos:iterate(fun(I,_) -> kaos:const(I) end)` |
| `kaos:list_of(SizeGen, ElemGen)` | List of size with element generator | `kaos:list_of(kaos:integer(1,3), kaos:integer(0,9))` |
| `kaos:map(Fun, Gen)` | Map over generated value | `kaos:map(fun (X) -> X*2 end, kaos:integer(1,5))` |
| `kaos:map_of(SizeGen, KeyGen, ValGen)` | Erlang map (maps) | `kaos:map_of(kaos:integer(1,3), kaos:byte(), kaos:boolean())` |
| `kaos:orddict_of(SizeGen, KeyGen, ValGen)` | orddict dictionary | `kaos:orddict_of(kaos:integer(1,2), kaos:byte(), kaos:boolean())` |
| `kaos:ordset_of(SizeGen, ElemGen)` | ordsets set | `kaos:ordset_of(kaos:integer(1,3), kaos:integer(1,5))` |
| `kaos:recurse(fun(Depth)->Gen end)` | Depth-aware recursion | `kaos:recurse(fun(D)-> if D<3 -> kaos:integer(1,9); true -> kaos:const(0) end end)` |
| `kaos:set_of(SizeGen, ElemGen)` | sets set | `kaos:set_of(kaos:integer(1,3), kaos:integer(1,5))` |
| `kaos:string_of(GenSize, GenChar)` | UTF-8 string from char generator | `kaos:string_of(kaos:integer(3,6), kaos:integer($a,$z))` |
| `kaos:tuple_of([Gen,...])` | Tuple from generators | `kaos:tuple_of([kaos:byte(), kaos:boolean()])` |
| `kaos:weighted([{W,Gen},...])` | Choose by weight | `kaos:generate(kaos:weighted([{1,kaos:const(a)},{3,kaos:const(b)}]), 42, 4)` |
| `kaos:generate(Gen, Seed, N)` | Produce `N` samples deterministically | `{ok, Samples} = kaos:generate(kaos:integer(1,9), 112, 3)` |
| `kaos:generate(Gen, Seed, N, Merge, Acc0)` | Fold over samples with custom merge | `kaos:generate(kaos:boolean(), 112, 5, fun(V,M)->maps:update_with(V, fun(X)->X+1 end, 1, M) end, #{})` |

    58> {ok, [S]} = kaos:generate(kaos:string_of(kaos:integer(4, 9), kaos:integer($a, $z)), 112, 1).
    {ok,[<<"ypwcby">>]}

Build
-----

    $ rebar3 compile

Running Example Files
---------------------

    $ rebar3 as examples shell

  [examples/rand_json.erl](examples/rand_json.erl)

    1> rand_json:json(12).
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

  [examples/rand_box.erl](examples/rand_box.erl)

    2> rand_box:box().
    ╕╒╜╔╖╒╛╙╗╛╖
    ╙╝╗╙╗╙╓╝╚╛╗
    ╙╒╜╕╛╓╔╕╗╙╝
    ╗╝╚╖╝╗╕╛╕╛╘
    ╝╘╘╜╕╓╖╒╓╝╗
    ╔╘╚╜╙╘╓╕╒╜╗
    ╙╕╗╖╝╛╗╖╕╗╝
    ╓╗╛╖╚╝╓╖╒╝╕
    ╒╛╒╜╛╚╖╕╝╔╓
    ╝╓╛╖╝╚╙╕╝╛╝
    ╒╛╝╛╝╖╛╒╒╝╛
    ok

  [examples/rand_expr.erl](examples/rand_expr.erl)

    3> rand_expr:expr(3).
    ( -39 - ( ( 29 + -52 ) - ( -90 + -65 ) ) )
