--
-- This is an adaptation of
-- https://github.com/billstclair/elm-oauth-middleware/blob/3.0.0/example/example.elm
--


module Pages.SignIn exposing (Model, Msg, page)

import Browser exposing (UrlRequest)
import Dict exposing (Dict)
import Effect exposing (Effect)
import Element exposing (..)
import Element.Background as Background
import Element.Font as Font
import Element.Region exposing (heading)
import Http
import Json.Decode exposing (Value)
import Json.Encode
import MyElements as My
import OAuthMiddleware
    exposing
        ( Authorization
        , ResponseToken
        , TokenAuthorization
        , TokenState(..)
        , authorize
        , locationToRedirectBackUri
        , receiveTokenAndState
        )
import OAuthMiddleware.EncodeDecode exposing (authorizationsEncoder, responseTokenEncoder)
import Page exposing (Page)
import Platform.Cmd as Cmd
import Route exposing (Route)
import Route.Path
import Shared
import Shared.Msg exposing (Msg(..))
import ToString
import Url exposing (Url)
import View exposing (View)


page : Shared.Model -> Route () -> Page Model Msg
page _ route =
    Page.new
        { init = init route.url
        , subscriptions = \_ -> Sub.none
        , update = update
        , view = view
        }


type alias Model =
    { authorization : Maybe Authorization
    , token : Maybe ResponseToken
    , state : Maybe String
    , msg : Maybe String
    , replyType : String
    , reply : Maybe Value
    , redirectBackUri : String
    , provider : String
    , authorizations : Dict String Authorization
    , tokenAuthorization : Maybe TokenAuthorization
    , api : Maybe Api
    , received_msg : List Msg
    }


type Msg
    = OnUrlRequest UrlRequest
    | OnUrlChange Url
    | ReceiveAuthorizations (Result Http.Error (List Authorization))
    | Login
    | GetUser
    | ReceiveUser (Result Http.Error Value)


msgToString : Msg -> String
msgToString msg =
    case msg of
        Login ->
            "Login"

        OnUrlRequest _ ->
            "OnUrlRequest _"

        OnUrlChange _ ->
            "OnUrlChange _"

        ReceiveAuthorizations _ ->
            "ReceiveAuthorizations _"

        GetUser ->
            "GetUser"

        ReceiveUser user_result ->
            "ReceiveUser "
                ++ (case user_result of
                        Ok user ->
                            "Ok " ++ Json.Encode.encode 0 user

                        Err err ->
                            "Error " ++ ToString.httpError err
                   )


{-| GitHub requires the "User-Agent" header.
-}
userAgentHeader : Http.Header
userAgentHeader =
    Http.header "User-Agent" "elm-on-shuttle"


type alias Api =
    { getUser : String
    }


apis : Dict String Api
apis =
    Dict.fromList
        [ ( "GitHub", { getUser = "user" } ) ]


init : Url -> () -> ( Model, Effect Msg )
init url _ =
    let
        ( token, state, msg ) =
            case receiveTokenAndState url of
                TokenAndState tok stat ->
                    ( Just tok, stat, Nothing )

                TokenErrorAndState m stat ->
                    ( Nothing, stat, Just m )

                TokenDecodeError m ->
                    ( Nothing, Nothing, Just m )

                NoToken ->
                    ( Nothing, Nothing, Nothing )
    in
    ( lookupProvider
        { authorization = Nothing
        , token = token
        , state = state
        , msg = msg
        , replyType = "Token"
        , reply =
            Maybe.map responseTokenEncoder token

        -- , redirectBackUri = locationToRedirectBackUri url
        , redirectBackUri = Url.toString { url | query = Nothing, fragment = Nothing }
        , authorizations =
            Dict.fromList
                [ ( "GitHub"
                  , { name = "GitHub"
                    , authorizationUri = "https://github.com/login/oauth/authorize"
                    , tokenUri = "https://github.com/login/oauth/access_token"
                    , apiUri = "https://api.github.com/"
                    , clientId = "Iv1.b5ba4dcd32da9063"
                    , redirectUri =
                        Url.toString
                            { url
                                | path = "/oauth/callback/github"
                                , query = Nothing
                                , fragment = Nothing
                            }
                    , scopes = Dict.fromList [ ( "user", "user" ) ]
                    }
                  )
                ]
        , provider =
            case state of
                Just p ->
                    p

                Nothing ->
                    "GitHub"
        , tokenAuthorization = Nothing
        , api = Nothing
        , received_msg = []
        }
    , Effect.replaceRoute { path = Route.Path.SignIn, query = Dict.empty, hash = Nothing }
    )


getUser : Model -> ( Model, Cmd Msg )
getUser model =
    case model.token of
        Nothing ->
            ( { model
                | msg = Just "You must login before getting user information."
              }
            , Cmd.none
            )

        Just token ->
            case ( model.api, model.authorization ) of
                ( Just api, Just auth ) ->
                    let
                        url =
                            auth.apiUri ++ api.getUser

                        req =
                            Http.request
                                { method = "GET"
                                , headers = OAuthMiddleware.use token [ userAgentHeader ]
                                , url = url
                                , body = Http.emptyBody
                                , expect = Http.expectJson ReceiveUser Json.Decode.value
                                , timeout = Nothing
                                , tracker = Nothing
                                }
                    in
                    ( model, req )

                _ ->
                    ( { model | msg = Just "No known API." }
                    , Cmd.none
                    )


