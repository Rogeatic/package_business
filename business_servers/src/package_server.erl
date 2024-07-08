-module(package_server).
-behaviour(gen_server).


%% API
-export([start/0,start/3,stop/0, transfer_package/2]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3, update_location/3]).


%%%===================================================================
%%% API
%%%===================================================================

transfer_package(Pack_id, Loc_id) -> 
    gen_server:call(?MODULE, {package_transferred, Pack_id, Loc_id}).
    
update_location(Loc_id, Long, Lat) -> 
    gen_server:call(?MODULE, {location_update, Loc_id, Long, Lat}).





%%--------------------------------------------------------------------
%% @doc
%% Starts the server assuming there is only one server started for 
%% this module. The server is registered locally with the registered
%% name being the name of the module.
%%
%% @end
%%--------------------------------------------------------------------
-spec start() -> {ok, pid()} | ignore | {error, term()}.
start() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).
%%--------------------------------------------------------------------
%% @doc
%% Starts a server using this module and registers the server using
%% the name given.
%% Registration_type can be local or global.
%%
%% Args is a list containing any data to be passed to the gen_server's
%% init function.
%%
%% @end
%%--------------------------------------------------------------------
-spec start(atom(),atom(),atom()) -> {ok, pid()} | ignore | {error, term()}.
start(Registration_type,Name,Args) ->
    gen_server:start_link({Registration_type, Name}, ?MODULE, Args, []).


%%--------------------------------------------------------------------
%% @doc
%% Stops the server gracefully
%%
%% @end
%%--------------------------------------------------------------------
-spec stop() -> {ok}|{error, term()}.
stop() -> gen_server:call(?MODULE, stop).

%% Any other API functions go here.

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%%
%% @end
%%--------------------------------------------------------------------
-spec init(term()) -> {ok, term()}|{ok, term(), number()}|ignore |{stop, term()}.
init([]) ->
    io:format("starting up package server~n"),
    Db_pid = db_api:initialize_connection("24.199.125.13", 8087),
    io:format("connected to Riak ~p~n", [Db_pid]),
    {ok, Db_pid}.

% Handling call messages
-spec handle_call(Request::term(), From::pid(), State::term()) ->
                                  {reply, term(), term()} |
                                  {reply, term(), term(), integer()} |
                                  {noreply, term()} |
                                  {noreply, term(), integer()} |
                                  {stop, term(), term(), integer()} | 
                                  {stop, term(), term()}.

% UPDATING LOCATION ID
handle_call({package_transferred, Pack_id, Loc_id}, _Some_from_pid, Some_Db_PID) ->
    case is_integer(Pack_id) == false orelse is_integer(Loc_id) == false of
    true -> {reply, fail, Some_Db_PID};
    false ->
        {reply, db_api:store_location_id(Pack_id, Loc_id, Some_Db_PID), Some_Db_PID}
    end;
% UPDATING AS DELIVERED
handle_call({delivered, Pack_id}, _Some_from_pid, Some_Db_PID) ->
    case is_integer(Pack_id) == false of
    true -> {reply, fail, Some_Db_PID};
    false ->
        {reply, db_api:delivered(Pack_id, Some_Db_PID), Some_Db_PID}
    end;

% GET LOCATION
handle_call({location_request, Pack_id}, _Some_from_pid, Some_Db_PID) ->
    case is_integer(Pack_id) == false of
    true -> {reply, fail, Some_Db_PID};
    false ->
        {reply, db_api:get_location(Pack_id), Some_Db_PID}
    end;

% UPDATE LOCATION
handle_call({location_update, Loc_id, Long, Lat}, _Some_from_pid, Some_Db_PID) ->
    case is_integer(Loc_id) == false orelse is_float(Long) == false  orelse is_float(Lat) == false of
    true -> {reply, fail, Some_Db_PID};
    false ->
        {reply, db_api:update_location(Loc_id, Long, Lat, Some_Db_PID), Some_Db_PID}
    end;

% KILL SERVER % setting the server's internal state to down
handle_call(stop, _Some_from_pid, _State) ->
    {stop,normal,
        server_stopped,
        down}. 

