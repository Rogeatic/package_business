%%%-------------------------------------------------------------------
%% @doc business_servers public API
%% @end
%%%-------------------------------------------------------------------

-module(business_servers_app).

-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    business_servers_sup:start_link().

stop(_State) ->
    ok.

%% internal functions
