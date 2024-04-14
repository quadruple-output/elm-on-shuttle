// from https://www.w3schools.com/js/js_cookies.asp
function getCookie(cname) {
  const nameWithEq = cname + "=";
  const decodedCookie = decodeURIComponent(document.cookie);
  const ca = decodedCookie.split(";");
  for (let i = 0; i < ca.length; i++) {
    let c = ca[i];
    while (c.charAt(0) == " ") {
      c = c.substring(1);
    }
    if (c.indexOf(nameWithEq) == 0) {
      return c.substring(nameWithEq.length, c.length);
    }
  }
  return "";
}

// This is called BEFORE your Elm app starts up
//
// The value returned here will be passed as flags
// into your `Shared.init` function.
export const flags = ({ _env }) => {
  const token = getCookie("github-access-token");
  if (token == "") {
    return {};
  } else {
    return {
      githubAccessToken: token
    };
  }
};

// This is called AFTER your Elm app starts up
//
// Here you can work with `app.ports` to send messages
// to your Elm application, or subscribe to incoming
// messages from Elm
export const onReady = ({ _app, _env }) => {
};
