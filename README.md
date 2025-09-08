<img src="images/logo.png" alt="Kaos" width="416" height="224">

# Kaos

A combinator library for Erlang to genrate random values and data structures.

## Getting Started

    58> {ok, [S]} = kaos:generate(kaos:string_of(kaos:integer(4, 9), kaos:integer($a, $z)), 112, 1).
    {ok,[<<"ypwcby">>]}

## Build

    $ rebar3 compile

## Running Example Files

    $ rebar3 as examples shell

### Generate Random JSON

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

### Generate Random ASCII Graphics

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

### Generate Random Math Expression

  [examples/rand_expr.erl](examples/rand_expr.erl)

    3> rand_expr:expr(3).
    ( -39 - ( ( 29 + -52 ) - ( -90 + -65 ) ) )

### Generate Random Password

  [examples/rand_pass.erl](examples/rand_pass.erl)

    4> rand_pass:pass(18).
    "6+LP!J}vaj1sg(+K:("
