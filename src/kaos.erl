-module(kaos).

-moduledoc """
Kaos is a small, composable generator library for Erlang. It provides building
blocks (generators) to produce random but controlled data and execution
functions to realize those generators deterministically.

## Core ideas

- Everything you build is a `gen()` value. Use combinators such as
  `const/1`, `integer/2`, `float/2`, `boolean/0`, `choose/1`, `weighted/1`,
  `list_of/2`, `tuple_of/1`, `map_of/3`, `dict_of/3`, `set_of/2`,
  `gb_tree_of/3`, `gb_set_of/2`, `string_of/2`, `binary_of/2`,
  `bitstring_of/2`, `shuffle/1`, and composition helpers `map/2`,
  `filter/2`, `flatmap/2`, `recurse/1`, `cycle/1`, `iterate/1`.
- Deterministic generation: `generate/3` and `generate/4` (with timeout) use
  a seed so the same seed and generator produce the same samples.
- Streaming-friendly: `generate_into/5` and `generate_into/6` fold each
  sample into a caller-supplied accumulator, avoiding materializing large
  intermediate lists when you do not need them.

## Execution APIs

- `{ok, Samples} = generate(Gen, Seed, Count)` returns a list of values.
- `{ok, Acc} = generate_into(Gen, Seed, Count, MergeFun, Acc)` returns a
  folded accumulator; the `/6` variant lets you pass a custom timeout. Both
  run generation in a linked worker and return `{error, Reason}` tuples on
  failure or `{error, timeout}` if the worker exceeds the deadline.

## Typical use cases

- Property testing and fuzzing: build diverse, reproducible inputs for unit
  or property tests without committing to a particular testing framework.
- Test fixtures and sample content: quickly synthesize realistic maps,
  lists, strings, binaries or trees for demos and benchmarks.
- Distribution shaping: pick values with `weighted/1` to approximate
  real-world frequency mixes in load tests.
- Large-output workflows: use `generate_into/5` to stream into sets or maps,
  running statistics, top-K structures, iolists, files, ETS, or external
  sinks without building a huge list in memory.
- Recursive/structured data: `recurse/1` and `iterate/1` help construct nested
  terms and controlled growth processes.

## Notes

- Deterministic seeding
  - Uses `rand:seed(exsss, Seed)`. Same OTP version + same `Seed` + same `Gen`
    yield the same samples. Across OTP versions, streams may differ.

- Worker + timeout semantics
  - Generation runs in a linked worker process with a default 30s timeout.
    Use `generate/4` or `generate_into/6` to increase the timeout for slow
    merges, narrow domains (lots of resampling), or deeper recursion.

- Memory vs streaming
  - `generate/3` materializes a list of `Count` elements in memory. Prefer
    `generate_into/5` to stream into sets/maps/files when `Count` is large.

- Resampling for uniqueness
  - Set and map/tree generators skip duplicates and resample. If the element or
    key domain is too narrow for the requested size, generation can take a long
    time or time out. Widen the domain or reduce the size.

- Error shapes
  - Many constructors validate inputs and will fail with
    `{error, {badarg, "..."}, _}` (or a related error), for example:
    - Size: `"Size generator must provide an integer >= 0"`
    - Byte: `"Byte generator must provide an integer between 0 and 255"`
    - Bit: `"Bit generator must produce 0 or 1"`
    - String codepoints: `unicode:characters_to_binary/1` may raise `badarg`

- Side effects run in the worker
  - `map/2`, `flatmap/2`, `filter/2`, and merge functions execute in the worker
    process. Ensure any side effects or external resources are safe to use
    from that process.

- Process-local state isolation
  - `cycle/1`, `iterate/1`, and `recurse/1` keep state in the process
    dictionary. Each `generate*` call uses its own worker, so runs are
    isolated and concurrent calls do not interfere.

- Weighted and uniform selection
  - `choose/1` selects uniformly among generators. `weighted/1` uses integer
    weights normalized by their GCD and selects proportionally; small samples
    can deviate from long-run ratios.

## Examples

### Hex Color Codes (#RRGGBB)

```erlang
1> Byte   = kaos:byte().
2> Hex2   = kaos:map(fun(B) -> io_lib:format("~2.16.0B", [B]) end, Byte).
3> Color  = kaos:map(fun({R,G,B}) -> lists:flatten([$#, R, G, B]) end,
3>                  kaos:tuple_of([Hex2, Hex2, Hex2]) ).
4> Gen    = Color.
5> {ok, Colors} = kaos:generate(Gen, 909, 3).
6> Colors.
["#2AE5E8","#2CC2EA","#F54938"]
```

### Dates (Month Day, Year)

```erlang
1> Year  = kaos:integer(2020, 2027).
2> Month = kaos:integer(1, 12).
3> Base  = kaos:tuple_of([Year, Month]).
4> Gen   = kaos:flatmap(
4>           fun({Y,M}) ->
4>             {Name,Days} = case M of
4>               1 -> {"January",31};  2 -> {"February",28}; 3 -> {"March",31};
4>               4 -> {"April",30};    5 -> {"May",31};      6 -> {"June",30};
4>               7 -> {"July",31};     8 -> {"August",31};    9 -> {"September",30};
4>              10 -> {"October",31}; 11 -> {"November",30}; 12 -> {"December",31}
4>             end,
4>             Leap = ((Y rem 400) =:= 0) orelse (((Y rem 4) =:= 0) andalso ((Y rem 100) =/= 0)),
4>             Max = case {M,Leap} of {2,true} -> 29; _ -> Days end,
4>             kaos:map(fun(D) -> lists:flatten(io_lib:format("~s ~B, ~B", [Name, D, Y])) end,
4>                      kaos:integer(1, Max))
4>           end,
4>           Base).
5> {ok, Dates} = kaos:generate(Gen, 909, 3).
6> Dates.
["June 15, 2022","November 15, 2024","February 1, 2025"]
```

### URLs

```erlang
1> Label  = kaos:string_of(kaos:integer(3, 8), kaos:integer($a, $z)).
2> TLD    = kaos:choose([kaos:const("com"), kaos:const("edu"), kaos:const("net"), kaos:const("io")]).
3> Host   = kaos:tuple_of([Label, Label, TLD]).
4> Path   = kaos:list_of(kaos:integer(1, 4), Label).
5> Scheme = kaos:choose([kaos:const("http"), kaos:const("https")]).
6> Base   = kaos:tuple_of([Scheme, Host, Path]).
7> Gen    = kaos:map(fun({Sc,{A,B,Tld},Segs}) ->
7>                     lists:flatten(io_lib:format("~s://~s.~s.~s/~s",
7>                       [Sc,
7>                        binary_to_list(A), binary_to_list(B), Tld,
7>                        string:join([binary_to_list(S) || S <- Segs], "/")]))
7>                   end,
7>                   Base).
8> {ok, Urls} = kaos:generate(Gen, 909, 3).
9> Urls.
["http://swqclnwb.eaeaokov.edu/cia/zzwhj/sie/gbx",
 "http://cozh.cikojsk.io/pqrbz/piqcu/qjf/uroqkra",
"http://qaf.ngdusuwj.net/teeswqx"]
```

### Email Address

```erlang
1> Label  = kaos:string_of(kaos:integer(3, 10), kaos:integer($a, $z)).
2> Local  = Label.
3> Dom    = kaos:tuple_of([Label, Label]).
4> TLD    = kaos:choose([kaos:const("com"), kaos:const("edu"), kaos:const("net"), kaos:const("io")]).
5> Base   = kaos:tuple_of([Local, Dom, TLD]).
6> Gen    = kaos:map(fun({L,{D1,D2},Tld}) ->
6>                     lists:flatten(io_lib:format("~s@~s.~s.~s",
6>                       [binary_to_list(L), binary_to_list(D1), binary_to_list(D2), Tld]))
6>                   end,
6>                   Base).
7> {ok, Emails} = kaos:generate(Gen, 909, 3).
8> Emails.
["dswqc@nwbleaea.kovnjqcia.net","zwhjgsie@gbxqb.ozhec.net",
 "ojskrrc@qrbzipiq.uaqjf.net"]
```

### JWTs

```erlang
1> Label  = kaos:string_of(kaos:integer(3, 10), kaos:integer($a, $z)).
2> Iat    = kaos:integer(1700000000, 1800000000).
3> Base   = kaos:tuple_of([Label, Label, Iat]).  % {sub, aud, iat}
4> B64URL = fun(Bin) ->
4>            Str = base64:encode_to_string(Bin),
4>            S1 = string:replace(Str, "+", "-", all),
4>            S2 = string:replace(S1, "/", "_", all),
4>            string:replace(S2, "=", "", all)
4>          end.
5> Gen    = kaos:map(fun({Sub, Aud, I}) ->
5>                     HeaderBin  = list_to_binary("{\"alg\":\"HS256\",\"typ\":\"JWT\"}"),
5>                     PayloadBin = iolist_to_binary(
5>                       io_lib:format("{\"sub\":\"~s\",\"aud\":\"~s\",\"iat\":~b}",
5>                                     [binary_to_list(Sub), binary_to_list(Aud), I])),
5>                     H64 = B64URL(HeaderBin),
5>                     P64 = B64URL(PayloadBin),
5>                     Data = H64 ++ "." ++ P64,
5>                     Sig = crypto:mac(hmac, sha256, "secret", Data),
5>                     S64 = B64URL(Sig),
5>                     lists:flatten(io_lib:format("~s.~s.~s", [H64, P64, S64]))
5>                   end,
5>                   Base).
6> {ok, Tokens} = kaos:generate(Gen, 909, 3).
7> Tokens.
["eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJkc3dxYyIsImF1ZCI6Im53YmxlYWVhIiwiaWF0IjoxNzk2NDM1NzkzfQ.byAv0IXjYP-DOv4dbxZT6D2CUv2kGoqcu8ezHaQ3Brs",
 "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJvdm4iLCJhdWQiOiJxY2lhd3p6d2hqIiwiaWF0IjoxNzUwOTIyNTQxfQ.7LSHE_fPVWLCk7d4bCUWCWO4qrXazrmTpIF28PRgYfM",
 "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJpZWdnYnhxIiwiYXVkIjoiY296aCIsImlhdCI6MTc1NDY0NDg3MX0.vIzHpm3o1NdDmRj8FXKDP8TY2raG2Dcf1vheFmzo9lk"]
```

### Phone Numbers (US format)

```erlang
1> Dn    = kaos:integer(2, 9).    % leading digit N=2..9
2> Dx    = kaos:integer(0, 9).    % other digits 0..9
3> Area  = kaos:tuple_of([Dn, Dx, Dx]).
4> Exch  = kaos:tuple_of([Dn, Dx, Dx]).
5> Line  = kaos:tuple_of([Dx, Dx, Dx, Dx]).
6> Base  = kaos:tuple_of([Area, Exch, Line]).
7> Gen   = kaos:map(fun({{A1,A2,A3},{E1,E2,E3},{L1,L2,L3,L4}}) ->
7>                    lists:flatten(io_lib:format("(~B~B~B) ~B~B~B-~B~B~B~B",
7>                      [A1,A2,A3,E1,E2,E3,L1,L2,L3,L4]))
7>                  end,
7>                  Base).
8> {ok, Phones} = kaos:generate(Gen, 909, 3).
9> Phones.
["(414) 664-3345","(748) 468-0251","(980) 608-5343"]
```
""".