lookupProvider : Model -> Model
lookupProvider model =
    let
        authorization =
            case Dict.get model.provider model.authorizations of
                Nothing ->
                    Maybe.map (\( _, auth ) -> auth) (List.head <| Dict.toList model.authorizations)

                Just auth ->
                    Just auth
    in
    case authorization of
        Nothing ->
            model

        Just auth ->
            case List.head <| Dict.toList auth.scopes of
                Nothing ->
                    model

                Just ( _, scope ) ->
                    let
                        provider =
                            auth.name

                        api =
                            Dict.get provider apis
                    in
                    { model
                        | provider = provider
                        , tokenAuthorization =
                            Just
                                { authorization = auth
                                , scope = [ scope ]
                                , state = Just model.provider
                                , redirectBackUri = model.redirectBackUri
                                }
                        , api = api
                        , authorization = authorization
                    }


update : Msg -> Model -> ( Model, Effect Msg )
update msg m =
    let
        model =
            { m | received_msg = m.received_msg ++ [ msg ] }
    in
    case msg of
        OnUrlRequest _ ->
            ( model, Effect.none )

        OnUrlChange _ ->
            ( model, Effect.none )

        ReceiveAuthorizations result ->
            case result of
                Err err ->
                    ( { model | msg = Just <| ToString.httpError err }, Effect.none )

                Ok authorizations ->
                    let
                        ( replyType, reply ) =
                            case ( model.token, model.msg ) of
                                ( Nothing, Nothing ) ->
                                    ( "Authorizations"
                                    , Just <| authorizationsEncoder authorizations
                                    )

                                _ ->
                                    ( model.replyType, model.reply )
                    in
                    ( lookupProvider
                        { model
                            | authorizations =
                                Dict.fromList <|
                                    List.map (\a -> ( a.name, a )) authorizations
                            , replyType = replyType
                            , reply = reply
                        }
                    , Effect.none
                    )

        Login ->
            case model.tokenAuthorization of
                Nothing ->
                    ( { model | msg = Just "No provider selected." }
                    , Effect.none
                    )

                Just authorization ->
                    case authorize authorization of
                        Nothing ->
                            ( { model
                                | msg =
                                    Just
                                        ("Bad Uri in authorization (one of "
                                            ++ authorization.authorization.authorizationUri
                                            ++ ", "
                                            ++ authorization.authorization.redirectUri
                                        )
                              }
                            , Effect.none
                            )

                        Just url ->
                            ( model, Effect.loadExternalUrl <| Url.toString url )

        GetUser ->
            Tuple.mapSecond Effect.sendCmd (getUser model)

        ReceiveUser result ->
            case result of
                Err err ->
                    ( { model | reply = Nothing, msg = Just <| ToString.httpError err }
                    , Effect.none
                    )

                Ok reply ->
                    ( { model
                        | replyType = "API Response"
                        , reply = Just reply
                        , msg = Nothing
                      }
                    , Effect.none
                    )


view : Model -> View Msg
view model =
    { title = "OAuthMiddleware Example"
    , attributes = [ height fill, width fill, padding 10 ]
    , element =
        column [ width fill ] <|
            viewMain
                :: viewLastErrorOrResponse model
                ++ [ viewMessageLog model ]
    }


viewMain : Element Msg
viewMain =
    column [ centerX ]
        [ el [ heading 1 ] <| text "OAuthMiddleware Example"
        , paragraph [] [ text "Provider: GitHub" ]
        , column [ centerX ]
            [ My.button [ centerX ] "Login" Login
            , My.button [ centerX ] "Get User" GetUser
            ]
        ]


viewMessageLog : Model -> Element msg
viewMessageLog model =
    column [ paddingEach { top = 10, right = 0, bottom = 0, left = 0 } ] <|
        text "--- Message Log: ---"
            :: List.map
                (\msg -> Element.paragraph [] [ text <| msgToString msg ])
                model.received_msg


viewLastErrorOrResponse : Model -> List (Element msg)
viewLastErrorOrResponse model =
    case ( model.msg, model.reply ) of
        ( Just msg, _ ) ->
            [ el [ paddingEach { top = 10, right = 0, bottom = 0, left = 0 } ] <|
                Element.paragraph [] <|
                    [ el [ Background.color (rgb 1 0 0), Font.color (rgb 1 1 0) ] <|
                        text "Error:"
                    , el [ Font.color (rgb 1 0 0) ] <|
                        text (" " ++ msg)
                    ]
            ]

        ( Nothing, Just reply ) ->
            [ el [ paddingEach { top = 10, right = 0, bottom = 0, left = 0 } ] <|
                Element.paragraph [] <|
                    [ el [ Background.color (rgb 0 0 1), Font.color (rgb 1 1 0) ] <|
                        text "Reply:"
                    , el [ Font.color (rgb 0 0 1) ] <|
                        text (model.replyType ++ ":\n" ++ Json.Encode.encode 2 reply)
                    ]
            ]

        ( Nothing, Nothing ) ->
            []
