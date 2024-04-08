module GitHub exposing (getUser, oAuthLoginUrl)

import Http
import Json.Decode
import Url exposing (Protocol(..), Url)
import Url.Builder exposing (string)


oAuthLoginUrl : Url -> String
oAuthLoginUrl myUrl =
    Url.Builder.crossOrigin gitHubPrePath
        [ "login", "oauth", "authorize" ]
        [ string "client_id" clientId
        , string "redirect_uri" (replacePath myUrl "/oauth/callback/github" |> Url.toString)
        ]


getUser : String -> (Result Http.Error Json.Decode.Value -> msg) -> Cmd msg
getUser token msg =
    Http.request
        { method = "GET"
        , headers =
            -- GitHub requires the "User-Agent" header.
            [ Http.header "User-Agent" "elm-on-shuttle"
            , Http.header "Authorization" <| "Bearer " ++ token
            ]
        , url = Url.Builder.crossOrigin apiPrePath [ "user" ] []
        , body = Http.emptyBody
        , expect = Http.expectJson msg Json.Decode.value
        , timeout = Nothing
        , tracker = Nothing
        }



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