-export([
    all/1,
    array_of/2,
    ascii_char/0,
    binary_of/2,
    bit/0,
    bitstring_of/2,
    boolean/0,
    byte/0,
    choose/1,
    const/1,
    cycle/1,
    dict_of/3,
    filter/2,
    flatmap/2,
    float/2,
    gb_set_of/2,
    gb_tree_of/3,
    integer/2,
    iterate/1,
    list_of/2,
    map/2,
    map_of/3,
    orddict_of/3,
    ordset_of/2,
    recurse/1,
    set_of/2,
    shuffle/1,
    string_of/2,
    tuple_of/1,
    weighted/1,
    generate/3,
    generate/4,
    generate_into/5,
    generate_into/6
]).

-export_type([
    depth_function/0,
    flatmap_function/0,
    gen/0,
    generate_error_response/0,
    generate_response/0,
    generate_into_function/1,
    generate_into_response/1,
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
    size :: fun((term()) -> non_neg_integer()),
    is_member :: fun((term(), term()) -> boolean()),
    add :: fun((term(), term()) -> term())
}).

-doc """
List type requiring at least two `gen()` values. Used by functions like
`all/1`, `choose/1`, `cycle/1`, and `weighted/1` to express that at least two
generators must be provided.
""".
-type nonunary_list() :: [gen() | nonempty_list(gen())].
-doc """
Function type used by `recurse/1`. Receives a depth counter (starting at 0) and
must return a `gen()` to continue generation at that depth.
""".
-type depth_function() :: fun((non_neg_integer()) -> gen()).
-doc """
Function type used by `flatmap/2`. Transforms a sampled value into another
`gen()` which is then sampled (monadic bind).
""".
-type flatmap_function() :: fun((term()) -> gen()).
-doc """
Error return shapes produced by generation functions on failures (bad arguments,
timeouts, or exceptions in user functions).
""".
-type generate_error_response() :: {error, {badarg, string()}, erlang:stacktrace()}
    | {error, timeout}
    | {error, term(), erlang:stacktrace()}
    | {error, term()}.
