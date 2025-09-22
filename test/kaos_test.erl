-module(kaos_test).
-include_lib("eunit/include/eunit.hrl").
-include("kaos_test.hrl").

format_string(Format, Args) -> lists:flatten(io_lib:format(Format, Args)).

unique(Fn, List) ->
    lists:sort(lists:uniq(lists:map(Fn, List))).

unique(List) ->
    lists:sort(lists:uniq(List)).

unique_nested(Fn, List) ->
    lists:sort(lists:uniq(lists:flatten(lists:map(Fn, List)))).


all_test_() ->
    AllGen = kaos:all([kaos:const(100), kaos:const(200)]),
    {ok, All} = kaos:generate(AllGen, 1000, 3),
    GetXY = fun (X, Y, List) -> lists:nth(Y, lists:nth(X, List)) end,
    [
        ?_assertEqual(GetXY(1, 1, All), 100),
        ?_assertEqual(GetXY(1, 2, All), 200),
        ?_assertEqual(GetXY(2, 1, All), 100),
        ?_assertEqual(GetXY(2, 2, All), 200),
        ?_assertEqual(GetXY(3, 1, All), 100),
        ?_assertEqual(GetXY(3, 2, All), 200)
    ].

array_of_test_() ->
    ElementsGen = kaos:cycle([
        kaos:const(100),
        kaos:const(200),
        kaos:const(300),
        kaos:const(400),
        kaos:const(500),
        kaos:const(600)
    ]),
    ArrGen1 = kaos:array_of(kaos:const(1), ElementsGen),
    ArrGen2 = kaos:array_of(kaos:const(3), ElementsGen),
    ArrGen3 = kaos:array_of(kaos:const(6), ElementsGen),
    {ok, [Arr1]} = kaos:generate(ArrGen1, 1001, 1),
    {ok, [Arr2]} = kaos:generate(ArrGen2, 1002, 1),
    {ok, [Arr3]} = kaos:generate(ArrGen3, 1003, 1),
    [
        ?_assertEqual(array:size(Arr1), 1),
        ?_assertEqual(array:get(0, Arr1), 100),

        ?_assertEqual(array:size(Arr2), 3),
        ?_assertEqual(array:get(0, Arr2), 100),
        ?_assertEqual(array:get(1, Arr2), 200),
        ?_assertEqual(array:get(2, Arr2), 300),

        ?_assertEqual(array:size(Arr3), 6),
        ?_assertEqual(array:get(0, Arr3), 100),
        ?_assertEqual(array:get(1, Arr3), 200),
        ?_assertEqual(array:get(2, Arr3), 300),
        ?_assertEqual(array:get(3, Arr3), 400),
        ?_assertEqual(array:get(4, Arr3), 500),
        ?_assertEqual(array:get(5, Arr3), 600)
    ].

array_of_bad_size_test_() -> ?_generic_bad_size_test_(kaos:array_of(kaos:boolean(), kaos:const(ok))).

binary_of_bad_size_test_() -> ?_generic_bad_size_test_(kaos:binary_of(kaos:boolean(), kaos:const(1))).

binary_of_bad_byte_test_() ->
    ?_assertMatch(
        {error, {badarg, "Byte generator must provide an integer between 0 and 255"}, _},
        kaos:generate(kaos:binary_of(kaos:const(1), kaos:const(1_000)), 909, 1)
    ).

binary_of_bad_byte_nonint_test_() ->
    ?_assertMatch(
        {error, {badarg, "Byte generator must provide an integer"}, _},
        kaos:generate(kaos:binary_of(kaos:const(1), kaos:const(foo)), 909, 1)
    ).

