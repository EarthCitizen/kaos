-define(_assertEqualWithin(Expected, Actual, Tolerance), ?_test(?assert(abs((Expected) - (Actual)) =< (Tolerance)))).

-define(_generic_key_value_test_(MapGen, SizeFun, KeysFun, ValuesFun),
    {
        generator,
        fun () ->
            Count = 1_000_000,
            Params = [
                {{1, 3}, {9, 15}, {40, 50}},
                {{10, 20}, {50, 99}, {100, 500}}
            ],
            TestBuilder = fun ({{SizeMin, SizeMax}, {KeyMin, KeyMax}, {ValueMin, ValueMax}}) ->
                SizeGen = kaos:integer(SizeMin, SizeMax),
                KeyGen = kaos:integer(KeyMin, KeyMax),
                ValueGen = kaos:integer(ValueMin, ValueMax),
                MapsGen = MapGen(SizeGen, KeyGen, ValueGen),

                {ok, Maps} = kaos:generate(MapsGen, 9, Count),

                Sizes = unique(fun (M) -> SizeFun(M) end, Maps),
                Keys = unique_nested(fun (M) -> KeysFun(M) end, Maps),
                Values = unique_nested(fun (M) -> ValuesFun(M) end, Maps),
                [
                    {
                        format_string("Generated ~p maps", [Count]),
                        ?_assertEqual(Count, length(Maps))
                    },
                    {
                        format_string("Sizes are from ~p to ~p", [SizeMin, SizeMax]),
                        ?_assertEqual(lists:seq(SizeMin, SizeMax), Sizes)
                    },
                    {
                        format_string("Keys are from ~p to ~p", [KeyMin, KeyMax]),
                        ?_assertEqual(lists:seq(KeyMin, KeyMax), Keys)
                    },
                    {
                        format_string("Values are from ~p to ~p", [ValueMin, ValueMax]),
                        ?_assertEqual(lists:seq(ValueMin, ValueMax), Values)
                    }
                ]
            end,
            lists:map(
                TestBuilder,
                Params
            )
        end
    }
).

-define(_generic_bad_size_test_(GenWithSize),
    ?_assertMatch(
        {error, {badarg, "Size generator must provide an integer"}, _},
        kaos:generate(GenWithSize, 909, 1)
    )
).

-define(_generic_set_test_(SetGenFun, ToListFun),
    {
        generator,
        fun () ->
            ElemGen = kaos:cycle([
                kaos:const(1),
                kaos:const(1),
                kaos:const(2),
                kaos:const(2),
                kaos:const(3),
                kaos:const(3)
            ]),
            Params = [
                {1, [1]},
                {2, [1, 2]},
                {2, [1, 2]},
                {3, [1, 2, 3]},
                {3, [1, 2, 3]}
            ],
            TestBuilder = fun ({Size, Expected}) ->
                {ok, [Set]} = kaos:generate(SetGenFun(kaos:const(Size), ElemGen), 909, 1),
                Actual = ToListFun(Set),
                [
                    {
                        format_string("Set expected to contain ~p. Actual was ~p", [Expected, Actual]),
                        ?_assertEqual(Expected, Actual)
                    }
                ]
            end,
            lists:map(
                TestBuilder,
                Params
            )
        end
    }
).
