-module(kaos).

-export([
    all/1,
    array_of/2,
    ascii_char/0,
    binary_of/2,
    bitstring_of/1,
    boolean/0,
    byte/0,
    choose/1,
    const/1,
    cycle/1,
    dict_of/3,
    float/2,
    gb_set_of/2,
    gb_tree_of/3,
    generate/3,
    generate/5,
    integer/2,
    iterate/1,
    list_of/2,
    map_of/3,
    filter/2,
    flatmap/2,
    map/2,
    orddict_of/3,
    ordset_of/2,
    recurse/1,
    set_of/2,
    string_of/2,
    tuple_of/1,
    weighted/1
]).

-export_type([
    depth_function/0,
    flatmap_function/0,
    gen/0,
    generate_response/0,
    iterate_function/0,
    map_function/0,
    predicate_function/0,
    weighted_gen/0
]).

-import(rand, [uniform/0]).

-record(map_trait, {
    new :: fun(() -> term()),
    size :: fun((term()) -> non_neg_integer()),
    is_key :: fun((term(), term()) -> boolean()),
    put :: fun((term(), term(), term()) -> term())
}).
-record(set_trait, {
    new :: fun(() -> term()),
    size :: fun((term) -> non_neg_integer()),
    is_member :: fun((term(), term()) -> boolean()),
    add :: fun((term(), term()) -> term())
}).

-type depth_function() :: fun((non_neg_integer()) -> gen()).
-type flatmap_function() :: fun((term()) -> gen()).
-type generate_response() :: {ok, list(term())} | {error, term()}.
-type iterate_function() :: fun((pos_integer(), term()) -> gen()).
-type map_function() :: fun((term()) -> term()).
-type predicate_function() :: fun((term()) -> boolean()).
-type weighted_gen() :: {pos_integer(), gen()}.

-record(gen_all, {gens :: nonempty_list(gen())}).
-record(gen_binary, {gen_size :: gen(), gen_byte :: gen()}).
-record(gen_bitstring, {gen_size :: gen()}).
-record(gen_choose, {gens :: nonempty_list(gen())}).
-record(gen_const, {value :: term()}).
-record(gen_cycle, {id :: reference(), gens :: nonempty_list(gen())}).
-record(gen_dict, {gen_size :: gen(), gen_key :: gen(), gen_value :: gen()}).
-record(gen_float, {min_bound :: float(), max_bound :: float()}).
-record(gen_gb_set, {gen_size :: gen(), gen_value:: gen()}).
-record(gen_gb_tree, {gen_size :: gen(), gen_key :: gen(), gen_value :: gen()}).
-record(gen_integer, {min_bound :: integer(), max_bound :: integer()}).
-record(gen_iterate, {id :: reference(), f :: iterate_function()}).
-record(gen_list, {gen_size :: gen(), gen_value :: gen()}).
-record(gen_map, {gen_size :: gen(), gen_key :: gen(), gen_value :: gen()}).
-record(gen_orddict, {gen_size :: gen(), gen_key :: gen(), gen_value :: gen()}).
-record(gen_ordset, {gen_size :: gen(), gen_value :: gen()}).
-record(gen_recurse, {f :: depth_function()}).
-record(gen_set, {gen_size :: gen(), gen_value :: gen()}).
-record(gen_string, {gen_size :: gen(), gen_char :: gen()}).
-record(gen_tuple, {gens :: list(gen())}).
-record(gen_weighted, {max_bound :: pos_integer(), weighted_gens :: nonempty_list(weighted_gen())}).
-record(mod_filter, {f :: predicate_function(), gen :: gen()}).
-record(mod_flatmap, {f :: flatmap_function(), gen :: gen()}).
-record(mod_map, {f :: map_function(), gen :: gen()}).

-opaque gen() ::
    #gen_all{}
    | #gen_binary{}
    | #gen_bitstring{}
    | #gen_choose{}
    | #gen_const{}
    | #gen_cycle{}
    | #gen_dict{}
    | #gen_float{}
    | #gen_gb_set{}
    | #gen_gb_tree{}
    | #gen_integer{}
    | #gen_iterate{}
    | #gen_list{}
    | #gen_map{}
    | #gen_orddict{}
    | #gen_ordset{}
    | #gen_recurse{}
    | #gen_set{}
    | #gen_string{}
    | #gen_tuple{}
    | #gen_weighted{}
    | #mod_filter{}
    | #mod_flatmap{}
    | #mod_map{}
    .