-doc """
Success or error shape returned by `generate/3,4`. On success, contains the list
of samples; otherwise one of the error variants.
""".
-type generate_response() :: {ok, list(term())} | generate_error_response().
-doc """
Merge/fold function type used by `generate_into/5,6`. Takes a sampled value and
an accumulator, and returns the updated accumulator.
""".
-type generate_into_function(T) :: fun((term(), T) -> T).
-doc """
Success or error shape returned by `generate_into/5,6`. On success, contains the
final accumulator; otherwise one of the error variants.
""".
-type generate_into_response(T) :: {ok, T} | generate_error_response().
-doc """
Function type used by `iterate/1`. Receives a positive position (1..N) and the
previous term (opaque to kaos) and must return a `gen()` for the next value.
""".
-type iterate_function() :: fun((pos_integer(), term()) -> gen()).
-doc """
Function type used by `map/2` to transform each sampled value.
""".
-type map_function() :: fun((term()) -> term()).
-doc """
Predicate function type used by `filter/2`. Return `true` to accept, `false` to
resample.
""".
-type predicate_function() :: fun((term()) -> boolean()).
-doc """
Weighted generator pair used by `weighted/1`: a positive integer weight and the
generator to select with that weight.
""".
-type weighted_gen() :: {pos_integer(), gen()}.

-record(gen_all, {gens :: nonempty_list(gen())}).
-record(gen_binary, {gen_size :: gen(), gen_byte :: gen()}).
-record(gen_bitstring, {gen_size :: gen(), gen_bit :: gen()}).
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
-record(gen_shuffle, {list :: list()}).
-record(gen_string, {gen_size :: gen(), gen_char :: gen()}).
-record(gen_tuple, {gens :: list(gen())}).
-record(gen_weighted, {max_bound :: pos_integer(), weighted_gens :: nonempty_list(weighted_gen())}).
-record(mod_filter, {f :: predicate_function(), gen :: gen()}).
-record(mod_flatmap, {f :: flatmap_function(), gen :: gen()}).
-record(mod_map, {f :: map_function(), gen :: gen()}).

-doc """
Opaque generator type used throughout the library. Values of this type are built
via the provided combinators and consumed by `generate*` functions.
""".
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
    | #gen_shuffle{}
    | #gen_string{}
    | #gen_tuple{}
    | #gen_weighted{}
    | #mod_filter{}
    | #mod_flatmap{}
    | #mod_map{}
    .

-doc """
Returns a generator that produces a list containing one sample from each generator, in order.

#### Parameters

- `Gens` — list with >= 2 `gen()` values; each is sampled once per output; each produced list has length `length(Gens)`.

#### Example

```erlang
1> Gen = kaos:all([kaos:const(100), kaos:const(200)]).
2> {ok, Samples} = kaos:generate(Gen, 1000, 3).
3> Samples.
[[100,200],[100,200],[100,200]]
```
""".
-spec all(nonunary_list()) -> gen().
all(Gens = [_, _ | _]) -> #gen_all{gens = Gens}.

