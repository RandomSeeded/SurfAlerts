-module(mongo_handler).
-compile(export_all).
-behavior(gen_server).
-record(db_info, {collection="emails",
    connection}).

start_link() ->
  gen_server:start_link(?MODULE, init, []).

% This function: initial setup and then loops
init(_DBInfo) ->
  application:ensure_all_started(mongodb),
  Database = <<"surf_alert">>,
  {ok, Connection} = mc_worker_api:connect([{database, Database}]),
  MyDB = #db_info{connection=Connection},
  {ok, MyDB}.

handle_call(get_emails, _From, MyDB) ->
  io:format("Retrieving emails...~n"),
  Connection = MyDB#db_info.connection,
  Collection = <<"emails">>,
  {ok, Cursor} = mc_worker_api:find(Connection, Collection, #{}),
  AllEntries = find_all([], Cursor),
  AllEmails = [maps:get(<<"email">>, Map) || {Map} <- AllEntries],
  {reply, AllEmails, MyDB}.

find_all(Acc, Cursor) ->
  Record = mc_cursor:next(Cursor),
  case Record of 
    error ->
      mc_cursor:close(Cursor),
      Acc; 
    _ -> 
      find_all([Record|Acc], Cursor) 
  end.

handle_info(Info, State) -> % calling mc_cursor:next when there are none remaining basically triggers a try/catch which issues this info event. Ideally this would be pattern matched to only catch that.
  io:format("Received handle request for info ~p state ~p~n", [Info, State]),
  {noreply, State}.


get_emails(Pid) ->
  gen_server:call(Pid, get_emails).

terminate(_, _State) ->
  ok.
