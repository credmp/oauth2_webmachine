%% @author https://github.com/IvanMartinez
%% @copyright 2013 author.
%% @doc OAuth2 backend functions.
%% Distributed under the terms and conditions of the Apache 2.0 license.

-module(oauth2_ets_backend).

%%% API
-export([start/0, stop/0, add_user/2, add_user/3, delete_user/1, add_client/4, 
         delete_client/1]).

%%% OAuth2 backend functionality
-export([authenticate_username_password/2, authenticate_client/2, 
         associate_access_token/2, resolve_access_token/1, 
         get_client_identity/1, get_redirection_uri/1, verify_resowner_scope/2,
         verify_client_scope/2
        ]).

-define(ACCESS_TOKEN_TABLE, access_tokens).
-define(USER_TABLE, users).
-define(CLIENT_TABLE, clients).
-define(REQUEST_TABLE, requests).

-define(TABLES, [?ACCESS_TOKEN_TABLE,
                 ?USER_TABLE,
                 ?CLIENT_TABLE,
                 ?REQUEST_TABLE]).

-record(client, {
          client_id     :: binary(),
          client_secret :: binary(),
          redirect_uri  :: binary(),
          scope         :: [binary()]
         }).

-record(user, {
          username  :: binary(),
          password  :: binary(),
          scope     :: [binary()]
         }).

%%%===================================================================
%%% API
%%%===================================================================

start() ->
    lists:foreach(fun(Table) ->
                          ets:new(Table, [named_table, public])
                  end,
                  ?TABLES).

stop() ->
    lists:foreach(fun ets:delete/1, ?TABLES).

add_user(Username, Password, Scope) ->
    put(?USER_TABLE, Username, #user{username = Username, password = Password, 
                                     scope = Scope}).

add_user(Username, Password) ->
    add_user(Username, Password, []).

delete_user(Username) ->
    delete(?USER_TABLE, Username).

add_client(Id, Secret, RedirectUri, Scope) ->
    put(?CLIENT_TABLE, Id, #client{client_id = Id,
                                   client_secret = Secret,
                                   redirect_uri = RedirectUri,
                                   scope = Scope
                                  }).

delete_client(Id) ->
    delete(?CLIENT_TABLE, Id).

%%%===================================================================
%%% OAuth2 backend functions
%%%===================================================================

authenticate_username_password(Username, Password) ->
    case get(?USER_TABLE, Username) of
        {ok, #user{password = Password} = Identity} ->
            {ok, Identity};
        {ok, #user{password = _WrongPassword}} ->
            {error, badpass};
        _ ->
            {error, notfound}
    end.

authenticate_client(ClientId, ClientSecret) ->
    case get(?CLIENT_TABLE, ClientId) of
        {ok, #client{client_secret = ClientSecret} = Identity} ->
            {ok, Identity};
        {ok, #client{client_secret = _WrongSecret}} ->
            {error, badsecret};
        _ ->
            {error, notfound}
    end.

associate_access_token(AccessToken, Context) ->
    put(?ACCESS_TOKEN_TABLE, AccessToken, Context),
    ok.

resolve_access_token(AccessToken) ->
    %% The case trickery is just here to make sure that
    %% we don't propagate errors that cannot be legally
    %% returned from this function according to the spec.
    case get(?ACCESS_TOKEN_TABLE, AccessToken) of
        Value = {ok, _} ->
            Value;
        Error = {error, notfound} ->
            Error
    end.

get_redirection_uri(ClientId) ->
    case get(?CLIENT_TABLE, ClientId) of
        {ok, #client{redirect_uri = RedirectUri}} ->
            {ok, RedirectUri};
        Error = {error, notfound} ->
            Error
    end.

get_client_identity(ClientId) ->
    case get(?CLIENT_TABLE, ClientId) of
        {ok, Identity} ->
            {ok, Identity};
        Error = {error, notfound} ->
            Error
    end.

verify_resowner_scope(#user{scope = RegisteredScope}, undefined) ->
    {ok, RegisteredScope};
verify_resowner_scope(#user{scope = _RegisteredScope}, []) ->
    {ok, []};
verify_resowner_scope(#user{scope = []}, _Scope) ->
    {error, invalid_scope};
verify_resowner_scope(#user{scope = RegisteredScope}, Scope) ->
    case oauth2_priv_set:is_subset(oauth2_priv_set:new(Scope), 
                                   oauth2_priv_set:new(RegisteredScope)) of
        true ->
            {ok, Scope};
        false ->
            {error, invalid_scope}
    end.

verify_client_scope(#client{scope = RegisteredScope}, undefined) ->
    {ok, RegisteredScope};
verify_client_scope(#client{scope = _RegisteredScope}, []) ->
    {ok, []};
verify_client_scope(#client{scope = []}, _Scope) ->
    {error, invalid_scope};
verify_client_scope(#client{scope = RegisteredScope}, Scope) ->
    case oauth2_priv_set:is_subset(oauth2_priv_set:new(Scope), 
                                   oauth2_priv_set:new(RegisteredScope)) of
        true ->
            {ok, Scope};
        false ->
            {error, invalid_scope}
    end.

%%%===================================================================
%%% Internal functions
%%%===================================================================

get(Table, Key) ->
    case ets:lookup(Table, Key) of
        [] ->
            {error, notfound};
        [{_Key, Value}] ->
            {ok, Value}
    end.

put(Table, Key, Value) ->
    ets:insert(Table, {Key, Value}).

delete(Table, Key) ->
    ets:delete(Table, Key).