-doc """
Returns a generator that produces an Erlang `array()` whose size is generated by `GenSize`
and whose elements are generated by `GenValue`.

#### Parameters

- `GenSize` — generator of non-negative integers (>= 0); determines the array
  length. If it yields an invalid value, generation fails with {error,
  {badarg, "Size generator must provide an integer >= 0"}, _}.
- `GenValue` — generator of element values; sampled once per index from 0..Size-1.

#### Example

```erlang
1> Gen = kaos:array_of(kaos:const(3), kaos:const(42)).
2> {ok, [Arr]} = kaos:generate(Gen, 1001, 1).
3> array:to_list(Arr).
[42,42,42]
```
""".
-spec array_of(gen(), gen()) -> gen().
array_of(GenSize, GenValue) ->
    map(fun array:from_list/1, list_of(GenSize, GenValue)).

-spec ascii_char() -> gen().
ascii_char() -> integer(33, 126).

-doc """
Returns a generator that produces a `binary()` whose size is generated by `GenSize`
and whose bytes are generated by `GenByte`.

#### Parameters

- `GenSize` — generator of non-negative integers (>= 0); determines the number
  of bytes. If it yields an invalid value, generation fails with {error,
  {badarg, "Size generator must provide an integer >= 0"}, _}.
- `GenByte` — generator of integers in the range 0..255; sampled once per
  byte. If it yields an invalid value, generation fails with {error,
  {badarg, "Byte generator must provide an integer between 0 and 255"}, _}.

#### Example

```erlang
1> Gen = kaos:binary_of(kaos:const(3), kaos:const(16)).
2> {ok, [Bin]} = kaos:generate(Gen, 909, 1).
3> binary:bin_to_list(Bin).
[16,16,16]
```
""".
-spec binary_of(gen(), gen()) -> gen().
binary_of(GenSize, GenByte) -> #gen_binary{gen_size = GenSize, gen_byte = GenByte}.

-doc """
Returns a generator that produces a single bit, i.e. an integer `0` or `1`.

#### Example

```erlang
1> Gen = kaos:bit().
2> {ok, Bits} = kaos:generate(Gen, 909, 8).
3> Bits.
[0,1,0,0,0,0,1,1]
```
""".
-spec bit() -> gen().
bit() -> choose([const(0), const(1)]).

-doc """
Returns a generator that produces a bitstring whose size is generated by `GenSize`
and whose bits are generated by `GenBit` (each bit must be `0` or `1`).

#### Parameters

- `GenSize` — generator of non-negative integers (>= 0); determines the number
  of bits. If it yields an invalid value, generation fails with {error,
  {badarg, "Size generator must provide an integer >= 0"}, _}.
- `GenBit` — generator that yields only `0` or `1`; sampled once per bit. If it
  yields an invalid value, generation fails with {error, {badarg,
  "Bit generator must produce 0 or 1"}, _}.

#### Example

```erlang
1> Gen = kaos:bitstring_of(kaos:const(5), kaos:bit()).
2> {ok, [Bits]} = kaos:generate(Gen, 909, 1).
3> {bit_size(Bits), Bits}.
{5, <<8:5>>}
```
""".
-spec bitstring_of(gen(), gen()) -> gen().
bitstring_of(GenSize, GenBit) -> #gen_bitstring{gen_size = GenSize, gen_bit = GenBit}.

-doc """
Returns a generator that produces a boolean: `true` or `false`.

#### Example

```erlang
1> Gen = kaos:boolean().
2> {ok, Bools} = kaos:generate(Gen, 303, 8).
3> Bools.
[false,true,true,false,false,true,false,true]
```
""".
 -spec boolean() -> gen().
boolean() -> choose([const(true), const(false)]).

-doc """
Returns a generator that produces a byte, i.e. an integer in the range `0..255`.

#### Example

```erlang
1> Gen = kaos:byte().
2> {ok, Bytes} = kaos:generate(Gen, 909, 4).
3> Bytes.
[42,229,232,44]
```
""".
 -spec byte() -> gen().
byte() -> integer(0, 255).

-doc """
Returns a generator that randomly selects one of the generators in `Gens` and
produces a sample from it each time.

#### Parameters

- `Gens` — list with at least two `gen()` values; one is chosen uniformly per sample.

#### Example

```erlang
1> Gen = kaos:choose([kaos:const(1), kaos:const(ok), kaos:const("abc")]).
2> {ok, Values} = kaos:generate(Gen, 909, 9).
3> Values.
["abc","abc","abc",ok,ok,"abc",1,ok,"abc"]
```
""".
 -spec choose(nonunary_list()) -> gen().
choose(Gens = [_, _ | _]) when length(Gens) > 1 -> #gen_choose{gens = Gens}.

-doc """
Returns a generator that always produces the given value `A`.

#### Parameters

- `A` — any Erlang term to be returned as-is on every sample.

#### Example

```erlang
1> Gen = kaos:const(ready).
2> {ok, Values} = kaos:generate(Gen, 909, 3).
3> Values.
[ready,ready,ready]
```
""".
 -spec const(term()) -> gen().
const(A) -> #gen_const{value = A}.

-doc """
Returns a generator that cycles through the generators in `Gens`, taking one
sample from the next generator each time, and wrapping to the start.

#### Parameters

- `Gens` — list with >= 2 `gen()` values; cycled in order for each sample.

#### Example

```erlang
1> Gen = kaos:cycle([kaos:const(1), kaos:const(true), kaos:const("abc")]).
2> {ok, Values} = kaos:generate(Gen, 505, 7).
3> Values.
[1,true,"abc",1,true,"abc",1]
```
""".
-spec cycle(nonunary_list()) -> gen().
cycle(Gens = [_, _ | _]) -> #gen_cycle{id = make_ref(), gens = Gens}.

