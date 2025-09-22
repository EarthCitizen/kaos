-module(kaos_char).

-export([resolve/1]).

resolve(Identifier) ->
    case Identifier of
        {ascii, control} -> [{0, 31}, 127];
        {ascii, whitespace} -> [32, $\f, $\n, $\r, $\t, $\v];
        {ascii, digit} -> {$0, $9};
        {ascii, graphical} -> {33, 126};
        {ascii, printable} -> {32, 126};
        {ascii, alpha} -> [{$A, $Z}, {$a, $z}];
        {ascii, alpha_lower} -> {$a, $z};
        {ascii, alpha_upper} -> {$A, $Z};
        {ascii, hex_lower} -> [{$0, $9}, {$a, $f}];
        {ascii, hex_upper} -> [{$0, $9}, {$A, $F}]
    end
.

% ascii_digit() -> {$0, $9}.
% ascii_lower() -> {$a, $z}.
% ascii_upper() -> {$A, $Z}.
% ascii_hex_lower() -> [{$0, $9}, {$a, $f}].
% ascii_hex_upper() -> [{$0, $9}, {$A, $F}].