-spec all(nonempty_list(gen())) -> gen().
all(Gens = [_ | _]) -> #gen_all{gens = Gens}.

-spec array_of(gen(), gen()) -> gen().
array_of(GenSize, GenValue) ->
    map(fun array:from_list/1, list_of(GenSize, GenValue)).

-spec ascii_char() -> gen().
ascii_char() -> integer(33, 126).

-spec binary_of(gen(), gen()) -> gen().
binary_of(GenSize, GenByte) -> #gen_binary{gen_size = GenSize, gen_byte = GenByte}.

-spec bitstring_of(gen()) -> gen().
bitstring_of(GenSize) -> #gen_bitstring{gen_size = GenSize}.

-spec boolean() -> gen().
boolean() -> choose([const(true), const(false)]).

-spec byte() -> gen().
byte() -> integer(0, 255).

-spec choose(nonempty_list(gen())) -> gen().
choose(Gens) when length(Gens) > 1 -> #gen_choose{gens = Gens}.

-spec const(term()) -> gen().
const(A) -> #gen_const{value = A}.

-spec cycle(nonempty_list(gen())) -> gen().
cycle(Gens = [_, _ | _]) -> #gen_cycle{id = make_ref(), gens = Gens}.

-spec dict_of(gen(), gen(), gen()) -> gen().
dict_of(GenSize, GenKey, GenValue) -> #gen_dict{gen_size = GenSize, gen_key = GenKey, gen_value = GenValue}.

-spec float(float(), float()) -> gen().
float(MinBound, MaxBound)
    when is_float(MinBound), is_float(MaxBound), MinBound < MaxBound ->
    #gen_float{min_bound = MinBound, max_bound = MaxBound}.

-spec gb_set_of(gen(), gen()) -> gen().
gb_set_of(GenSize, GenValue) -> #gen_gb_set{gen_size = GenSize, gen_value = GenValue}.

-spec gb_tree_of(gen(), gen(), gen()) -> gen().
gb_tree_of(GenSize, GenKey, GenValue) -> #gen_gb_tree{gen_size = GenSize, gen_key = GenKey, gen_value = GenValue}.

-spec integer(integer(), integer()) -> gen().
integer(MinBound, MaxBound)
    when is_integer(MinBound), is_integer(MaxBound), MinBound < MaxBound ->
    #gen_integer{min_bound = MinBound, max_bound = MaxBound}.

-spec iterate(iterate_function()) -> gen().
iterate(Fun) when is_function(Fun, 2) -> #gen_iterate{id = make_ref(), f = Fun}.

-spec list_of(gen(), gen()) -> gen().
list_of(GenSize, GenValue) -> #gen_list{gen_size = GenSize, gen_value = GenValue}.

-spec map_of(gen(), gen(), gen()) -> gen().
map_of(GenSize, GenKey, GenValue) -> #gen_map{gen_size = GenSize, gen_key = GenKey, gen_value = GenValue}.

-spec orddict_of(gen(), gen(), gen()) -> gen().
orddict_of(GenSize, GenKey, GenValue) -> #gen_orddict{gen_size = GenSize, gen_key = GenKey, gen_value = GenValue}.

-spec ordset_of(gen(), gen()) -> gen().
ordset_of(GenSize, GenValue) -> #gen_ordset{gen_size = GenSize, gen_value = GenValue}.

-spec recurse(depth_function()) -> gen().
recurse(Fun) when is_function(Fun, 1) -> #gen_recurse{f = Fun}.

-spec set_of(gen(), gen()) -> gen().
set_of(GenSize, GenValue) -> #gen_set{gen_size = GenSize, gen_value = GenValue}.

-spec string_of(gen(), gen()) -> gen().
string_of(GenSize, GenChar) -> #gen_string{gen_size = GenSize, gen_char = GenChar}.

-spec tuple_of(list(gen())) -> gen().
tuple_of(Gens) when is_list(Gens) -> #gen_tuple{gens = Gens}.

-spec weighted(nonempty_list(weighted_gen())) -> gen().
weighted(WeightedGens = [_ | _]) ->
    Weights = lists:map(fun({W, _}) when is_integer(W), W > 0 -> W end, WeightedGens),
    GCD = reduce(fun gcd/2, Weights),
    Increments = lists:map(fun(W) when is_integer(W) -> trunc(W / GCD) end, Weights),
    ReverseBounds =
        [_ | _] =
            lists:foldl(fun (I, []) when is_integer(I) ->
                                [I];
                            (I, A = [F | _]) when is_integer(I), is_list(A), is_integer(F) ->
                                [F + I | A]
                        end,
                        [],
                        Increments),
    Bounds = lists:reverse(ReverseBounds),
    MaxBound = lists:max(Bounds),
    BoundedGens = lists:zipwith(fun(B, {_, G}) -> {B, G} end, Bounds, WeightedGens),
    #gen_weighted{max_bound = MaxBound, weighted_gens = BoundedGens}.

