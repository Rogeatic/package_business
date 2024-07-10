-module(db_api).
-export([store_location_id/3, delivered/2, get_location/1, update_location/4, initialize_connection/2]).

store_location_id(Pack_id, Loc_id, Some_Db_PID)->
    Request=riakc_obj:new(<<"packages">>, Pack_id, {Loc_id, false}),
    case riakc_pb_socket:put(Some_Db_PID, Request) of 
        ok -> worked;
        _ -> fail
    end.

delivered(Pack_id, Some_Db_PID)->
    case riakc_pb_socket:get(<<"packages">>, Pack_id) of
        {ok, Package} ->
            [Loc_id, _] = riakc_obj:get_values(Package),
            Request=riakc_obj:new(<<"packages">>, Pack_id, {Loc_id, true}),
            case riakc_pb_socket:put(Some_Db_PID, Request) of 
                ok -> worked;
                _ -> fail
            end;
        _ -> fail
    end.

get_location(Pack_id)->
    io:format("2"),
    case riakc_pb_socket:get(<<"packages">>, Pack_id) of
        {ok, Package} ->
            io:format(riakc_obj:get_values(Package)),
            [Loc_id, _] = riakc_obj:get_values(Package),
            case riakc_pb_socket:get(<<"locations">>, Loc_id) of
            {ok, Loc_obj} ->
                [Long, Lat] = riakc_obj:get_values(Loc_obj),
                io:format(riakc_obj:get_values(Loc_obj)),
                {worked, Long, Lat};
            _ -> fail
            end;
        _ -> fail
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