binary_of_bad_byte_oob_test_() ->
    ResultN999 = kaos:generate(kaos:binary_of(kaos:const(2), kaos:const(-999)), 909, 1),
    ResultN1 = kaos:generate(kaos:binary_of(kaos:const(2), kaos:const(-1)), 909, 1),
    Result256 = kaos:generate(kaos:binary_of(kaos:const(2), kaos:const(256)), 909, 1),
    Result999 = kaos:generate(kaos:binary_of(kaos:const(2), kaos:const(999)), 909, 1),
    [
        ?_assertMatch(
            {error, {badarg, "Byte generator must provide an integer between 0 and 255"}, _},
            ResultN999
        ),
        ?_assertMatch(
            {error, {badarg, "Byte generator must provide an integer between 0 and 255"}, _},
            ResultN1
        ),
        ?_assertMatch(
            {error, {badarg, "Byte generator must provide an integer between 0 and 255"}, _},
            Result256
        ),
        ?_assertMatch(
            {error, {badarg, "Byte generator must provide an integer between 0 and 255"}, _},
            Result999
        )
    ].

binary_of_test_() ->
    {
        generator,
        fun () ->
            lists:map(
                fun ({Size, Byte}) ->
                    {ok, [Binary]} = kaos:generate(kaos:binary_of(kaos:const(Size), kaos:const(Byte)), 909, 1),
                    ExpectedBytes =
                        case Size of
                            0 -> [];
                            _ -> [Byte]
                        end,
                    ActualBytes = lists:uniq(binary:bin_to_list(Binary)),
                    [
                        {
                            format_string("Expected binary to have ~p bytes", [Size]),
                            ?_assertEqual(Size, byte_size(Binary))
                        },
                        {
                            format_string("Expected all bytes to be ~p or empty for size 0", [Byte]),
                            ?_assertEqual(ExpectedBytes, ActualBytes)

                        }
                    ]
                end,
                [{0, 0}, {1, 12}, {3, 36}, {12, 48}, {97, 96}, {121, 144}, {12_003, 224}]
            )
        end
    }.

bit_test_() ->
    Count = 144,
    {ok, BitCounts } = kaos:generate_into(
        kaos:bit(),
        909,
        Count,
        fun (Bit, Acc) -> io:format("~p~n", [Acc]), maps:update_with(Bit, fun (V) -> V + 1 end, 1, Acc) end,
        #{}
    ),
    [
        {
            "Results contain only 0 and 1",
            ?_assertEqual([0, 1], lists:sort(maps:keys(BitCounts)))
        },
        {
            "Counts ad up to samples",
            ?_assertEqual(Count, maps:get(0, BitCounts) + maps:get(1, BitCounts))
        }
    ].

bitstring_of_bad_size_test_() -> ?_generic_bad_size_test_(kaos:bitstring_of(kaos:boolean(), kaos:bit())).

bitstring_of_bad_bit_test_() ->
    ?_assertMatch(
        {error, {badarg, "Bit generator must produce 0 or 1"}, _},
        kaos:generate(kaos:bitstring_of(kaos:const(1), kaos:const(1_000)), 909, 1)
    ).

bitstring_of_test_() ->
    {
        generator,
        fun () ->
            lists:map(
                fun (Size) ->
                    {ok, [Bitstring]} = kaos:generate(kaos:bitstring_of(kaos:const(Size), kaos:bit()), 909, 1),
                    [
                        {
                            format_string("Expected bitstring to have ~p bits", [Size]),
                            ?_assertEqual(Size, bit_size(Bitstring))
                        }
                    ]
                end,
                [0, 1, 3, 12, 97, 121, 12_003]
            )
        end
    }.

boolean_test_() ->
    Count = 1000,
    {ok, AllValues} = kaos:generate(kaos:boolean(), 303, Count),
    UniqueValues = unique(AllValues),
    [
        {
            format_string("Generated ~p booleans", [Count]),
            ?_assertEqual(Count, length(AllValues))
        },
        {
            "All values true or false",
            ?_assertEqual([false, true], UniqueValues)
        }
    ].

byte_test_() ->
    {ok, AllValues} = kaos:generate_into(kaos:byte(), 909, 1000, fun (V, Set) -> sets:add_element(V, Set) end, sets:new()),
    Bools = sets:to_list(sets:map(fun (V) -> is_integer(V) andalso V >= 0 andalso V =< 255 end, AllValues)),
    {
        "All values are integers between 0 and 255",
        ?_assertEqual([true], Bools)
    }.

choose_test_() ->
    Count = 1000,
    GenChoose = kaos:choose([kaos:const(1), kaos:const(2), kaos:const(3)]),
    {ok, Values} = kaos:generate(GenChoose, 909, Count),
    [
        ?_assertEqual(Count, length(Values)),
        ?_assertEqual([1, 2, 3], unique(Values))
    ].

