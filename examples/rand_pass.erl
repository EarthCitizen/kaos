-module(rand_pass).

-export([
    pass/1
]).

gen_pass(RequiredLength) ->
    GenSpecialW = {_, GenSpecialC} = kaos:weighted_from_list([
        $!, $@, $#, $$, $%, $^, $&, $*, $(, $), $_, $+, $-, $=
    ]),
    GenUpperW = {_, GenUpperC} = kaos:weighted_from_range($A, $Z),
    GenLowerW = {_, GenLowerC} = kaos:weighted_from_range($a, $z),
    GenNumberW = {_, GenNumberC} = kaos:weighted_from_range($0, $9),
    GenSymbolW = kaos:weighted_from_list([
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
    {ok, Passes} = kaos:generate(gen_pass(RequiredLength), os:system_time(nanosecond), 1),
    io:format("~p~n", Passes).
