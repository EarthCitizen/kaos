-module(go).

-compile(export_all).

test() ->
    GenInt = kaos:integer(1, 100),
    GenTup = kaos:flatmap(fun (N) -> kaos:tuple_of([kaos:const(N), kaos:integer(N + 1, N + 12)]) end, GenInt),
    GenOne = kaos:choose([GenInt, GenTup]),
    {ok, GL} = kaos:generate(GenOne, os:system_time(), 24),
    % GL = [25,28,12,{7,18},17,41,29,{1,7},{4,8},{19,24},{29,35},{8,12}],
    % GL = [{25,35},1,{3,15},2,{32,36},43,{29,32},28,{8,9},38,43,{8,17}],
    SL = lists:sort(fun sort/2, GL),
    ML = lists:reverse(lists:foldl(fun folder/2, [], SL)),
    io:format("G: ~p~n", [GL]),
    io:format("S: ~p~n", [SL]),
    io:format("M: ~p~n", [ML]).

% NOT WORKING
% G: [25,28,12,{7,18},17,41,29,{1,7},{4,8},{19,24},{29,35},{8,12}]
% S: [{1,7},{4,8},{8,12},17,{7,18},12,{19,24},25,28,29,{29,35},41]
% M: [{1,12},{7,25},{28,35},41]
%
% WRONg
% G: [{25,35},1,{3,15},2,{32,36},43,{29,32},28,{8,9},38,43,{8,17}]
% S: [1,2,{8,9},{3,15},{8,17},28,{29,32},{25,35},{32,36},38,43,43]
% M: [{1,2},{8,17},{28,36},38,43]

sort({A, _}, {X, _}) when A < X -> true;
sort({A, B}, {X, Y}) -> A =:= X andalso B =< Y;
sort(A, {X, _}) -> A =< X;
sort({A, _}, X) -> A =< X;
sort(A, X) -> A =< X.

merge({A, B}, {X, Y}) when (X-B) =:= 1 -> {A, Y};
merge({A, B}, {X, Y}) when B >= X -> {A, max(B, Y)};
merge(Left = {_, _}, Right = {_, _}) -> [Left, Right];
%
merge(A, {X, Y}) when (X-A) =:= 1 -> {A, Y};
merge(A, Range = {X, Y}) when A >= X andalso A =< Y -> Range;
merge(A, Range = {_, _}) -> [A, Range];
%
merge({A, B}, X) when (X-B) =:= 1 -> {A, X};
merge(Range = {A, B}, X) when X >= A andalso X =< B -> Range;
merge(Range = {_, _}, X) -> [Range, X];
%
merge(A, X) when A =:= X -> X;
merge(A, X) when (X - A) =:= 1 -> {A, X};
merge(A, X) -> [A, X].

% lists:foldl(Fun, Acc0, List)

folder(E, []) -> [E];
folder(E, All = [V | Tail]) ->
    M = merge(V, E),
    io:format("MERGING: E=~p V=~p to M=~p Tail=~p All=~p~n", [E, V, M, Tail, All]),
    case M of
        [L, R] -> [R, L | Tail];
        M -> [M | Tail]
    end.