gcd(A, B) when is_integer(A), is_integer(B), A < B -> gcd(B, A);
gcd(A, 0) when is_integer(A), A >= 0 -> A;
gcd(A, B) when is_integer(A), A >= 0, is_integer(B), B >= 0 -> gcd(B, A rem B).

reduce(_, [L]) -> L;
reduce(Fun, [L, R | T]) -> reduce(Fun, [Fun(L, R) | T]).

-spec filter(predicate_function(), gen()) -> gen().
filter(Fun, Gen) when is_function(Fun, 1) -> #mod_filter{f = Fun, gen = Gen}.

-spec flatmap(flatmap_function(), gen()) -> gen().
flatmap(Fun, Gen) when is_function(Fun, 1) -> #mod_flatmap{f = Fun, gen = Gen}.

-spec map(map_function(), gen()) -> gen().
map(Fun, Gen) when is_function(Fun, 1) -> #mod_map{f = Fun, gen = Gen}.

-spec generate(gen(), term(), pos_integer()) -> generate_response().
generate(Gen, Seed, Count) when is_integer(Count), Count > 0 ->
    Result = generate(
        Gen,
        Seed,
        Count,
        fun (Sample, Acc) -> [Sample | Acc] end,
        []
    ),
    case Result of
        {ok, SampleList} -> {ok, lists:reverse(SampleList)};
        Error -> Error
    end.

-spec generate(gen(), term(), pos_integer(), fun((term(), term()) -> term()), term()) -> generate_response().
generate(Gen, Seed, Count, Merge, Acc) when is_integer(Count), Count > 0 ->
    process_flag(trap_exit, true),
    Self = self(),
    % Need to user spawn monitor
    WorkerPid = spawn_link(
        fun () ->
            generate_worker(Gen, Seed, Count, Self, Merge, Acc)
        end
    ),
    CleanUpMessages =
        fun Loop () ->
            receive
                _ -> Loop()
            after 0 ->
                ok
            end
        end,
    CleanUpWorker =
        fun () ->
            process_flag(trap_exit, false),
            unlink(WorkerPid),
            exit(WorkerPid, normal),
            CleanUpMessages()
        end,
    receive
        {'EXIT', _, Error} -> CleanUpWorker(), {error, Error};
        Error = {error, _, _} -> CleanUpWorker(), Error;
        Result = {ok, _} -> CleanUpWorker(), Result
    after 30_000 ->
        CleanUpWorker(),
        {error, timeout}
    end.

generate_worker(Gen, Seed, Count, To, Merge, Acc) when is_integer(Count), Count > 0 ->
    _ = rand:seed(exsss, Seed),
    RunLoop =
        fun Loop(RemainingCount, LoopAcc) ->
            case RemainingCount of
                0 -> LoopAcc;
                _ ->
                    Sample = generate_one(Gen),
                    Loop(RemainingCount - 1, Merge(Sample, LoopAcc))
            end
        end,
    try
        To ! {ok, RunLoop(Count, Acc)}
    catch
        _:Error:Stacktrace ->
            To ! {error, Error, Stacktrace}
    end.