const_test_() ->
    {ok, A} = kaos:generate(kaos:const(1), 909, 3),
    {ok, B} = kaos:generate(kaos:const(1), 909, 9),
    [
        ?_assertEqual([1, 1, 1], A),
        ?_assertEqual([1, 1, 1, 1, 1, 1, 1, 1, 1], B)
    ].

choose_from_list_test_() ->
    Actual = kaos:choose_from_list([1, 2, 3]),
    Expected = kaos:choose([kaos:const(1), kaos:const(2), kaos:const(3)]),
    ?_assertEqual(Expected, Actual).

cycle_test_() ->
    Gen = kaos:cycle([
        kaos:const(1),
        kaos:const(true),
        kaos:const("abc")
    ]),
    {ok, Over} = kaos:generate(Gen, 505, 7),
    {ok, Under} = kaos:generate(Gen, 505, 2),
    {ok, One} = kaos:generate(Gen, 505, 1),
    [
        ?_assertEqual([1, true, "abc", 1, true, "abc", 1], Over),
        ?_assertEqual([1, true], Under),
        ?_assertEqual([1], One),
        ?_assertError(function_clause, kaos:cycle([])),
        ?_assertError(function_clause, kaos:cycle([1]))
    ].

dict_of_bad_size_test_() -> ?_generic_bad_size_test_(kaos:dict_of(kaos:boolean(), kaos:const(2), kaos:const(1))).

dict_of_test_() -> ?_generic_key_value_test_(
    fun kaos:dict_of/3,
    fun dict:size/1,
    fun dict:fetch_keys/1,
    fun (D) -> [Value || {_, Value} <:- dict:to_list(D)] end
).

filter_test_() ->
    Values = lists:seq(1, 20),
    Gens = lists:map(fun kaos:const/1, Values),
    FiveGen = kaos:filter(fun (X) -> (X rem 5) =:= 0 end, kaos:cycle(Gens)),
    ThreeGen = kaos:filter(fun (X) -> (X rem 3) =:= 0 end, kaos:cycle(Gens)),
    {ok, Fives} = kaos:generate(FiveGen, 1212, 4),
    {ok, Threes} = kaos:generate(ThreeGen, 1212, 6),
    [
        ?_assertEqual([5, 10, 15, 20], Fives),
        ?_assertEqual([3, 6, 9, 12, 15, 18], Threes)
    ].

flatmap_test_() ->
    SizeGen = kaos:const(3),
    FlatMapGen = kaos:flatmap(
        fun (S) -> kaos:list_of(kaos:const(S), kaos:const("A")) end,
        SizeGen
    ),
    {ok, Values} = kaos:generate(FlatMapGen, 999, 3),
    [
        ?_assertEqual([["A", "A", "A"], ["A", "A", "A"], ["A", "A", "A"]], Values)
    ].

float_test_() ->
    {
        generator,
        fun () ->
            Count = 1000,
            Ranges = [
                {-9999.0, 9999.0},
                {0.5, 10.5},
                {0.00001, 0.5},
                {-10.1, 0.1},
                {100_000.0, 200_000.0}
            ],
            lists:map(
                fun ({Min, Max}) ->
                    Gen = kaos:float(Min, Max),

                    {ok, Values} = kaos:generate(Gen, 707, Count),

                    InRange = unique(fun (E) -> E >= Min andalso E =< Max end, Values),
                    RangeDescr = format_string("Range ~p to ~p: ", [Min, Max]),
                    [
                        {RangeDescr ++ "Expected Count Sampled", ?_assertEqual(Count, length(Values))},
                        {RangeDescr ++ "All Values in Range", ?_assertEqual([true], InRange)}
                    ]
                end,
                Ranges
            )
        end
    }.

gb_set_of_bad_size_test_() -> ?_generic_bad_size_test_(kaos:gb_set_of(kaos:boolean(), kaos:const(1))).

gb_set_of_test_() -> ?_generic_set_test_(fun kaos:gb_set_of/2, fun gb_sets:to_list/1).

