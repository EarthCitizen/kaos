-module(rand_expr).

-export([
    expr/1
]).

format_string(Format, Args) -> lists:flatten(io_lib:format(Format, Args)).

gen_expr(MaxDepth) ->
    GenValue = kaos:mod_map(fun (I) -> format_string("~p", [I]) end, kaos:integer(-100, 100)),
    GenOpSymbol = kaos:choose([kaos:const(C) || C <- [$+, $-, $/, $*]]),
    GenExpression =
        fun (GenOperand, GenOperator) ->
            kaos:mod_map(
                fun ([Operand1, Operator, Operand2]) ->
                    format_string("( ~s ~c ~s )", [Operand1, Operator, Operand2])
                end,
                kaos:all([GenOperand, GenOperator, GenOperand])
            )
        end,
    GenExprRecur =
        fun Nest () ->
            kaos:recurse(
                fun (Depth) ->
                    case Depth < MaxDepth of
                        true ->
                            kaos:weighted([
                                {2, GenValue},
                                {3, GenExpression(Nest(), GenOpSymbol)}
                            ]);
                        false ->
                            GenValue
                    end
                end
            )
        end,
    GenExprRecur().

expr(MaxDepth) ->
    {ok, [Expr]} = kaos:generate(gen_expr(MaxDepth), os:system_time(nanosecond), 1),
    io:format("~s~n", [Expr]).
