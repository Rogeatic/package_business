-module(package_server).
-behaviour(gen_server).


%% API
-export([start/0,start/3,stop/0]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).


%%%===================================================================
%%% API
%%%===================================================================

transfer_package(Pack_id, Loc_id) -> 
    gen_server:call(?MODULE, {package_transfered, Pack_id, Loc_id}).
    






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
    {ok, Db_pid} = riakc_pb_socket:start("24.199.125.13", 8087),
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
handle_call({package_transfered, Pack_id, Loc_id}, Some_from_pid, Some_Db_PID) ->
    case is_integer(Pack_id) == false orelse is_integer(Loc_id) == false of
    true -> {reply, fail, Some_Db_PID};
    false ->
        case riakc_pb_socket:get(<<"packages">>, Pack_id) of
            {ok, _} ->
                Package=riakc_obj:new(<<"packages">>, Pack_id, {Loc_id, false}),
                case riakc_pb_socket:put(Some_Db_PID, Package) of 
                    ok -> {reply, worked, Some_Db_PID};
                    _ -> {reply, fail, Some_Db_PID}
                end;
            _ -> {reply, fail, Some_Db_PID}
        end
    end;
% UPDATING AS DELIVERED
handle_call({delivered, Pack_id}, Some_from_pid, Some_Db_PID) ->
    case is_integer(Pack_id) == false of
    true -> {reply, fail, Some_Db_PID};
    false ->
        case riakc_pb_socket:get(<<"packages">>, Pack_id) of
            {ok, Package} ->
                [Loc_id, _] = riakc_obj:get_values(Package),
                Request=riakc_obj:new(<<"packages">>, Pack_id, {Loc_id, true}),
                case riakc_pb_socket:put(Some_Db_PID, Request) of 
                    ok -> {reply, worked, Some_Db_PID};
                    _ -> {reply, fail, Some_Db_PID}
                end;
            _ -> {reply, fail, Some_Db_PID}
        end
    end;

% GET LOCATION
handle_call({location_request, Pack_id}, Some_from_pid, Some_Db_PID) ->
    case is_integer(Pack_id) == false of
    true -> {reply, fail, Some_Db_PID};
    false ->
        case riakc_pb_socket:get(<<"packages">>, Pack_id) of
            {ok, Package} ->
                [Loc_id, _] = riakc_obj:get_values(Package),
                case riakc_pb_socket:get(<<"locations">>, Loc_id) of
                {ok, Loc_obj} ->
                    [Long, Lat] = riakc_obj:get_values(Loc_obj),
                    {reply, {worked, Long, Lat}, Some_Db_PID};
                _ -> {reply, fail, Some_Db_PID}
                end;
            _ -> {reply, fail, Some_Db_PID}
        end
    end;

% UPDATE LOCATION
handle_call({location_update, Loc_id, Long, Lat}, Some_from_pid, Some_Db_PID) ->
    case is_integer(Loc_id) == false orelse is_float(Long) == false  orelse is_float(Lat) == false of
    true -> {reply, fail, Some_Db_PID};
    false ->
        case riakc_pb_socket:get(<<"locations">>, Loc_id) of
        {ok, _} ->
            Location=riakc_obj:new(<<"locations">>, Loc_id, {Long, Lat}),
            case riakc_pb_socket:put(Some_Db_PID, Location) of 
                ok -> {reply, worked, Some_Db_PID};
                _ -> {reply, fail, Some_Db_PID}
            end;
        _ -> {reply, fail, Some_Db_PID}
        end
    end;

% KILL SERVER % setting the server's internal state to down
handle_call(stop, Some_from_pid, _State) ->
    {stop,normal,
        server_stopped,
        down}. 

% handle_call({friends_for,Name_key,Friends_value}, _From, Db_PID) ->
%         case Name_key =:= <<"">> of
%             true ->
%                 {reply,{fail,empty_key},Db_PID};
%             _ ->
%                 {reply,db_api:put_friends_for(Name_key,Friends_value,Db_PID),Db_PID}
%         end;
% handle_call(stop, _From, _State) ->
%         {stop,normal,
%                 replace_stopped,
%           down}. %% setting the server's internal state to down

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
    {[
        ?_assertEqual(ok,package_server:start())
    ]}.


