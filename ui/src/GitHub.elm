module GitHub exposing (loginUrl, oAuth)

import Url exposing (Protocol(..), Url)
import Url.Builder exposing (string)


oAuth : { tokenUrl : Url, apiUrl : Url, clientId : String }
oAuth =
    let
        baseUrl : Url
        baseUrl =
            { protocol = Https
            , host = "github.com"
            , port_ = Nothing
            , path = "/"
            , query = Nothing
            , fragment = Nothing
            }
    in
    { tokenUrl = { baseUrl | path = "/login/oauth/access_token" }
    , apiUrl = { baseUrl | host = "api.github.com" }
    , clientId = "Iv1.b5ba4dcd32da9063"
    }


loginUrl : Url -> String
loginUrl myUrl =
    Url.Builder.crossOrigin gitHubPrePath
        [ "login", "oauth", "authorize" ]
        [ string "client_id" oAuth.clientId
        , string "redirect_uri" (replacePath myUrl "/oauth/callback/github" |> Url.toString)
        ]



-- Private helpers --


gitHubPrePath : String
gitHubPrePath =
    "https://github.com"


replacePath : Url -> String -> Url
replacePath url newPath =
    { url | path = newPath, query = Nothing, fragment = Nothing }