-doc """
Returns a generator that produces a `dict()` with size generated by `GenSize` and
keys/values generated by `GenKey`/`GenValue`. Duplicate keys are skipped until the
target size is reached.

#### Parameters

- `GenSize` — generator of non-negative integers (>= 0); determines number of
  entries. If it yields an invalid value, generation fails with {error,
  {badarg, "Size generator must provide an integer >= 0"}, _}.
- `GenKey` — generator for keys; should produce enough unique keys to reach size.
- `GenValue` — generator for values; sampled once per unique key.

#### Example

```erlang
1> Gen = kaos:dict_of(kaos:const(3), kaos:integer(1,100), kaos:const(ready)).
2> {ok, [D]} = kaos:generate(Gen, 909, 1).
3> dict:to_list(D).
[{25,ready},{63,ready},{42,ready}]
```
""".
-spec dict_of(gen(), gen(), gen()) -> gen().
dict_of(GenSize, GenKey, GenValue) -> #gen_dict{gen_size = GenSize, gen_key = GenKey, gen_value = GenValue}.

-doc """
Returns a generator that filters values from `Gen` using predicate `Fun/1`,
resampling until `Fun(Value)` returns `true`.

#### Parameters

- `Fun` — unary predicate; return `true` to accept a value.
- `Gen` — source generator to sample from.

> Note: If the predicate rarely or never accepts values, generation may take a
> long time or time out. Consider widening `Gen` or relaxing the predicate to
> ensure progress.

#### Example

```erlang
1> Even = fun(N) -> (N rem 2) =:= 0 end.
2> Gen = kaos:filter(Even, kaos:integer(1,10)).
3> {ok, Values} = kaos:generate(Gen, 1212, 6).
4> Values.
[4,6,10,10,2,10]
```
""".
-spec filter(predicate_function(), gen()) -> gen().
filter(Fun, Gen) when is_function(Fun, 1) -> #mod_filter{f = Fun, gen = Gen}.

-doc """
Returns a generator that maps each value from `Gen` through `Fun/1` to a new
generator, and samples from that generator (monadic bind).

#### Parameters

- `Fun` — unary function returning a `gen()` for a given value.
- `Gen` — source generator whose values are transformed.

#### Example

```erlang
1> F = fun(S) -> kaos:list_of(kaos:const(S), kaos:const(ready)) end.
2> Gen = kaos:flatmap(F, kaos:const(3)).
3> {ok, Values} = kaos:generate(Gen, 999, 3).
4> Values.
[[ready,ready,ready],[ready,ready,ready],[ready,ready,ready]]
```
""".
-spec flatmap(flatmap_function(), gen()) -> gen().
flatmap(Fun, Gen) when is_function(Fun, 1) -> #mod_flatmap{f = Fun, gen = Gen}.

-doc """
Returns a generator that produces a floating-point number in the open interval
`(MinBound, MaxBound)`, with `MinBound < MaxBound`.

#### Parameters

- `MinBound` — lower bound (float); must be less than `MaxBound`.
- `MaxBound` — upper bound (float); must be greater than `MinBound`.

#### Example

```erlang
1> Gen = kaos:float(1.5, 2.5).
2> {ok, Values} = kaos:generate(Gen, 101, 3).
3> Values.
[1.9373364319283917,1.9752916097381772,1.7695279988967685]
```
""".
-spec float(float(), float()) -> gen().
float(MinBound, MaxBound)
    when is_float(MinBound), is_float(MaxBound), MinBound < MaxBound ->
    #gen_float{min_bound = MinBound, max_bound = MaxBound}.

-doc """
Returns a generator that produces a `gb_set()` with size generated by `GenSize`
and elements generated by `GenValue`. Duplicate elements are skipped until the
target size is reached.

#### Parameters

- `GenSize` — generator of non-negative integers (>= 0); determines set
  cardinality. If it yields an invalid value, generation fails with {error,
  {badarg, "Size generator must provide an integer >= 0"}, _}.
- `GenValue` — generator for set elements; should produce enough unique
  elements to reach size. Duplicates are skipped; a narrow domain may increase
  generation time or cause timeouts.

#### Example

```erlang
1> Gen = kaos:gb_set_of(kaos:const(3), kaos:integer(1,100)).
2> {ok, [S]} = kaos:generate(Gen, 909, 1).
3> gb_sets:to_list(S).
[25,42,63]
```
""".
-spec gb_set_of(gen(), gen()) -> gen().
gb_set_of(GenSize, GenValue) -> #gen_gb_set{gen_size = GenSize, gen_value = GenValue}.

-doc """
Returns a generator that produces a `gb_tree()` (balanced tree map) with size
generated by `GenSize` and keys/values generated by `GenKey`/`GenValue`.
Duplicate keys are skipped until the target size is reached.

#### Parameters

- `GenSize` — generator of non-negative integers (>= 0); determines number of
  entries. If it yields an invalid value, generation fails with {error,
  {badarg, "Size generator must provide an integer >= 0"}, _}.
- `GenKey` — generator for keys; should provide enough unique keys to reach
  size. Duplicates are skipped; a narrow key domain may increase generation
  time or cause timeouts.
- `GenKey` — generator for keys; should provide enough unique keys to reach
  size. Duplicates are skipped; a narrow key domain may increase generation
  time or cause timeouts.
- `GenValue` — generator for values; sampled once per unique key.

#### Example

```erlang
1> Gen = kaos:gb_tree_of(kaos:const(3), kaos:integer(1,100), kaos:const(ready)).
2> {ok, [T]} = kaos:generate(Gen, 909, 1).
3> gb_trees:to_list(T).
[{25,ready},{42,ready},{63,ready}]
```
""".
-spec gb_tree_of(gen(), gen(), gen()) -> gen().
gb_tree_of(GenSize, GenKey, GenValue) -> #gen_gb_tree{gen_size = GenSize, gen_key = GenKey, gen_value = GenValue}.

