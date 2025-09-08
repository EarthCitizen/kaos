-module(rand_pass).

-export([
    pass/1
]).

list_to_choose(Elements = [_ | _]) ->
    kaos:choose(lists:map(fun kaos:const/1, Elements)).
list_to_weighted(Elements = [_ | _]) ->
    {length(Elements), list_to_choose(Elements)}.
range_to_weighted(Lower, Upper) when is_integer(Lower), is_integer(Upper), Lower < Upper ->
    {abs(Upper - Lower) + 1, kaos:integer(Lower, Upper)}.

gen_pass(RequiredLength) ->
    GenSpecialW = {_, GenSpecialC} = list_to_weighted([
        $!, $@, $#, $$, $%, $^, $&, $*, $(, $), $_, $+, $-, $=
    ]),
    GenUpperW = {_, GenUpperC} = range_to_weighted($A, $Z),
    GenLowerW = {_, GenLowerC} = range_to_weighted($a, $z),
    GenNumberW = {_, GenNumberC} = range_to_weighted($0, $9),
    GenSymbolW = list_to_weighted([
        $(, $), $_, $+, $-, $=, ${, $}, $[, $], $:, $;, $<, $>, $,, $., $?, $/
    ]),
    GenFiller = kaos:weighted([
        GenSpecialW,
        GenUpperW,
        GenLowerW,
        GenNumberW,
        GenSymbolW
    ]),
    GenAllChars =
        kaos:all([
            % Require 2 special characters
            kaos:list_of(kaos:const(2), GenSpecialC),
            % Require 1 uppercase letter
            kaos:list_of(kaos:const(1), GenUpperC),
            % Require 1 lowercase letter
            kaos:list_of(kaos:const(1), GenLowerC),
            % Require 1 number
            kaos:list_of(kaos:const(1), GenNumberC),
            % Subtract required characters
            kaos:list_of(kaos:const(RequiredLength - 5), GenFiller)
        ]),
    kaos:flatmap(
        fun (AllCharsGrouped) ->
            AllChars = lists:flatten(AllCharsGrouped),
            kaos:shuffle(AllChars)
        end,
        GenAllChars
    ).

pass(RequiredLength) when is_integer(RequiredLength), RequiredLength >= 6 ->
    {ok, Passes} = kaos:generate(gen_pass(RequiredLength), os:system_time(nanosecond), 12),
    io:format("~p~n", Passes).
