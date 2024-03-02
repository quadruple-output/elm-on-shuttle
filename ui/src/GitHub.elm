module GitHub exposing (..)

import Url exposing (Protocol(..), Url)


oAuth : { authorizationUrl : Url, tokenUrl : Url, apiUrl : Url, clientId : String }
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
    { authorizationUrl = { baseUrl | path = "/login/oauth/authorize" }
    , tokenUrl = { baseUrl | path = "/login/oauth/access_token" }
    , apiUrl = { baseUrl | host = "api.github.com" }
    , clientId = "Iv1.b5ba4dcd32da9063"
    }