-doc """
Returns a generator that produces integers in the inclusive range
`MinBound..MaxBound`, with `MinBound < MaxBound`.

#### Parameters

- `MinBound` — lower bound (integer), strictly less than `MaxBound`.
- `MaxBound` — upper bound (integer), strictly greater than `MinBound`.

#### Example

```erlang
1> Gen = kaos:integer(1, 10).
2> {ok, Values} = kaos:generate(Gen, 707, 5).
3> Values.
[1,6,10,7,6]
```
""".
-spec integer(integer(), integer()) -> gen().
integer(MinBound, MaxBound)
    when is_integer(MinBound), is_integer(MaxBound), MinBound < MaxBound ->
    #gen_integer{min_bound = MinBound, max_bound = MaxBound}.

-spec iterate(iterate_function()) -> gen().
iterate(Fun) when is_function(Fun, 2) -> #gen_iterate{id = make_ref(), f = Fun}.

-doc """
Returns a generator that produces a list whose length is generated by `GenSize`
and whose elements are generated by `GenValue`.

#### Parameters

- `GenSize` — generator of non-negative integers (>= 0); determines list
  length. If it yields an invalid value, generation fails with {error,
  {badarg, "Size generator must provide an integer >= 0"}, _}.
- `GenValue` — generator for each element.

#### Example

```erlang
1> Gen = kaos:list_of(kaos:const(3), kaos:const(ready)).
2> {ok, [L]} = kaos:generate(Gen, 9, 1).
3> L.
[ready,ready,ready]
```
""".
-spec list_of(gen(), gen()) -> gen().
list_of(GenSize, GenValue) -> #gen_list{gen_size = GenSize, gen_value = GenValue}.

-doc """
Returns a generator that produces a `map()` with size generated by `GenSize` and
keys/values generated by `GenKey`/`GenValue`. Duplicate keys are skipped until the
target size is reached.

#### Parameters

- `GenSize` — generator of non-negative integers (>= 0); number of entries. If
  it yields an invalid value, generation fails with {error, {badarg, "Size
  generator must provide an integer >= 0"}, _}.
- `GenKey` — generator for keys; should provide enough unique keys to reach
  size. Duplicates are skipped; a narrow key domain may increase generation
  time or cause timeouts.
- `GenValue` — generator for values; sampled once per unique key.

#### Example

```erlang
1> Gen = kaos:map_of(kaos:const(3), kaos:integer(1,100), kaos:const(ready)).
2> {ok, [M]} = kaos:generate(Gen, 909, 1).
3> maps:to_list(M).
[{25,ready},{42,ready},{63,ready}]
```
""".
-spec map_of(gen(), gen(), gen()) -> gen().
map_of(GenSize, GenKey, GenValue) -> #gen_map{gen_size = GenSize, gen_key = GenKey, gen_value = GenValue}.

-doc """
Returns a generator that produces an `orddict()` (sorted list of `{Key,Val}`)
with size generated by `GenSize` and keys/values generated by `GenKey`/`GenValue`.
Duplicate keys are skipped until the target size is reached.

#### Parameters

- `GenSize` — generator of non-negative integers (>= 0); number of entries. If
  it yields an invalid value, generation fails with {error, {badarg, "Size
  generator must provide an integer >= 0"}, _}.
- `GenKey` — generator for keys; should provide enough unique keys to reach
  size. Duplicates are skipped; a narrow key domain may increase generation
  time or cause timeouts.
- `GenValue` — generator for values; sampled once per unique key.

#### Example

```erlang
1> Gen = kaos:orddict_of(kaos:const(3), kaos:integer(1,100), kaos:const(ready)).
2> {ok, [OD]} = kaos:generate(Gen, 909, 1).
3> orddict:to_list(OD).
[{25,ready},{42,ready},{63,ready}]
```
""".
-spec orddict_of(gen(), gen(), gen()) -> gen().
orddict_of(GenSize, GenKey, GenValue) -> #gen_orddict{gen_size = GenSize, gen_key = GenKey, gen_value = GenValue}.

-doc """
Returns a generator that produces an `ordset()` (sorted set) with size generated
by `GenSize` and elements generated by `GenValue`. Duplicate elements are
skipped until the target size is reached.

#### Parameters

- `GenSize` — generator of non-negative integers (>= 0); determines set
  cardinality. If it yields an invalid value, generation fails with {error,
  {badarg, "Size generator must provide an integer >= 0"}, _}.
- `GenValue` — generator for set elements; should produce enough unique
  elements to reach size. Duplicates are skipped; a narrow domain may increase
  generation time or cause timeouts.

#### Example

```erlang
1> Gen = kaos:ordset_of(kaos:const(3), kaos:integer(1,100)).
2> {ok, [S]} = kaos:generate(Gen, 909, 1).
3> ordsets:to_list(S).
[25,42,63]
```
""".
-spec ordset_of(gen(), gen()) -> gen().
ordset_of(GenSize, GenValue) -> #gen_ordset{gen_size = GenSize, gen_value = GenValue}.

