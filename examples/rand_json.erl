-module(rand_json).

-export([
    json/1
]).

% Generate a JSON data structure which is less likely
% to keep growing as the nesting becomes deeper.
% The curve is tamed a bit to prevent it from
% exploding too quickly.
gen_json(MaxDepth) when is_integer(MaxDepth), MaxDepth >= 0 ->
    GenNestSize = kaos:integer(1, 4),
    GenFloat = kaos:float(-12.0, 12.0),
    GenInteger = kaos:integer(-12, 12),
    GenString = kaos:string_of(kaos:integer(1, 12), kaos:integer($a, $z)),
    GenPrimitive = kaos:choose([
        kaos:boolean(),
        GenFloat,
        GenInteger,
        GenString
    ]),
    CreateGenJson = fun Nest () ->
        % First depth will be zero.
        kaos:recurse(fun (Depth) ->
            case Depth < MaxDepth of
                true ->
                    % These weights are not scientific.
                    % Just trial and error to tame the curve a bit.
                    % Speeds up performance on large structures.
                    PrimitiveWeight = trunc((Depth + 1) * 1.75),
                    NestedWeight = max(1, trunc((MaxDepth - Depth) * 0.45)),
                    kaos:weighted([
                        {
                            PrimitiveWeight,
                            GenPrimitive
                        },
                        {
                            NestedWeight,
                            kaos:choose([
                                kaos:list_of(GenNestSize, Nest()),
                                kaos:map_of(GenNestSize, GenString, Nest())
                            ])
                        }
                    ]);
                false ->
                    GenPrimitive
            end
        end)
    end,
    CreateGenJson().

% Generates new JSON for every unique nanosecond.
% Nesting will not go beyond MaxDepth.
json(MaxDepth) when is_integer(MaxDepth), MaxDepth >= 0 ->
    {ok, [Json]} = kaos:generate(gen_json(MaxDepth), os:system_time(nanosecond), 1),
    io:format("~ts~n", [json:format(Json)]).