package_transfer_test_()->
    {setup,
    fun() -> %this setup fun is run once befor the tests are run.
        meck:new(db_api),
        meck:expect(db_api, put_friends_for, fun(Key,Names,PID) -> worked end)
    
    end,
    fun(_) ->%This is the teardown fun.
        meck:unload(db_api)
    end,
    [%Package Transfer Test
        ?_assertEqual({reply, worked, some_Db_PID}, package_server:handle_call({package_transfered, pack_id, loc_id}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({package_transfered, bad_id, loc_id}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({package_transfered, pack_id, bad_id}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({package_transfered, pack_id, undefined}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({package_transfered, bad_id, undefined}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({package_transfered, undefined, loc_id}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({package_transfered, undefined, bad_id}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({package_transfered, undefined, undefined}, some_from_pid, some_Db_PID))
    
    ]}.
  
delivered_test_()->
    {setup,
    fun() -> %this setup fun is run once befor the tests are run.
       meck:new(db_api),
       meck:expect(db_api, put_friends_for, fun(Key,Names,PID) -> worked end)
       
    end,
    fun(_) ->%This is the teardown fun.
       meck:unload(db_api)
    end,
    [%Delievered Test
    ?_assertEqual({reply, worked, some_Db_PID}, package_server:handle_call({delivered, pack_id}, some_from_pid, some_Db_PID)),
    ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({delivered, bad_id}, some_from_pid, some_Db_PID)),
    ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({delivered, undefined}, some_from_pid, some_Db_PID))
]}.

request_test_()->
    {setup,
    fun() -> %this setup fun
       meck:new(db_api),
       meck:expect(db_api, put_friends_for, fun(Key,Names,PID) -> worked end)
       
    end,
    fun(_) ->%This is the teardown fun.
       meck:unload(db_api)
    end,
    [%Request Test
        ?_assertEqual({reply, {worked, 123.0, 456.0}, some_Db_PID}, package_server:handle_call({location_request, pack_id}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_request, bad_id}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_request, undefined}, some_from_pid, some_Db_PID))
    ]}.

location_test_()->
    {setup,
    fun() -> %this setup function
        meck:new(db_api),
        meck:expect(db_api, put_friends_for, fun(Key,Names,PID) -> worked end)
        
    end,
    fun(_) ->%This is the teardown fun.
        meck:unload(db_api)
    end,
    [%Update Test
        ?_assertEqual({reply, worked, some_Db_PID}, package_server:handle_call({location_update, loc_id, 123.0, 456.0}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, bad_id, 123.0, 456.0}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, loc_id, bad_id, 456.0},some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, loc_id, 123.0, bad_id}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, bad_id, bad_id, 456.0}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, bad_id, 123.0, bad_id}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, loc_id, bad_id, bad_id}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, bad_id, bad_id, bad_id}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, undefined, 123.0, 456.0}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, loc_id, undefined, 456.0}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, loc_id, 123.0, undefined}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, undefined, undefined, 456.0}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, undefined, 123.0, undefined}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, loc_id, undefined, undefined}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, undefined, undefined, undefined}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, bad_id, undefined, 456.0}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, bad_id, 123.0, undefined}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, undefined, bad_id, 456.0}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, loc_id, bad_id, undefined}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, undefined, 123.0, bad_id}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, loc_id, undefined, bad_id}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, bad_id, undefined, undefined}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, undefined, bad_id, undefined}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, undefined, undefined, bad_id}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, undefined, bad_id, bad_id}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, bad_id, undefined, bad_id}, some_from_pid, some_Db_PID)),
        ?_assertEqual({reply, fail, some_Db_PID}, package_server:handle_call({location_update, bad_id, bad_id, undefined}, some_from_pid, some_Db_PID))
]}.

   
-endif.