-doc """
Returns a generator that delegates to `Fun/1` with a depth counter to help
build recursive structures without unbounded growth. Within `Fun`, you may
return `kaos:recurse(Fun)` to go one level deeper, or any other generator to
terminate.

#### Parameters

- `Fun` — `fun(Depth) -> gen()`; `Depth` starts at 0 and increases when you
  return `recurse(Fun)`.

> Note: Always include a termination condition (for example, a depth limit);
> without it, recursion may not converge and generation can time out.

#### Example

```erlang
1> F = fun Recur(D) ->
1>         case D >= 3 of
1>             true -> kaos:const(leaf);
1>             false ->
1>                 kaos:choose([
1>                     kaos:const(leaf),
1>                     kaos:map(fun({L,R}) -> {node,L,R} end,
1>                              kaos:tuple_of([kaos:recurse(Recur), kaos:recurse(Recur)]))
1>                 ])
1>         end
1>     end.
2> {ok, [Tree]} = kaos:generate(kaos:recurse(F), 505, 1).
3> Tree.
{node,{node,{node,leaf,leaf},leaf},{node,{node,leaf,leaf},{node,leaf,leaf}}}
```
""".
-spec recurse(depth_function()) -> gen().
recurse(Fun) when is_function(Fun, 1) -> #gen_recurse{f = Fun}.

-doc """
Returns a generator that produces a `sets:set()` with size generated by
`GenSize` and elements generated by `GenValue`. Duplicate elements are skipped
until the target size is reached.

#### Parameters

- `GenSize` — generator of non-negative integers (>= 0); set cardinality. If it
  yields an invalid value, generation fails with {error, {badarg, "Size
  generator must provide an integer >= 0"}, _}.
- `GenValue` — generator for set elements; should produce enough unique elements to reach size. Duplicates are skipped; a narrow domain may increase generation time or cause timeouts.

#### Example

```erlang
1> Gen = kaos:set_of(kaos:const(3), kaos:integer(1,100)).
2> {ok, [S]} = kaos:generate(Gen, 909, 1).
3> sets:to_list(S).
[25,42,63]
```
""".
-spec set_of(gen(), gen()) -> gen().
set_of(GenSize, GenValue) -> #gen_set{gen_size = GenSize, gen_value = GenValue}.

-doc """
Returns a generator that produces a random permutation of the given list
(`Fisher–Yates` shuffle).

#### Parameters

- `Elements` — list of terms to shuffle.

#### Example

```erlang
1> Gen = kaos:shuffle([1,2,3,4,5]).
2> {ok, [L]} = kaos:generate(Gen, 909, 1).
3> L.
[3,1,5,4,2]
```
""".
-spec shuffle(list()) -> gen().
shuffle(Elements) when is_list(Elements) -> #gen_shuffle{list = Elements}.

-doc """
Returns a generator that produces a UTF-8 binary (string) whose length is
generated by `GenSize` and whose characters are generated by `GenChar`.

#### Parameters

- `GenSize` — generator of non-negative integers (>= 0); number of characters.
  If it yields an invalid value, generation fails with {error, {badarg,
  "Size generator must provide an integer >= 0"}, _}.
- `GenChar` — generator of codepoints (integers); must yield valid Unicode
  codepoints. If it yields an invalid value, generation fails with {error,
  badarg, _} from `unicode:characters_to_binary/1`.

#### Example

```erlang
1> Gen = kaos:string_of(kaos:const(5), kaos:const($A)).
2> {ok, [S]} = kaos:generate(Gen, 111, 1).
3> S.
<<"AAAAA">>
```
""".
-spec string_of(gen(), gen()) -> gen().
string_of(GenSize, GenChar) -> #gen_string{gen_size = GenSize, gen_char = GenChar}.

-doc """
Returns a generator that produces a tuple by sampling each generator in `Gens`
once and assembling the results in order.

#### Parameters

- `Gens` — list of `gen()` values; one element per tuple position.

#### Example

```erlang
1> Gen = kaos:tuple_of([kaos:const(1), kaos:const(true), kaos:const("abc")]).
2> {ok, [T]} = kaos:generate(Gen, 9, 1).
3> T.
{1,true,"abc"}
```
""".
-spec tuple_of(list(gen())) -> gen().
tuple_of(Gens) when is_list(Gens) -> #gen_tuple{gens = Gens}.

-doc """
Returns a generator that selects among `gen()` values with integer weights.
Weights are normalized by their greatest common divisor, and selection is
uniform within the expanded ranges.

#### Parameters

- `WeightedGens` — list of `{Weight, Gen}` pairs where `Weight > 0`.

#### Example

```erlang
1> Gen = kaos:weighted([{20, kaos:const(2)}, {80, kaos:const(8)}]).
2> {ok, Values} = kaos:generate(Gen, 101, 10).
3> Values.
[8,8,8,8,8,2,2,2,8,8]
```
""".
-spec weighted(nonunary_list()) -> gen().
weighted(WeightedGens = [_, _ | _]) ->
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

-doc """
Returns a generator that maps each sampled value from `Gen` through `Fun/1`.

#### Parameters

- `Fun` — unary function to transform each sampled value.
- `Gen` — source generator to sample from.

#### Example

```erlang
1> Fun = fun(S) -> S * 10 end.
2> Gen = kaos:map(Fun, kaos:const(3)).
3> {ok, Values} = kaos:generate(Gen, 999, 3).
4> Values.
[30,30,30]
```
""".
-spec map(map_function(), gen()) -> gen().
map(Fun, Gen) when is_function(Fun, 1) -> #mod_map{f = Fun, gen = Gen}.

default_timeout() -> 30_000.

-doc """
Generates a list of `Count` samples from `Gen` using `Seed` for deterministic
randomness.

#### Parameters

- `Gen` — generator to sample from.
- `Seed` — term to seed the random number generator.
- `Count` — positive integer; number of samples.

#### Example

```erlang
1> {ok, Values} = kaos:generate(kaos:integer(1,5), 909, 5).
2> Values.
[3,2,5,5,2]
```
""".
-spec generate(gen(), term(), pos_integer()) -> generate_response().
generate(Gen, Seed, Count) when is_integer(Count), Count > 0 ->
    generate(Gen, Seed, Count, default_timeout()).

