--
-- This is an adaptation (and massive simplification) of
-- https://github.com/billstclair/elm-oauth-middleware/blob/3.0.0/example/example.elm
--


module Pages.SignIn exposing (Model, Msg, page)

import Browser exposing (UrlRequest)
import Dict
import Effect exposing (Effect)
import Element exposing (..)
import Element.Background as Background
import Element.Font as Font
import Element.Region exposing (heading)
import GitHub
import Http
import Json.Decode exposing (Value)
import Json.Encode
import MyElements as My
import Page exposing (Page)
import Platform.Cmd as Cmd
import Route exposing (Route)
import Route.Path
import Shared
import Shared.Msg exposing (Msg(..))
import ToString
import Url exposing (Url)
import Url.Builder as Builder
import View exposing (View)


oAuthRedirectUrl : Url -> Url
oAuthRedirectUrl url =
    { url | path = "/oauth/callback/github", query = Nothing, fragment = Nothing }


page : Shared.Model -> Route () -> Page Model Msg
page _ route =
    Page.new
        { init = init route.url
        , subscriptions = \_ -> Sub.none
        , update = update
        , view = view
        }


type alias Model =
    { url : Url
    , token : Maybe String
    , state : Maybe String
    , msg : Maybe String
    , replyType : String
    , reply : Maybe Value
    , api : Api
    , receivedMsg : List Msg
    }


type Msg
    = OnUrlRequest UrlRequest
    | OnUrlChange Url
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


type alias Api =
    { getUser : String
    }


init : Url -> () -> ( Model, Effect Msg )
init url _ =
    ( { url = url
      , token = url.fragment
      , state = Nothing
      , msg = Nothing
      , replyType = "Token"
      , reply = Nothing
      , api = { getUser = "/user" }
      , receivedMsg = []
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
            let
                apiUrl =
                    GitHub.oAuth.apiUrl

                req =
                    Http.request
                        { method = "GET"
                        , headers =
                            -- GitHub requires the "User-Agent" header.
                            [ Http.header "User-Agent" "elm-on-shuttle"
                            , Http.header "Authorization" <| "Bearer " ++ token
                            ]
                        , url = { apiUrl | path = model.api.getUser } |> Url.toString
                        , body = Http.emptyBody
                        , expect = Http.expectJson ReceiveUser Json.Decode.value
                        , timeout = Nothing
                        , tracker = Nothing
                        }
            in
            ( model, req )


update : Msg -> Model -> ( Model, Effect Msg )
update msg m =
    let
        model =
            { m | receivedMsg = m.receivedMsg ++ [ msg ] }
    in
    case msg of
        OnUrlRequest _ ->
            ( model, Effect.none )

        OnUrlChange _ ->
            ( model, Effect.none )

        Login ->
            let
                oAuthUrl =
                    GitHub.oAuth.authorizationUrl

                query =
                    [ Builder.string "client_id" GitHub.oAuth.clientId
                    , Builder.string "redirect_uri" <|
                        Url.toString
                            (oAuthRedirectUrl model.url)
                    ]
                        |> Builder.toQuery
                        |> String.dropLeft 1
            in
            ( model, Effect.loadExternalUrl <| Url.toString { oAuthUrl | query = Just query } )

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
                        , msg =
                            Just <|
                                "Hello "
                                    ++ (Result.withDefault "unknown Person" <|
                                            Json.Decode.decodeValue
                                                (Json.Decode.field "name" Json.Decode.string)
                                                reply
                                       )
                      }
                    , Effect.none
                    )


view : Model -> View Msg
view model =
    { title = "Elm on Shuttle"
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
        [ el [ heading 1, Font.heavy ] <| text "OAuth Login Page"
        , paragraph [] [ text "Authorization Provider is GitHub" ]
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
                model.receivedMsg


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
