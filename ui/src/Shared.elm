module Shared exposing
    ( Flags, decoder
    , Model, Msg
    , init, update, subscriptions
    )

{-|

@docs Flags, decoder
@docs Model, Msg
@docs init, update, subscriptions

-}

import Effect exposing (Effect)
import GitHub
import Json.Decode
import RemoteData exposing (RemoteData(..), WebData)
import Route exposing (Route)
import Shared.Model
import Shared.Msg
import User exposing (UserData)



-- FLAGS


type alias Flags =
    { githubAccessToken : Maybe String
    }


decoder : Json.Decode.Decoder Flags
decoder =
    Json.Decode.map
        Flags
        (Json.Decode.maybe <| Json.Decode.field "githubAccessToken" Json.Decode.string)



-- INIT


type alias Model =
    Shared.Model.Model


init : Result Json.Decode.Error Flags -> Route () -> ( Model, Effect Msg )
init flagsResult _ =
    let
        model =
            initModel

        flags =
            case flagsResult of
                Ok f ->
                    f

                Err _ ->
                    -- let
                    --     _ = Debug.log "Error decoding flags" (Json.Decode.errorToString err)
                    -- in
                    { githubAccessToken = Nothing }

        effect =
            case flags.githubAccessToken of
                Just token ->
                    Effect.sendCmd (GitHub.getUser token Shared.Msg.GotUser)

                Nothing ->
                    Effect.none
    in
    ( { model | githubAccessToken = flags.githubAccessToken }
    , effect
    )


initModel : Model
initModel =
    { githubAccessToken = Nothing
    , user = NotAsked
    }



-- UPDATE


type alias Msg =
    Shared.Msg.Msg


update : Route () -> Msg -> Model -> ( Model, Effect Msg )
update _ msg model =
    case msg of
        Shared.Msg.GotUser webUserData ->
            processGotUser webUserData model


processGotUser : WebData UserData -> Model -> ( Model, Effect Msg )
processGotUser webdata model =
    ( model
    , Effect.none
    )



-- SUBSCRIPTIONS


subscriptions : Route () -> Model -> Sub Msg
subscriptions _ _ =
    Sub.none
