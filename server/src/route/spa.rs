use ::std::path::PathBuf;
use ::tower_http::services::{ServeDir, ServeFile};

pub(crate) fn serve_dir(directory_path: PathBuf) -> ServeDir<ServeFile> {
    // The served directory contains a single page app (SPA), and 'index.html' is the HTML file to
    // be served by default. Even URLs to (virtual) sub-paths must be resolved to the same app.
    // Routing to the virtual path will be done by the JavaScript of the SPA.
    let mut path_to_index_html = directory_path.clone();
    path_to_index_html.push("index.html");
    ServeDir::new(directory_path).fallback(ServeFile::new(path_to_index_html))
}