generate_one(#gen_all{gens = Gens}) ->
    lists:map(fun generate_one/1, Gens);
generate_one(#gen_binary{gen_size = GenSize, gen_byte = GenByte}) ->
    case Size = generate_one_size(GenSize) of
        0 -> <<>>;
        _ ->
            Bytes = [generate_one_byte(GenByte) || _ <- lists:seq(1, Size)],
            << <<B>> || B <- Bytes >>
    end;
generate_one(#gen_bitstring{gen_size = GenSize}) ->
    case Size = generate_one_size(GenSize) of
        0 -> <<>>;
        _ ->
            ZeroOrOne = choose([const(0), const(1)]),
            Bits = generate_one(all(lists:duplicate(Size, ZeroOrOne))),
            << <<B:1>> || B <- Bits >>
    end;
generate_one(#gen_choose{gens = Gens}) ->
    Index = generate_one(integer(1, length(Gens))),
    generate_one(lists:nth(Index, Gens));
generate_one(#gen_const{value = Value}) ->
    Value;
generate_one(#gen_cycle{id = Id, gens = Gens}) ->
    StateKey = {kaos, gen_cycle, Id},
    InitState = fun () -> put(StateKey, 1) end,
    GetNextIndex =
        fun NextIndex() ->
            case get(StateKey) of
                undefined ->
                    InitState(),
                    NextIndex();
                N when is_integer(N), N > length(Gens) ->
                    InitState(),
                    NextIndex();
                N when is_integer(N) ->
                    put(StateKey, N + 1),
                    N
            end
        end,
    generate_one(lists:nth(GetNextIndex(), Gens));
generate_one(#gen_dict{gen_size = GenSize, gen_key = GenKey, gen_value = GenValue}) ->
    Size = generate_one_size(GenSize),
    MapTrait = #map_trait{
        new = fun dict:new/0,
        size = fun dict:size/1,
        is_key = fun dict:is_key/2,
        put = fun dict:store/3
    },
    generate_one_map_until_size(MapTrait, GenKey, GenValue, Size);
generate_one(#gen_float{min_bound = MinBound, max_bound = MaxBound}) ->
    MaxFromZero = MaxBound - MinBound,
    rand:uniform_real() * MaxFromZero + MinBound;
generate_one(#gen_gb_set{gen_size = GenSize, gen_value = GenValue}) ->
    Size = generate_one_size(GenSize),
    SetTrait =
        #set_trait{new = fun gb_sets:new/0,
                   size = fun gb_sets:size/1,
                   is_member = fun gb_sets:is_member/2,
                   add = fun gb_sets:add/2},
    generate_one_set_until_size(SetTrait, GenValue, Size);
generate_one(#gen_gb_tree{gen_size = GenSize, gen_key = GenKey, gen_value = GenValue}) ->
    Size = generate_one_size(GenSize),
    MapTrait =
        #map_trait{new = fun gb_trees:empty/0,
                   size = fun gb_trees:size/1,
                   is_key = fun gb_trees:is_defined/2,
                   put = fun gb_trees:enter/3},
    generate_one_map_until_size(MapTrait, GenKey, GenValue, Size);
generate_one(#gen_integer{min_bound = MinBound, max_bound = MaxBound}) ->
    MaxFromZero = MaxBound - MinBound,
    rand:uniform(MaxFromZero + 1) - 1 + MinBound;
generate_one(#gen_iterate{id = Id, f = Fun}) ->
    StateKey = {kaos, gen_iterate, Id},
    {Count, PreviousTermHolder} =
        case get(StateKey) of
            undefined ->
                {1, {}};
            State -> State
        end,
    NewTerm = Fun(Count, PreviousTermHolder),
    put(StateKey, {Count + 1, {NewTerm}}),
    NewTerm;
generate_one(#gen_list{gen_size = GenSize, gen_value = GenValue}) ->
    Size = generate_one_size(GenSize),
    lists:map(fun(_) -> generate_one(GenValue) end, lists:seq(1, Size));
generate_one(#gen_map{gen_size = GenSize, gen_key = GenKey, gen_value = GenValue}) ->
    Size = generate_one_size(GenSize),
    MapTrait =
        #map_trait{new = fun maps:new/0,
                   size = fun maps:size/1,
                   is_key = fun maps:is_key/2,
                   put = fun maps:put/3},
    generate_one_map_until_size(MapTrait, GenKey, GenValue, Size);
generate_one(#gen_orddict{gen_size = GenSize, gen_key = GenKey, gen_value = GenValue}) ->
    Size = generate_one_size(GenSize),
    MapTrait =
        #map_trait{new = fun orddict:new/0,
                   size = fun orddict:size/1,
                   is_key = fun orddict:is_key/2,
                   put = fun orddict:store/3},
    generate_one_map_until_size(MapTrait, GenKey, GenValue, Size);
generate_one(#gen_ordset{gen_size = GenSize, gen_value = GenValue}) ->
    Size = generate_one_size(GenSize),
    SetTrait =
        #set_trait{new = fun ordsets:new/0,
                   size = fun ordsets:size/1,
                   is_member = fun ordsets:is_element/2,
                   add = fun ordsets:add_element/2},
    generate_one_set_until_size(SetTrait, GenValue, Size);
generate_one(#gen_set{gen_size = GenSize, gen_value = GenValue}) ->
    Size = generate_one_size(GenSize),
    SetTrait =
        #set_trait{new = fun sets:new/0,
                   size = fun sets:size/1,
                   is_member = fun sets:is_element/2,
                   add = fun sets:add_element/2},
    generate_one_set_until_size(SetTrait, GenValue, Size);
generate_one(#gen_recurse{f = Fun}) ->
    StateKey = {kaos, gen_recurse},
    Depth = case get(StateKey) of
        undefined ->
            put(StateKey, 0),
            0;
        PreviousLevel ->
            NewDepth = PreviousLevel + 1,
            put(StateKey, NewDepth),
            NewDepth
    end,
    try
        generate_one(Fun(Depth))
    after
        case Depth of
            0 ->
                erase(StateKey);
            _ ->
                put(StateKey, Depth - 1)
        end
    end;
generate_one(#gen_string{gen_size = GenSize, gen_char = GenChar}) ->
    unicode:characters_to_binary(generate_one(list_of(GenSize, GenChar)));
generate_one(#gen_tuple{gens = Gens}) ->
    case length(Gens) of
        0 ->
            {};
        _ ->
            Values = lists:map(fun(Gen) -> generate_one(Gen) end, Gens),
            list_to_tuple(Values)
    end;
generate_one(#gen_weighted{max_bound = MaxBound, weighted_gens = WeightedGens}) ->
    Selector = generate_one(integer(1, MaxBound)),
    {value, {_, FoundGen}} =
        lists:search(fun({Bound, _}) -> Selector =< Bound end, WeightedGens),
    generate_one(FoundGen);
generate_one(#mod_flatmap{f = Fun, gen = Gen}) ->
    GenFn = fun() -> Fun(generate_one(Gen)) end,
    generate_one(GenFn());
generate_one(#mod_filter{f = Fun, gen = Gen}) ->
    ValFn =
        fun Go() ->
            Value = generate_one(Gen),
            case Fun(Value) of
                true ->
                    Value;
                false ->
                    Go()
            end
        end,
    ValFn();
generate_one(#mod_map{f = Fun, gen = Gen}) ->
    Fun(generate_one(Gen));
generate_one(_) ->
    throw({badarg, "Argument provided does not appear to be a generator"}).

generate_one_byte(GenByte) ->
    case Byte = generate_one(GenByte) of
        _ when not is_integer(Byte) ->
            throw({badarg, "Byte generator must provide an integer"});
        _ when Byte < 0 orelse Byte > 255 ->
            throw({badarg, "Byte generator must provide an integer between 0 and 255"});
        _ ->
            Byte
    end.

generate_one_size(GenSize) ->
    case Size = generate_one(GenSize) of
        _ when not is_integer(Size) ->
            throw({badarg, "Size generator must provide an integer"});
        _ when Size < 0 ->
            throw({badarg, "Size generator must provide an integer >= 0"});
        _ ->
            Size
    end.

generate_one_map_until_size(MapTrait, GenKey, GenValue, Size) when is_record(MapTrait, map_trait) ->
    generate_one_map_until_size(MapTrait, (MapTrait#map_trait.new)(), GenKey, GenValue, Size).

generate_one_map_until_size(MapTrait, Map, GenKey, GenValue, Size) when is_record(MapTrait, map_trait) ->
    case (MapTrait#map_trait.size)(Map) >= Size of
        true ->
            Map;
        false ->
            Key = generate_one(GenKey),
            case (MapTrait#map_trait.is_key)(Key, Map) of
                true ->
                    generate_one_map_until_size(MapTrait, Map, GenKey, GenValue, Size);
                false ->
                    Value = generate_one(GenValue),
                    UpdatedMap = (MapTrait#map_trait.put)(Key, Value, Map),
                    generate_one_map_until_size(MapTrait, UpdatedMap, GenKey, GenValue, Size)
            end
    end.

generate_one_set_until_size(SetTrait, GenValue, Size) when is_record(SetTrait, set_trait) ->
    generate_one_set_until_size(SetTrait, (SetTrait#set_trait.new)(), GenValue, Size).

generate_one_set_until_size(SetTrait, Set, GenValue, Size) when is_record(SetTrait, set_trait) ->
    case (SetTrait#set_trait.size)(Set) >= Size of
        true ->
            Set;
        false ->
            Value = generate_one(GenValue),
            case (SetTrait#set_trait.is_member)(Value, Set) of
                true ->
                    generate_one_set_until_size(SetTrait, Set, GenValue, Size);
                false ->
                    UpdatedSet = (SetTrait#set_trait.add)(Value, Set),
                    generate_one_set_until_size(SetTrait, UpdatedSet, GenValue, Size)
            end
    end.