% HANDLING CAST MESSAGE
-spec handle_cast(Msg::term(), State::term()) -> {noreply, term()} |
                                  {noreply, term(), integer()} |
                                  {stop, term(), term()}.
handle_cast(_Msg, State) ->
    {noreply, State}.
    
% Handling all non call/cast messages
-spec handle_info(Info::term(), State::term()) -> {noreply, term()} |
                                   {noreply, term(), integer()} |
                                   {stop, term(), term()}.
handle_info(_Info, State) ->
    {noreply, State}.

%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
-spec terminate(Reason::term(), term()) -> term().
terminate(_Reason, _State) ->
    ok.
    
% CONVERT PROCESS STATE WHEN CODE CHANGES
-spec code_change(term(), term(), term()) -> {ok, term()}.
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.


-ifdef(EUNIT).
%%
%% Unit tests go here. 
%%
-include_lib("eunit/include/eunit.hrl").

%Startup Test
startup_test_() ->
    {setup,
    fun() -> %this setup fun is run once befor the tests are run.
        meck:new(db_api),
        meck:expect(db_api, initialize_connection, fun(Address, Port) -> 1 end)
    end,
    fun(_) ->%This is the teardown fun.
        meck:unload(db_api)
    end,
    [
        ?_assertEqual({ok, 1},package_server:init([]))
    ]}.


package_transfer_test_()->
    {setup,
    fun() -> %this setup fun is run once befor the tests are run.
        meck:new(db_api),
        meck:expect(db_api, store_location_id, fun(Pack_id, Loc_id, Some_Db_PID) -> 
            case Pack_id of
                bad_id -> fail;
                3 -> fail;
                _ -> 
                case Some_Db_PID of
                    bad_Db_PID -> fail;
                    _ -> worked
                end
            end
        end)
    
    end,
    fun(_) ->%This is the teardown fun.
        meck:unload(db_api)
    end,
    [%Package Transfer Test
        ?_assertEqual({reply, worked, some_Db_PID}, package_server:handle_call({package_transferred, 99999, 111}, some_from_pid, some_Db_PID)), % happy path
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({package_transferred, bad_id, 111}, some_from_pid, some_Db_PID)), % non-int pack_id
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({package_transferred, 3, 111}, some_from_pid, some_Db_PID)), % bad pack_id
        ?_assertEqual({reply, fail, bad_Db_PID}, package_server:handle_call({package_transferred, 99999, 111}, some_from_pid, bad_Db_PID)), % bad db_pid
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({package_transferred, 99999, string}, some_from_pid, some_Db_PID)), % non-int loc_id
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({package_transferred, string, string}, some_from_pid, some_Db_PID)), % non-int pack+loc_id
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({package_transferred, 3, string}, some_from_pid, some_Db_PID)), % bad Pack_id + non-int loc_id
        ?_assertEqual({reply, fail, bad_Db_PID}, package_server:handle_call({package_transferred, 99999, string}, some_from_pid, bad_Db_PID)), % nonint loc_id + bad db_pid
        ?_assertEqual({reply, fail, bad_Db_PID}, package_server:handle_call({package_transferred, 3, 111}, some_from_pid, bad_Db_PID)), % bad package_id + bad db_pid
        ?_assertEqual({reply, fail, bad_Db_PID}, package_server:handle_call({package_transferred, string, 111}, some_from_pid, bad_Db_PID)), % non-int pack_id + bad db_pid
        ?_assertEqual({reply, fail, bad_Db_PID}, package_server:handle_call({package_transferred, bad, bad}, some_from_pid, bad_Db_PID)) % bad thoughts
    ]}.
  