-doc """
Like `generate/3` but with a millisecond timeout. Returns `{error, timeout}` if
the worker exceeds `Timeout`.

#### Parameters

- `Gen` — generator to sample from.
- `Seed` — term to seed the random number generator.
- `Count` — positive integer; number of samples.
- `Timeout` — positive integer; milliseconds before timing out.

#### Example

```erlang
1> {ok, Values} = kaos:generate(kaos:integer(1,5), 909, 3, 5000).
2> Values.
[3,2,5]
```
""".
-spec generate(gen(), term(), pos_integer(), pos_integer()) -> generate_response().
generate(Gen, Seed, Count, Timeout) when is_integer(Count), Count > 0, is_integer(Timeout), Timeout > 0 ->
    Result = generate_into(
        Gen,
        Seed,
        Count,
        fun (Sample, Acc) -> [Sample | Acc] end,
        [],
        Timeout
    ),
    case Result of
        {ok, SampleList} -> {ok, lists:reverse(SampleList)};
        Error -> Error
    end.

-doc """
Generates `Count` samples from `Gen`, folding each into the accumulator with
`Merge/2`, and returns the final accumulator.

#### Parameters

- `Gen` — generator to sample from.
- `Seed` — term to seed the random number generator.
- `Count` — positive integer; number of samples.
- `Merge` — fun `(Sample, PrevAcc) -> NewAcc` to merge each sample.
- `Acc` — initial accumulator value.

#### Example

```erlang
1> Merge = fun(V, S) -> sets:add_element(V, S) end.
2> {ok, Set} = kaos:generate_into(kaos:integer(1,3), 505, 20, Merge, sets:new()).
3> sets:to_list(Set).
[1,2,3]
```
""".
-spec generate_into(gen(), term(), pos_integer(), generate_into_function(T), T) -> generate_into_response(T).
generate_into(Gen, Seed, Count, Merge, Acc) when is_integer(Count), Count > 0 ->
    generate_into(Gen, Seed, Count, Merge, Acc, default_timeout()).

-doc """
Like `generate_into/5` but with a millisecond timeout. Returns `{error, timeout}`
if the worker exceeds `Timeout`.

#### Parameters

- `Gen` — generator to sample from.
- `Seed` — term to seed the random number generator.
- `Count` — positive integer; number of samples.
- `Merge` — fun `(Sample, Acc) -> Acc1`.
- `Acc` — initial accumulator value.
- `Timeout` — positive integer; milliseconds before timing out.

#### Example

```erlang
1> Merge = fun(V, S) -> sets:add_element(V, S) end.
2> {ok, Set} = kaos:generate_into(kaos:integer(1,3), 505, 20, Merge, sets:new(), 5000).
3> sets:to_list(Set).
[1,2,3]
```
""".
-spec generate_into(gen(), term(), pos_integer(), generate_into_function(T), T, pos_integer()) -> generate_into_response(T).
generate_into(Gen, Seed, Count, Merge, Acc, Timeout) when is_integer(Count), Count > 0, is_integer(Timeout), Timeout > 0 ->
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
    after Timeout ->
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
        _:Reason:Stacktrace ->
            To ! {error, Reason, Stacktrace}
    end.

gcd(A, B) when is_integer(A), is_integer(B), A < B -> gcd(B, A);
gcd(A, 0) when is_integer(A), A >= 0 -> A;
gcd(A, B) when is_integer(A), A >= 0, is_integer(B), B >= 0 -> gcd(B, A rem B).

reduce(_, [L]) -> L;
reduce(Fun, [L, R | T]) -> reduce(Fun, [Fun(L, R) | T]).

generate_one(#gen_all{gens = Gens}) ->
    lists:map(fun generate_one/1, Gens);
generate_one(#gen_binary{gen_size = GenSize, gen_byte = GenByte}) ->
    case Size = generate_one_size(GenSize) of
        0 -> <<>>;
        _ ->
            Bytes = [generate_one_byte(GenByte) || _ <- lists:seq(1, Size)],
            << <<B>> || B <- Bytes >>
    end;
generate_one(#gen_bitstring{gen_size = GenSize, gen_bit = GenBit}) ->
    GenerateOneBit =
        fun () ->
            case generate_one(GenBit) of
                0 -> 0;
                1 -> 1;
                _ -> throw({badarg, "Bit generator must produce 0 or 1"})
            end
        end,
    case Size = generate_one_size(GenSize) of
        0 -> <<>>;
        _ ->
            Bits = [GenerateOneBit() || _ <- lists:seq(1, Size)],
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
generate_one(#gen_shuffle{list = Elements}) ->
    % Implementation of Fisher-Yates shuffle algorithm.
    % See: https://en.wikipedia.org/wiki/Fisher–Yates_shuffle
    case Elements of
        [] -> [];
        [E] -> [E];
        _ ->
            ElemArray = array:from_list(Elements),
            N = array:size(ElemArray),
            N_2 = N - 2,
            N_1 = N - 1,
            Shuffle = fun
                Recur (Array, I) when I > N_2 ->
                    array:to_list(Array);
                Recur (Array, I) ->
                    J = generate_one(integer(I, N_1)),
                    IE = array:get(I, Array),
                    JE = array:get(J, Array),
                    ISwapped = array:set(I, JE, Array),
                    JSwapped = array:set(J, IE, ISwapped),
                    Recur(JSwapped, I + 1)
            end,
            Shuffle(ElemArray, 0)
    end;
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
