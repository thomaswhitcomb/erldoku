-module(data_server).
-compile(export_all).

new(Name) ->
  register(Name,spawn(data_server,init,[])).

put(Atom,Key,Value) when is_atom(Atom) ->put(whereis(Atom),Key,Value);
put(Pid,Key,Value) ->
  Pid!{self(),put,Key,Value},
  receive
    {Pid,put,X} -> X
    after 3000 -> timeout
  end.

ping(Atom) when is_atom(Atom) -> ping(whereis(Atom));
ping(Pid) ->
  Pid!{self(),ping},
  receive
   {Pid,ping,X} -> X
   after 3000 -> timeout
  end.

get(Atom,Key) when is_atom(Atom) -> get(whereis(Atom),Key);
get(Pid,Key) ->
  Pid!{self(),get,Key},
  receive
   {Pid,get,X,ok} -> X
   after 3000 -> timeout
  end.

stop(Atom) when is_atom(Atom)  -> 
  stop(whereis(Atom));

stop(Pid) ->
  Pid!{self(),stop},
  receive
    {Pid,stop,X} -> X
    after 3000 -> timeout
  end.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Server
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
init() ->
  Hash = dict:new(),
  loop(Hash).

loop(Hash) ->
  receive
    {Pid,put,Key,Value} ->
      NewHash = dict:store(Key,Value,Hash),
      Pid!{self(),put,ok},
      loop(NewHash);

    {Pid,get,Key} ->
      Value = dict:fetch(Key,Hash),
      Pid!{self(),get,Value,ok},
      loop(Hash);

    {Pid,ping} ->
      Pid!{self(),ping,pong},
      loop(Hash);

    {Pid,stop} ->
      Pid!{self(),stop,ok}
  end.
