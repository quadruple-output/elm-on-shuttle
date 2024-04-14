module GitHub exposing (getUser, oAuthLoginUrl)

import Http
import Json.Decode as Decode exposing (Decoder)
import RemoteData exposing (WebData)
import Url exposing (Protocol(..), Url)
import Url.Builder exposing (string)
import User exposing (UserData)


oAuthLoginUrl : Url -> String
oAuthLoginUrl myUrl =
    Url.Builder.crossOrigin gitHubPrePath
        [ "login", "oauth", "authorize" ]
        [ string "client_id" clientId
        , string "redirect_uri" (replacePath myUrl "/oauth/callback/github" |> Url.toString)
        ]


getUser : String -> (WebData UserData -> msg) -> Cmd msg
getUser token webDataToMsg =
    Http.request
        { method = "GET"
        , headers =
            -- GitHub requires the "User-Agent" header.
            [ Http.header "User-Agent" "elm-on-shuttle"
            , Http.header "Authorization" <| "Bearer " ++ token
            ]
        , url = Url.Builder.crossOrigin apiPrePath [ "user" ] []
        , body = Http.emptyBody
        , expect = Http.expectJson (RemoteData.fromResult >> webDataToMsg) decodeUserData
        , timeout = Nothing
        , tracker = Nothing
        }


decodeUserData : Decoder UserData
decodeUserData =
    Decode.map
        UserData
        (Decode.field "name" Decode.string)



-- Private helpers --


clientId : String
clientId =
    "Iv1.b5ba4dcd32da9063"


apiPrePath : String
apiPrePath =
    "https://api.github.com"


gitHubPrePath : String
gitHubPrePath =
    "https://github.com"


replacePath : Url -> String -> Url
replacePath url newPath =
    { url | path = newPath, query = Nothing, fragment = Nothing }
