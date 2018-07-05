-module(sud).
-compile(export_all).

unit_size() -> 9.   %6
rows_in_quadrant() -> 3. %2
cols_in_quadrant() -> 3. %3

initial_grid() -> dict:from_list(lists:map(fun(C) -> {C,lists:seq(1,unit_size())} end, cells())).

col_ids() -> 
    {Prefix,_} = lists:split(unit_size(),"123456789ABCDEFGHIJKLMNOPQ"),
    Prefix.
row_ids() -> 
    {Prefix,_} = lists:split(unit_size(),"ABCDEFGHIJKLMNOPQRSTUVWXYZ"),
    Prefix.

sublist(_,[]) -> [];
sublist(0,L) -> L;
sublist(N,L) when length(L) > N -> 
    {P,S} = lists:split(N,L),
    [P|sublist(N,S)];
sublist(_,L) ->
    [L].

row_partitions() ->
    sublist(rows_in_quadrant(),row_ids()).

col_partitions() ->
    sublist(cols_in_quadrant(),col_ids()).

cross(List1,List2) -> [ [X,Y] || X <- List1, Y <- List2].

cells() -> cross(row_ids(),col_ids()).

unit_list() -> 
    [ cross(row_ids(),[C]) || C <- col_ids() ] ++
    [ cross([R],col_ids()) || R <- row_ids() ] ++
    [ cross(R,C) || R <- row_partitions(), C <- col_partitions() ].
    
units() -> [ { S , [ U || U <- unit_list(), lists:member(S,U) ] } || S <- cells() ]. 

flatten([]) -> [];
flatten([L|LOL]) ->  L ++ flatten(LOL).

peers() -> dict:from_list([ {S,sets:to_list(sets:del_element(S,sets:from_list(flatten(LOS))))} || {S,LOS} <- units() ]).

gridstring2tuples(S) ->  
    F = fun({K,$0}) -> {K,lists:seq(1,unit_size())} ;
            ({K,N}) -> {K,[N-48]}
    end,        
    lists:map(F, lists:zip(cells(),S)).

to_string(I) when is_integer(I) -> [I+48];
to_string([]) -> [];
to_string([I|Is]) -> to_string(I) ++ to_string(Is).

grid2gridstring(Dict) ->
    F = fun(K,Acc) -> Acc ++"("++ to_string(dict:fetch(K,Dict))++")" end,
    lists:foldl(F,"",cells()).

grid2list(Dict) ->
    F = fun(K) -> dict:fetch(K,Dict) end,
    lists:map(F,cells()).

print_grid(Dict) when is_tuple(Dict) ->
    L = grid2list(Dict), 
    print_grid(L);
print_grid([]) -> io:format("~n",[]);
print_grid(List) when is_list(List) ->
    {Row,Rest} = lists:split(unit_size(),List),
    io:format("~w~n",[Row]),
    print_grid(Rest).

remove_unconstrained_cells(LOL) -> lists:map(fun(L) -> lists:filter(fun(C) -> is_integer(C) end,L) end ,LOL).

my_peers(ME) -> dict:fetch(ME,data_server:get(ds,peers)).
%my_peers(ME) -> dict:fetch(ME,peers()).

forward(S) ->
    G = forward_(gridstring2tuples(S)),
    grid2gridstring(G).

forward_(Tuples) ->
    Facts = facts(Tuples),
    lists:foldl(fun({K,V},Acc) -> assign(Acc,K,V) end,initial_grid(),Facts).

assign(Grid,Cell,[Domain]) ->
    case conflict(Grid,Cell,[Domain]) of 
        false -> reduce(dict:store(Cell,[Domain],Grid), [Domain], my_peers(Cell));
        true -> Grid
    end.

conflict(Grid,Cell,[Domain]) -> 
    Fun = fun(P) -> [Domain] /= dict:fetch(P,Grid) end,
    Hits = lists:takewhile(Fun, my_peers(Cell)),
    length(Hits) /= length(my_peers(Cell)).

is_subset_of([Domain1],Domain2) -> lists:member(Domain1,Domain2).

difference(List1,[Domain]) -> 
    case lists:member(Domain,List1) of
        true -> lists:delete(Domain,List1);
        false -> List1
    end.    

reduce(Grid,_,[]) -> Grid;
reduce(Grid,[Domain],[Peer|Peers]) ->
    PeerDomain = dict:fetch(Peer,Grid),
    case is_subset_of([Domain],PeerDomain) of
        true -> 
            Diff = difference(PeerDomain,[Domain]),    
            Next = reduce(dict:store(Peer,Diff,Grid),[Domain],Peers),
            reduce(Next,Diff,my_peers(Peer));
        false -> reduce(Grid,[Domain],Peers)
    end;
reduce(Grid,Domain,[Peer|Peers]) -> Grid.

backtrack([],Grid) ->
    case is_consistent(Grid) and is_solved(Grid) of
        true -> Grid;
        false -> dict:new()
    end;
backtrack([Cell|Cells],Grid) ->
    case is_solved(Grid) and is_consistent(Grid) of
        true -> Grid;
        false ->
          case is_consistent(Grid) of
              true -> 
                  Fun = fun(D,Acc) -> 
                            case Acc == dict:new() of
                                true -> backtrack(Cells, (assign(Grid, Cell,[D])));
                                false -> Acc
                            end
                        end,
                  lists:foldl(Fun,dict:new(),dict:fetch(Cell,Grid));
              false ->
                  dict:new()
          end        
    end.