delivered_test_()->
    {setup,
    fun() -> %this setup fun is run once befor the tests are run.
        meck:new(db_api),
        meck:expect(db_api, delivered, fun(Pack_id, Some_Db_PID)->
            case Pack_id of
                bad_id -> fail;
                3 -> fail;
                _ -> 
                case Some_Db_PID of
                    bad_Db_PID -> fail;
                    _ -> worked
                end
            end
        end)
        end,
    fun(_) ->%This is the teardown fun.
       meck:unload(db_api)
    end,
    [%Delievered Test
    ?_assertEqual({reply, worked, some_Db_PID}, package_server:handle_call({delivered, 100}, some_from_pid, some_Db_PID)),
    ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({delivered, 3}, some_from_pid, some_Db_PID)),
    ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({delivered, bad_id}, some_from_pid, some_Db_PID)),
    ?_assertEqual({reply, fail, bad_Db_PID}, package_server:handle_call({delivered, 100}, some_from_pid, bad_Db_PID))
]}.

request_test_()->
    {setup,
    fun() -> %this setup fun
        meck:new(db_api),
        meck:expect(db_api, get_location, fun(Pack_id) ->
            case Pack_id of
                bad_id -> fail;
                3 -> fail;
                _ -> {worked, 123.0, 456.0}
            end
        end)
    end,
    fun(_) ->%This is the teardown fun.
       meck:unload(db_api)
    end,
    [%Request Test
        ?_assertEqual({reply, {worked, 123.0, 456.0}, some_Db_PID}, package_server:handle_call({location_request, 1111}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_request, bad_id}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_request, 3}, some_from_pid, some_Db_PID))
    ]}.

location_test_()->
    {setup,
    fun() -> %this setup function
        meck:new(db_api),
        meck:expect(db_api, update_location, fun(Loc_id, Long, Lat, Some_Db_PID) -> 
            case Loc_id of
                bad_loc_id -> fail;
                3 -> fail;
                _ -> 
                    case Long of
                        bad_long -> fail;
                        3.0 -> fail;
                        _ ->
                            case Lat of
                                bad_lat -> fail;
                                3.0 -> fail;
                                _ -> worked
                            end
                    end
            end
        end)
        
    end,
    fun(_) ->%This is the teardown fun.
        meck:unload(db_api)
    end,
    [%Update Test
        %BAD LOC_ID
        ?_assertEqual({reply, worked, some_Db_PID}, package_server:handle_call({location_update, 100, 123.0, 456.0}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, 3, 123.0, 456.0}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, bad_loc_id, 123.0, 456.0}, some_from_pid, some_Db_PID)),
        %BAD LONG
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, 100, 123, 456.0}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, 100, bad_long, 456.0}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, 100, 3.0, 456.0}, some_from_pid, some_Db_PID)),
        %BAD LAT
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, 100, 123.0, 456}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, 100, 123.0, bad_lat}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, 100, 123.0, 3.0}, some_from_pid, some_Db_PID)),

        %BAD LAT AND LONG
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, 100, 3.0, 3.0}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, 100, bad_long, bad_lat}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, 100, 123, 123}, some_from_pid, some_Db_PID)),    
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, 100, 3.0, 123}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, 100, 3.0, bad_lat}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, 100, 123, 3.0}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, 100, bad_long, 3.0}, some_from_pid, some_Db_PID)),

        %BAD LOC_ID AND LONG
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, bad_loc_id, 3.0, 456.0}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, bad_loc_id, 123, 456.0}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, bad_loc_id, bad_long, 456.0}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, 3, 3.0, 456.0}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, 3, 123, 456.0}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, 3, bad_long, 456.0}, some_from_pid, some_Db_PID)),

        %BAD LOC_ID AND LAT
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, bad_loc_id, 123.0, 3.0}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, bad_loc_id, 123.0, 123}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, bad_loc_id, 123.0, bad_lat}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, 3, 123.0, 3.0}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, 3, 123.0, 123}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, 3, 123.0, bad_lat}, some_from_pid, some_Db_PID)),

        %BAD THOUGHTS
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, bad_loc_id, 3.0, 3.0}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, bad_loc_id, 123, 3.0}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, bad_loc_id, bad_long, 3.0}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, bad_loc_id, 3.0, 123}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, bad_loc_id, 3.0, bad_lat}, some_from_pid, some_Db_PID)),

        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, 3, 3.0, 3.0}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, 3, 123, 3.0}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, 3, bad_long, 3.0}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, 3, 3.0, 123}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, 3, 3.0, bad_lat}, some_from_pid, some_Db_PID))
]}.

   
-endif.