gb_tree_of_bad_size_test_() -> ?_generic_bad_size_test_(kaos:gb_tree_of(kaos:boolean(), kaos:const(2), kaos:const(1))).

gb_tree_of_test_() -> ?_generic_key_value_test_(fun kaos:gb_tree_of/3, fun gb_trees:size/1, fun gb_trees:keys/1, fun gb_trees:values/1).

integer_test_() ->
    {
        generator,
        fun () ->
            Count = 1000,
            Ranges = [
                {-9999, 9999},
                {0, 10},
                {-10, 0},
                {100_000, 200_000}
            ],
            lists:map(
                fun ({Min, Max}) ->
                    Gen = kaos:integer(Min, Max),

                    {ok, Values} = kaos:generate(Gen, 707, Count),

                    InRange = unique(fun (E) -> E >= Min andalso E =< Max end, Values),
                    RangeDescr = format_string("Range ~p to ~p: ", [Min, Max]),
                    [
                        {RangeDescr ++ "Expected Count Sampled", ?_assertEqual(Count, length(Values))},
                        {RangeDescr ++ "All Values in Range", ?_assertEqual([true], InRange)}
                    ]
                end,
                Ranges
            )
        end
    }.

iterate_test_() ->
    InitState = {1, 3},
    IterFun = fun ({Count, Product}) -> {Count + 1, Product * 3} end,
    GenIter = kaos:iterate(IterFun, InitState),
    {ok, Samples} = kaos:generate(GenIter, 909, 6),
    ?_assertEqual(
        [
            {1, 3},
            {2, 9},
            {3, 27},
            {4, 81},
            {5, 243},
            {6, 729}
        ],
        Samples
    ).

list_of_bad_size_test_() ->
    ?_assertMatch(
        {error, {badarg, "Size generator must provide an integer"}, _},
        kaos:generate(
            kaos:list_of(kaos:boolean(), kaos:const(1)),
            909,
            1
        )
    ).

list_of_test_() ->
    {
        generator,
        fun () ->
            Count = 1000,
            Params = [
                {{1, 3}, {4, 10}},
                {{10, 20}, {100, 500}}
            ],
            lists:map(
                fun ({{SizeMin, SizeMax}, {ValueMin, ValueMax}}) ->
                    SizeGen = kaos:integer(SizeMin, SizeMax),
                    ValueGen = kaos:integer(ValueMin, ValueMax),
                    ListsGen = kaos:list_of(SizeGen, ValueGen),

                    {ok, Lists} = kaos:generate(ListsGen, 9, Count),

                    Sizes = unique(fun length/1, Lists),
                    Values = unique(lists:flatten(Lists)),
                    [
                        {
                            format_string("Generated ~p lists", [Count]),
                            ?_assertEqual(Count, length(Lists))
                        },
                        {
                            format_string("Sizes are from ~p to ~p", [SizeMin, SizeMax]),
                            ?_assertEqual(lists:seq(SizeMin, SizeMax), Sizes)
                        },
                        {
                            format_string("Values are from ~p to ~p", [ValueMin, ValueMax]),
                            ?_assertEqual(lists:seq(ValueMin, ValueMax), Values)
                        }
                    ]
                end,
                Params
            )
        end
    }.

map_test_() ->
    ValueGen = kaos:const(3),
    MapGen = kaos:map(
        fun (S) -> S * 10 end,
        ValueGen
    ),
    {ok, Values} = kaos:generate(MapGen, 999, 3),
    [
        {
            format_string("Mapped all generated values to 30", []),
            ?_assertEqual([30, 30, 30], Values)
        }
    ].

map_of_bad_size_test_() -> ?_generic_bad_size_test_(kaos:map_of(kaos:boolean(), kaos:const(2), kaos:const(1))).

map_of_test_() -> ?_generic_key_value_test_(fun kaos:map_of/3, fun maps:size/1, fun maps:keys/1, fun maps:values/1).

orddict_of_bad_size_test_() -> ?_generic_bad_size_test_(kaos:orddict_of(kaos:boolean(), kaos:const(2), kaos:const(1))).

