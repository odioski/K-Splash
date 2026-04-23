
.pragma library

var REFERRAL_SOURCE = "k_unsplash_widget";
var REFERRAL_MEDIUM = "referral";

function normalizedText(value) {
    return value ? String(value).trim() : "";
}

function appendQueryParameters(url, params) {
    if (!params || params.length === 0) {
        return url;
    }

    return url + (url.indexOf("?") === -1 ? "?" : "&") + params.join("&");
}

function buildUnsplashRequestUrl(config) {
    var base = "https://api.unsplash.com/photos/random";
    var params = [];
    var category = normalizedText(config.category);

    if (category.length > 0) {
        params.push("query=" + encodeURIComponent(category));
    }
    params.push("orientation=landscape");
    params.push("content_filter=high");

    return base + "?" + params.join("&");
}

function buildUnsplashUrl(config) {
    return buildUnsplashRequestUrl(config);
}

function buildImageUrl(photo, config) {
    var urls = photo && photo.urls ? photo.urls : {};
    var baseUrl = urls.raw || urls.full || urls.regular || "";
    var params = [
        "auto=format",
        "fm=jpg",
        "q=80"
    ];

    if (!baseUrl) {
        return "";
    }

    if (config.resolutionWidth > 0) {
        params.push("w=" + encodeURIComponent(config.resolutionWidth));
    }
    if (config.resolutionHeight > 0) {
        params.push("h=" + encodeURIComponent(config.resolutionHeight));
    }
    if (config.resolutionWidth > 0 && config.resolutionHeight > 0) {
        params.push("fit=crop");
        params.push("crop=entropy");
    }

    return appendQueryParameters(baseUrl, params);
}

function buildAttributionUrl(url) {
    if (!url) {
        return "";
    }

    return appendQueryParameters(url, [
        "utm_source=" + encodeURIComponent(REFERRAL_SOURCE),
        "utm_medium=" + encodeURIComponent(REFERRAL_MEDIUM)
    ]);
}

function escapeHtml(value) {
    return String(value)
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;");
}

function buildAttributionMarkup(photo) {
    var photographerName = normalizedText(photo && photo.user ? photo.user.name : "")
        || "Unsplash photographer";
    var photographerUrl = buildAttributionUrl(photo && photo.user && photo.user.links
        ? photo.user.links.html
        : "");
    var photoPageUrl = buildAttributionUrl(photo && photo.links ? photo.links.html : "https://unsplash.com");
    var photographerLabel = photographerUrl
        ? "<a href=\"" + escapeHtml(photographerUrl) + "\">" + escapeHtml(photographerName) + "</a>"
        : escapeHtml(photographerName);
    var unsplashLabel = photoPageUrl
        ? "<a href=\"" + escapeHtml(photoPageUrl) + "\">Unsplash</a>"
        : "Unsplash";

    return "Photo by " + photographerLabel + " on " + unsplashLabel;
}

function extractPhotoDetails(photo, config) {
    return {
        attributionMarkup: buildAttributionMarkup(photo),
        description: normalizedText(photo ? photo.description : "")
            || normalizedText(photo ? photo.alt_description : ""),
        downloadLocation: photo && photo.links ? (photo.links.download_location || "") : "",
        imageUrl: buildImageUrl(photo, config),
        photoId: normalizedText(photo ? photo.id : "")
    };
}

function buildApiErrorMessage(responseText, status) {
    var message = status ? "HTTP " + status : "Unsplash request failed";

    if (!responseText) {
        return message;
    }

    try {
        var json = JSON.parse(responseText);
        if (json.errors && json.errors.length > 0) {
            return message + ": " + json.errors.join(", ");
        }
    } catch (e) {
        // Ignore JSON parse failures and keep the HTTP status message.
    }

    return message;
}

function shellQuote(value) {
    return "'" + String(value).replace(/'/g, "'\"'\"'") + "'";
}

function buildCommand(imageUrl) {
    var filePath = "/tmp/k-unsplash-wallpaper.jpg";
    var qdbusScript =
        "var Desktops = desktops(); " +
        "for (var i = 0; i < Desktops.length; i++) { " +
        "  var d = Desktops[i]; " +
        "  d.wallpaperPlugin = 'org.kde.image'; " +
        "  d.currentConfigGroup = ['Wallpaper','org.kde.image','General']; " +
        "  d.writeConfig('Image','file://" + filePath + "'); " +
        "}";

    var script =
        "curl -fL " + shellQuote(imageUrl) + " -o " + shellQuote(filePath) +
        " && if command -v qdbus6 >/dev/null 2>&1; then QDBUS=qdbus6; " +
        "elif command -v qdbus >/dev/null 2>&1; then QDBUS=qdbus; " +
        "else echo " + shellQuote("qdbus command not found") + " >&2; exit 127; fi" +
        " && \"$QDBUS\" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
        + shellQuote(qdbusScript);

    return "bash -c " + shellQuote(script);
}
