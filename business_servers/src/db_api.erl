-module(db_api).
-export([store_location_id/3, delivered/2, get_location/2, update_location/4, initialize_connection/2]).

store_location_id(Pack_id, Loc_id, Some_Db_PID)->
    io:format("PackID: ~p Location:~p~n", [Pack_id, Loc_id]),
    Request=riakc_obj:new(<<"packages">>, Pack_id, {Loc_id, false}),
    case riakc_pb_socket:put(Some_Db_PID, Request) of 
        ok -> worked;
        _ -> fail
    end.

delivered(Pack_id, Some_Db_PID)->
    case riakc_pb_socket:get(Some_Db_PID, <<"packages">>, Pack_id) of
        {ok, Package} ->
            Val = riakc_obj:get_value(Package),
            io:format(Val),
            [Loc_id, _] = Val,
            io:format(Loc_id),
            Request=riakc_obj:new(<<"packages">>, Pack_id, {Loc_id, true}),
            case riakc_pb_socket:put(Some_Db_PID, Request) of 
                ok -> worked;
                _ -> fail
            end;
        _ -> fail
    end.

get_location(Pack_id, Some_Db_PID)->
    io:format("PackID: ~p~n", [Pack_id]),
    case riakc_pb_socket:get(Some_Db_PID, <<"packages">>, Pack_id) of
        {ok, Fetched} ->
            io:format("Fetched: ~p~n", [Fetched]),
            Something = riakc_obj:get_value(Fetched),
            io:format("Something: ~p~n", [Something]),
            case riakc_pb_socket:get(<<"locations">>, Something) of
            {ok, Loc_obj} ->
                {Long, Lat} = riakc_obj:get_value(Loc_obj),
                {worked, Long, Lat};
            _ -> fail
            end;
        _ -> 
            fail
    end.

update_location(Loc_id, Long, Lat, Some_Db_PID)->
    Request=riakc_obj:new(<<"locations">>, Loc_id, {Long, Lat}),
    case riakc_pb_socket:put(Some_Db_PID, Request) of
        ok -> worked;
        _ -> fail
    end.

initialize_connection(Address, Port)->
    {ok, Db_pid} = riakc_pb_socket:start(Address, Port),
    Db_pid.