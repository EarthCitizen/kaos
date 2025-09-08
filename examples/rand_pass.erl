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
        % Use arrays and a set to track previously
        % picked indexes for massive performance boost
        % on large values.
        fun (AllCharsGrouped) ->
            AllChars = lists:flatten(AllCharsGrouped),
            AllCharsArray = array:from_list(AllChars),
            N = array:size(AllCharsArray),
            N_2 = N - 2,
            N_1 = N - 1,
            GenShuffle =
                fun
                    Recur (Choices, I) when I > N_2 ->
                        kaos:const(array:to_list(Choices));
                    Recur (Choices, I) ->
                        kaos:flatmap(
                            fun (J) ->
                                IE = array:get(I, Choices),
                                JE = array:get(J, Choices),
                                Set1 = array:set(I, JE, Choices),
                                Set2 = array:set(J, IE, Set1),
                                Recur(Set2, I + 1)
                            end,
                            kaos:integer(I, N_1)
                        )
                end,
            GenShuffle(AllCharsArray, 0)
        end,
        GenAllChars
    ).

pass(RequiredLength) when is_integer(RequiredLength), RequiredLength >= 6 ->
    {ok, [Passes]} = kaos:generate(gen_pass(RequiredLength), os:system_time(nanosecond), 1),
    io:format("~p~n", [Passes]).