resolve_unit_list(Grid) ->
    Fun = fun(E,Acc) ->
        D = dict:fetch(E,Grid),
        X = case length(D) of
              1 -> D;
              _ -> E
        end,
        sets:add_element(X,Acc)
    end,
    lists:map(fun(L) -> sets:to_list(lists:foldl(Fun,sets:new(),L)) end,data_server:get(ds,unit_list)).
    %lists:map(fun(L) -> sets:to_list(lists:foldl(Fun,sets:new(),L)) end,unit_list()).

facts(Grid) when is_tuple(Grid)  ->  facts(dict:to_list(Grid));
facts(List) when is_list(List)  ->  lists:filter(fun({_,V}) -> length(V) == 1 end, List).

is_solved(Grid) -> 
    List = facts(Grid),
    dict:size(Grid) == length(List).

is_consistent(Grid) ->
    RL = resolve_unit_list(Grid),
    XL = lists:takewhile(fun(L) -> length(L) == unit_size() end,RL),
    length(RL) == length(XL).

solve(S) ->
    Tuples = gridstring2tuples(S),
    Grid = forward_(Tuples),
    Solution = backtrack(lists:filter(fun(E) -> length(dict:fetch(E,Grid)) > 1 end,dict:fetch_keys(Grid)),Grid),
    grid2gridstring(Solution).

test() -> [
    forward("003010002850649700070002000016080070204701609030020810000500020009273086300060900") == "(4)(9)(3)(8)(1)(7)(5)(6)(2)(8)(5)(2)(6)(4)(9)(7)(3)(1)(6)(7)(1)(3)(5)(2)(4)(9)(8)(9)(1)(6)(4)(8)(5)(2)(7)(3)(2)(8)(4)(7)(3)(1)(6)(5)(9)(7)(3)(5)(9)(2)(6)(8)(1)(4)(1)(6)(8)(5)(9)(4)(3)(2)(7)(5)(4)(9)(2)(7)(3)(1)(8)(6)(3)(2)(7)(1)(6)(8)(9)(4)(5)",
    forward("920705003600000080004600000006080120040301070071060500000004800010000002400902061") == "(9)(2)(8)(7)(4)(5)(6)(1)(3)(6)(5)(7)(2)(1)(3)(4)(8)(9)(1)(3)(4)(6)(9)(8)(2)(5)(7)(3)(9)(6)(5)(8)(7)(1)(2)(4)(8)(4)(5)(3)(2)(1)(9)(7)(6)(2)(7)(1)(4)(6)(9)(5)(3)(8)(7)(6)(2)(1)(3)(4)(8)(9)(5)(5)(1)(9)(8)(7)(6)(3)(4)(2)(4)(8)(3)(9)(5)(2)(7)(6)(1)",
    solve("900705003600000080004600000006080120040301070071060500000004800010000002400902001") == "(9)(2)(8)(7)(4)(5)(6)(1)(3)(6)(5)(7)(2)(1)(3)(4)(8)(9)(1)(3)(4)(6)(9)(8)(2)(5)(7)(3)(9)(6)(5)(8)(7)(1)(2)(4)(8)(4)(5)(3)(2)(1)(9)(7)(6)(2)(7)(1)(4)(6)(9)(5)(3)(8)(7)(6)(2)(1)(3)(4)(8)(9)(5)(5)(1)(9)(8)(7)(6)(3)(4)(2)(4)(8)(3)(9)(5)(2)(7)(6)(1)",
    solve("020007000609000008000950200035000070407000809080000120001034000700000602000100030") == "(1)(2)(8)(4)(6)(7)(3)(9)(5)(6)(5)(9)(3)(1)(2)(7)(4)(8)(3)(7)(4)(9)(5)(8)(2)(6)(1)(2)(3)(5)(8)(9)(1)(4)(7)(6)(4)(1)(7)(6)(2)(3)(8)(5)(9)(9)(8)(6)(7)(4)(5)(1)(2)(3)(5)(6)(1)(2)(3)(4)(9)(8)(7)(7)(4)(3)(5)(8)(9)(6)(1)(2)(8)(9)(2)(1)(7)(6)(5)(3)(4)",
    solve("600000084003060000001000502100074000720906035000320008305000200000050900240000007") == "(6)(5)(2)(7)(1)(9)(3)(8)(4)(4)(8)(3)(2)(6)(5)(7)(9)(1)(9)(7)(1)(4)(3)(8)(5)(6)(2)(1)(3)(8)(5)(7)(4)(6)(2)(9)(7)(2)(4)(9)(8)(6)(1)(3)(5)(5)(6)(9)(3)(2)(1)(4)(7)(8)(3)(9)(5)(8)(4)(7)(2)(1)(6)(8)(1)(7)(6)(5)(2)(9)(4)(3)(2)(4)(6)(1)(9)(3)(8)(5)(7)",
    solve("100007090030020008009600500005300900010080002600004000300000010040000007007000300") == "(1)(6)(2)(8)(5)(7)(4)(9)(3)(5)(3)(4)(1)(2)(9)(6)(7)(8)(7)(8)(9)(6)(4)(3)(5)(2)(1)(4)(7)(5)(3)(1)(2)(9)(8)(6)(9)(1)(3)(5)(8)(6)(7)(4)(2)(6)(2)(8)(7)(9)(4)(1)(3)(5)(3)(5)(6)(4)(7)(8)(2)(1)(9)(2)(4)(1)(9)(3)(5)(8)(6)(7)(8)(9)(7)(2)(6)(1)(3)(5)(4)"
    ].

init() ->
    data_server:new(ds),
    data_server:put(ds,peers,peers()),
    data_server:put(ds,unit_list,unit_list()),
    data_server:put(ds,cells,cells()),
    data_server:put(ds,units,units()).

stop()->
    data_server:stop(ds).
