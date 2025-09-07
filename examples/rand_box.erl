-module(rand_box).

-export([
    box/0
]).

% Generate a square of box drawing characters.
box() ->
    % The characters to choose from.
    GenChars = kaos:choose([kaos:const(C) || C <- ["╒", "╓", "╔", "╕", "╖", "╗", "╘", "╙", "╚", "╛", "╜", "╝"]]),
    % The width of the square.
    GenWidth = kaos:integer(6, 60),
    % Take the value generated from the width
    % and transform it into a more complex
    % generator.
    GenLines = kaos:flatmap(
        fun (Width) ->
            GenString = kaos:string_of(kaos:const(Width), GenChars),
            GenStrings = lists:duplicate(Width, GenString),
            GenAll = kaos:all(GenStrings),
            kaos:map(
                fun (ListOfStrings) ->
                    lists:join("\n", ListOfStrings)
                end,
                GenAll
            )
        end,
        GenWidth
    ),
    {ok, [Box]} = kaos:generate(GenLines, os:system_time(nanosecond), 1),
    io:format("~ts~n", [Box]).