orddict_of_test_() -> ?_generic_key_value_test_(
    fun kaos:orddict_of/3,
    fun orddict:size/1,
    fun orddict:fetch_keys/1,
    fun (D) -> [Value || {_, Value} <:- orddict:to_list(D)] end
).

ordset_of_bad_size_test_() -> ?_generic_bad_size_test_(kaos:ordset_of(kaos:boolean(), kaos:const(1))).

ordset_of_test_() -> ?_generic_set_test_(fun kaos:ordset_of/2, fun ordsets:to_list/1).

recurse_test_() ->
    GenSeq = kaos:iterate(fun (N) -> N + 1 end, 1),
    Run = fun Recur () ->
        kaos:recurse(
            fun (Depth) ->
                case Depth < 3 of
                    true -> kaos:list_of(kaos:const(2), Recur());
                    false -> GenSeq
                end
            end
        )
    end,
    {ok, [Result]} = kaos:generate((Run()), 101, 1),
    ?_assertEqual(
        [
            [
                [1,2],
                [3,4]
            ],
            [
                [5,6],
                [7,8]
            ]
        ],
        Result
    ).

set_of_bad_size_test_() -> ?_generic_bad_size_test_(kaos:set_of(kaos:boolean(), kaos:const(1))).

set_of_test_() -> ?_generic_set_test_(fun kaos:set_of/2, fun sets:to_list/1).

shuffle_test_() ->
    {
        generator,
        fun () ->
            lists:map(
                fun ({Input, Expected}) ->
                    {ok, Actual} = kaos:generate(kaos:shuffle(Input), 909, 3),
                    ?_assertEqual(Expected, Actual)
                end,
                [
                    {[], [[], [], []]},
                    {[1], [[1], [1], [1]]},
                    {[1, 2, 3], [[3,1,2],[3,2,1],[2,1,3]]},
                    {"abcdefg", ["fgbdaec","bcgadfe","cbdfeag"]}
                ]
            )
        end
    }.

string_of_test_() ->
    {
        generator,
        fun () ->
            lists:map(
                fun ({Expected, Size, GenChar}) ->
                    GenString = kaos:string_of(kaos:const(Size), GenChar),
                    {ok, [Actual]} = kaos:generate(GenString, 101, 1),
                    [?_assertEqual(Expected, Actual)]
                end,
                [
                    {<<"AAA">>, 3, kaos:const($A)},
                    {<<"XYXYXY">>, 6, kaos:cycle([kaos:const($X), kaos:const($Y)])}
                ]
            )
        end
    }.

string_of_bad_code_point_test_() ->
    [
        ?_assertMatch(
            {error, {badarg, "Invalid code point given by generator."}, _},
            kaos:generate(kaos:string_of(kaos:const(2), kaos:const([$a, $b])), 909, 1)
        ),
        ?_assertMatch(
            {error, {badarg, "Invalid code point given by generator."}, _},
            kaos:generate(kaos:string_of(kaos:const(2), kaos:const(-1)), 909, 1)
        )
    ].

string_of_bad_size_test_() -> ?_generic_bad_size_test_(kaos:string_of(kaos:boolean(), kaos:const($A))).

tuple_of_test_() ->
    {
        generator,
        fun () ->
            Count = 100,
            Params = lists:seq(0, 24),
            lists:map(
                fun (Size) ->
                    ExpectedValues = case Size of
                        0 -> [];
                        _ -> lists:seq(1, Size)
                    end,

                    TupleGen = kaos:tuple_of(lists:map(fun kaos:const/1, ExpectedValues)),

                    {ok, Tuples} = kaos:generate(TupleGen, 9, Count),

                    ActualValues = unique(fun tuple_to_list/1, Tuples),
                    [
                        {
                            format_string("Generated ~p of ~p element tuples", [Count, Size]),
                            ?_assertEqual(Count, length(Tuples))
                        },
                        {
                            format_string("All ~p element tuples contain expected values", [Size]),
                            ?_assertEqual([ExpectedValues], ActualValues)
                        }
                    ]
                end,
                Params
            )
        end
    }.

