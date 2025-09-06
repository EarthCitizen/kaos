kaos
=====

A combinator library for Erlang to genrate random values and data structures.

Getting Started
---------------

    58> {ok, [S]} = kaos:generate(kaos:string(kaos:integer(4, 9), kaos:integer($a, $z)), 112, 1).
    {ok,[<<"ypwcby">>]}

Build
-----

    $ rebar3 compile

Running Example Files
---------------------

  [examples/rand_json.erl](examples/rand_json.erl)

    $ rebar3 as examples shell
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

  [examples/rand_boxes.erl](examples/rand_boxes.erl)

    2> rand_boxes:boxes().
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