weighted_test_() ->
    {
        generator,
        fun () ->
            Count = 1_000_000,
            Params = [
                {
                    #{2 => 200_000, 8 => 800_000},
                    [{20, kaos:const(2)}, {80, kaos:const(8)}]
                },
                {
                    #{10 => 100_000, 30 => 300000, 20 => 200_000, 35 => 350_000, 5 => 50_000},
                    [{10, kaos:const(10)}, {30, kaos:const(30)}, {20, kaos:const(20)}, {35, kaos:const(35)}, {5, kaos:const(5)}]

                }
            ],
            CountMerge = fun (Value, CountMap) ->
                maps:merge_with(
                    fun (_, V1, V2) -> V1 + V2 end,
                    CountMap,
                    #{Value => 1}
                )
            end,
            lists:map(
                fun ({ExpectedCounts, WeightedGens}) ->
                    {ok, SampleCounts} = kaos:generate_into(kaos:weighted(WeightedGens), 909, Count, CountMerge, #{}),
                    Tolerance = 0.0015,
                    [
                        {
                            "Expected samples generated",
                            ?_assertEqual(Count, lists:foldl(fun (V, Sum) -> V + Sum end, 0, maps:values(SampleCounts)))
                        },
                        lists:map(
                            fun (ValueKey) ->
                                #{ValueKey := ExpectedCount} = ExpectedCounts,
                                #{ValueKey := ActualCount} = SampleCounts,
                                ExpectedPercentage = ExpectedCount / Count,
                                ActualPercentage = ActualCount / Count,
                                [
                                    {
                                        format_string(
                                            "Percent of samples ~p expected to be within ~p of ~p~n",
                                            [ActualPercentage, Tolerance, ExpectedPercentage]
                                        ),
                                        ?_assertEqualWithin(ExpectedPercentage, ActualPercentage, Tolerance)
                                    }
                                ]
                            end,
                            maps:keys(ExpectedCounts)
                        )
                    ]
                end,
                Params
            )
        end
    }.

weighted_bad_weight_test_() ->
    ?_assertError(function_clause, kaos:weighted([{0, kaos:const(a)}, {1, kaos:const(b)}])).

weighted_from_list_test_() ->
    MultipleActual = kaos:weighted_from_list([1, 2, 3]),
    MultipleExpected = {3, kaos:choose([kaos:const(1), kaos:const(2), kaos:const(3)])},
    SingleActual = kaos:weighted_from_list([ready]),
    SingleExpected = {1, kaos:const(ready)},
    [
        ?_assertEqual(MultipleExpected, MultipleActual),
        ?_assertEqual(SingleExpected, SingleActual)
    ].

weighted_from_range_test_() ->
    Actual = kaos:weighted_from_range(1, 3),
    Expected = {3, kaos:integer(1, 3)},
    ?_assertEqual(Expected, Actual).

generate_different_seed_test_() ->
    {ok, Values1} = kaos:generate(kaos:integer(1, 500), 909, 500),
    {ok, Values2} = kaos:generate(kaos:integer(1, 500), 450, 500),
    [
        {
            "Different seeds generate different values",
            ?_assertNotEqual(Values1, Values2)
        }
    ].

generate_same_seed_test_() ->
    {ok, Values1} = kaos:generate(kaos:integer(1, 500), 909, 500),
    {ok, Values2} = kaos:generate(kaos:integer(1, 500), 909, 500),
    [
        {
            "Same seeds generate same values",
            ?_assertEqual(Values1, Values2)
        }
    ].

generate_into_timeout_test_() ->
    Slow = kaos:map(fun(X) -> timer:sleep(10), X end, kaos:const(ok)),
    ?_assertEqual({error, timeout}, kaos:generate_into(Slow, 0, 2, fun(_, A) -> A end, ok, 1)).

generate_into_user_fun_error_test_() ->
    ?_assertMatch(
        {error, badmerge, _},
        kaos:generate_into(kaos:const(1), 0, 3, fun(_, _) -> erlang:error(badmerge) end, [])
    ).

generate_with_non_generator_test_() ->
    Res = kaos:generate(not_a_generator, 909, 1),
    case Res of
        {error, {badarg, Msg}, _} ->
            ?_assertMatch(true, string:prefix(Msg, "Argument provided does not appear to be a generator") =/= nomatch);
        _ -> ?_assert(false)
    end.
