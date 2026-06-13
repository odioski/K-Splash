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

function encodePathSegments(path) {
    return String(path || "")
        .split("/")
        .map(function(segment) {
            return encodeURIComponent(segment);
        })
        .join("/");
}

function parseSearchTerms(config) {
    var terms = [];
    var category = normalizedText(config ? config.category : "");
    var customCategories = normalizedText(config ? config.customCategories : "");

    if (category.length > 0 && category !== "collections") {
        terms.push(category);
    }

    if (customCategories.length > 0) {
        customCategories.split(",").forEach(function(term) {
            var normalized = normalizedText(term);
            if (normalized.length > 0 && terms.indexOf(normalized) === -1) {
                terms.push(normalized);
            }
        });
    }

    return terms;
}

function parseUserCollections(config) {
    var collections = [];
    var rawCollections = normalizedText(config ? config.userCollections : "");

    if (rawCollections.length === 0) {
        return collections;
    }

    rawCollections.split(",").forEach(function(collection) {
        var normalized = normalizedText(collection);
        var urlMatch;

        if (normalized.length === 0) {
            return;
        }

        urlMatch = normalized.match(/unsplash\.com\/collections\/([^?#\s]+)/i);
        if (urlMatch && urlMatch[1]) {
            normalized = urlMatch[1];
        }

        normalized = normalized.replace(/^\/?collections\//, "");
        normalized = normalized.replace(/[?#].*$/, "");
        normalized = normalized.replace(/^\/+|\/+$/g, "");

        if (normalized.length > 0 && collections.indexOf(normalized) === -1) {
            collections.push(normalized);
        }
    });

    return collections;
}

function buildUnsplashDomUrl(config, offset) {
    var collections = parseUserCollections(config);
    var terms = parseSearchTerms(config);
    var category = normalizedText(config ? config.category : "");
    var username = normalizedText(config ? config.username : "");
    var index = offset || 0;
    var sources = [];
    var source;

    if (category === "collections" && collections.length === 0 && username.length > 0) {
        sources.push({
            type: "userCollections",
            value: username.replace(/^@/, "")
        });
    }
    collections.forEach(function(collection) {
        sources.push({
            type: "collection",
            value: collection
        });
    });
    terms.forEach(function(term) {
        sources.push({
            type: "search",
            value: term
        });
    });
    if (terms.indexOf("wallpaper") === -1) {
        sources.push({
            type: "search",
            value: "wallpaper"
        });
    }

    source = sources[index % sources.length];
    if (source.type === "userCollections") {
        return "https://unsplash.com/@" + encodeURIComponent(source.value) + "/collections";
    }
    if (source.type === "collection") {
        return "https://unsplash.com/collections/" + encodePathSegments(source.value);
    }

    return "https://unsplash.com/s/photos/" + encodeURIComponent(source.value);
}

function countDomSources(config) {
    var collections = parseUserCollections(config);
    var terms = parseSearchTerms(config);
    var category = normalizedText(config ? config.category : "");
    var username = normalizedText(config ? config.username : "");
    var count = collections.length + terms.length;

    if (category === "collections" && collections.length === 0 && username.length > 0) {
        count++;
    }

    return terms.indexOf("wallpaper") === -1 ? count + 1 : count;
}

function htmlDecode(value) {
    return String(value || "")
        .replace(/\\u0026/g, "&")
        .replace(/&amp;/g, "&")
        .replace(/&quot;/g, "\"")
        .replace(/&#x27;/g, "'")
        .replace(/&#39;/g, "'")
        .replace(/&lt;/g, "<")
        .replace(/&gt;/g, ">");
}

function buildDomImageUrl(baseUrl, config) {
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

function extractPhotoIdFromImageUrl(url) {
    var match = String(url || "").match(/\/photo-([^?]+)/);

    return match && match[1] ? safeFileSegment(match[1]) : "dom";
}

function extractDomDescription(context) {
    var altMatch = context.match(/alt="([^"]+)"/);
    if (altMatch && altMatch[1]) {
        var altText = normalizedText(htmlDecode(altMatch[1]));
        if (altText.length > 0 && altText !== "Download" && altText.indexOf("Go to ") !== 0) {
            return altText;
        }
    }

    var ariaMatch = context.match(/aria-label="([^"]+)"/);
    if (ariaMatch && ariaMatch[1]) {
        var ariaText = normalizedText(htmlDecode(ariaMatch[1]));
        if (ariaText.length > 0 && ariaText.indexOf("Go to ") !== 0) {
            return ariaText;
        }
    }

    return "";
}

function stripHtml(value) {
    return normalizedText(htmlDecode(String(value || "").replace(/<[^>]*>/g, " ")));
}

function decodeJsonString(value) {
    return htmlDecode(String(value || "")
        .replace(/\\"/g, "\"")
        .replace(/\\\//g, "/")
        .replace(/\\n/g, " ")
        .replace(/\\t/g, " "));
}

function extractJsonStringField(context, fieldName) {
    var regex = new RegExp("\"" + fieldName + "\"\\s*:\\s*\"((?:\\\\.|[^\"\\\\])*)\"");
    var match = String(context || "").match(regex);

    return match && match[1] ? normalizedText(decodeJsonString(match[1])) : "";
}

function buildPhotographer(name, username) {
    var safeUsername = normalizedText(username);
    var safeName = normalizedText(name) || safeUsername;

    return {
        name: safeName,
        username: safeUsername,
        profileUrl: safeUsername.length > 0 ? "https://unsplash.com/@" + safeUsername : ""
    };
}

function extractDomPhotographer(context) {
    var profileMatch = context.match(/(?:href|to)="\/@([a-zA-Z0-9_.-]+)"[^>]*>([\s\S]{0,500}?)<\/a>/);
    var labelMatch;
    var userBlockMatch;
    var username;
    var name;

    if (profileMatch && profileMatch[1]) {
        return buildPhotographer(stripHtml(profileMatch[2]), profileMatch[1]);
    }

    labelMatch = context.match(/Go to ([^"']+)'s profile/);
    if (labelMatch && labelMatch[1]) {
        username = extractJsonStringField(context, "username");
        return buildPhotographer(normalizedText(htmlDecode(labelMatch[1])), username);
    }

    userBlockMatch = context.match(/"user"\s*:\s*\{[\s\S]{0,3000}?\}/);
    if (userBlockMatch && userBlockMatch[0]) {
        username = extractJsonStringField(userBlockMatch[0], "username");
        name = extractJsonStringField(userBlockMatch[0], "name");

        if (name.length > 0 || username.length > 0) {
            return buildPhotographer(name, username);
        }
    }

    return {
        name: "Unsplash photographer",
        username: "",
        profileUrl: ""
    };
}

function buildDomAttributionMarkup(details) {
    var photographerName = normalizedText(details ? details.photographerName : "")
        || "Unsplash photographer";
    var photographerUsername = normalizedText(details ? details.photographerUsername : "");
    var photographerTag = photographerUsername.length > 0 ? "@" + photographerUsername : "";
    var photographerUrl = buildAttributionUrl(details ? details.photographerUrl : "");
    var photoPageUrl = buildAttributionUrl(details && details.photoPageUrl
        ? details.photoPageUrl
        : "https://unsplash.com");
    var photographerText = photographerTag.length > 0
        ? photographerName + " (" + photographerTag + ")"
        : photographerName;
    var photographerLabel = photographerUrl
        ? "<a href=\"" + escapeHtml(photographerUrl) + "\">" + escapeHtml(photographerText) + "</a>"
        : escapeHtml(photographerText);
    var unsplashLabel = photoPageUrl
        ? "<a href=\"" + escapeHtml(photoPageUrl) + "\">Unsplash</a>"
        : "Unsplash";

    // Unsplash credit should read "Photo by [photographer] on Unsplash";
    // do not replace "on Unsplash" with "by Unsplash".
    return "Photo by " + photographerLabel + " on " + unsplashLabel;
}

function extractDomPhotoDetails(html, config, offset) {
    var text = htmlDecode(html);
    var regex = /https:\/\/images\.unsplash\.com\/photo-[^"'<>\s)]+/g;
    var seen = {};
    var candidates = [];
    var match;
    var selected;
    var index;
    var start;
    var end;
    var context;
    var photographer;
    var photoPageMatch;

    while ((match = regex.exec(text)) !== null) {
        var imageUrl = match[0].split("?")[0];
        if (seen[imageUrl]) {
            continue;
        }
        seen[imageUrl] = true;
        candidates.push({
            imageUrl: imageUrl,
            sourceIndex: match.index
        });
    }

    if (candidates.length === 0) {
        return {
            attributionMarkup: "",
            description: "",
            downloadLocation: "",
            imageUrl: "",
            photoId: ""
        };
    }

    index = ((offset || 0) + Math.floor(Math.random() * candidates.length)) % candidates.length;
    selected = candidates[index];
    start = Math.max(0, selected.sourceIndex - 20000);
    end = Math.min(text.length, selected.sourceIndex + 20000);
    context = text.substring(start, end);
    photographer = extractDomPhotographer(context);
    photoPageMatch = context.match(/href="(\/photos\/[^"]+)"/);

    var details = {
        description: extractDomDescription(context),
        imageUrl: buildDomImageUrl(selected.imageUrl, config),
        photographerName: photographer.name,
        photographerUsername: photographer.username,
        photographerUrl: photographer.profileUrl,
        photoId: extractPhotoIdFromImageUrl(selected.imageUrl),
        photoPageUrl: photoPageMatch && photoPageMatch[1]
            ? "https://unsplash.com" + photoPageMatch[1]
            : "https://unsplash.com"
    };

    details.attributionMarkup = buildDomAttributionMarkup(details);
    details.downloadLocation = "";

    return details;
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
    var photographerUsername = normalizedText(photo && photo.user ? photo.user.username : "");
    var photographerTag = photographerUsername.length > 0 ? "@" + photographerUsername : "";
    var photographerUrl = buildAttributionUrl(photo && photo.user && photo.user.links
        ? photo.user.links.html
        : "");
    var photoPageUrl = buildAttributionUrl(photo && photo.links ? photo.links.html : "https://unsplash.com");
    var photographerText = photographerTag.length > 0
        ? photographerName + " (" + photographerTag + ")"
        : photographerName;
    var photographerLabel = photographerUrl
        ? "<a href=\"" + escapeHtml(photographerUrl) + "\">" + escapeHtml(photographerText) + "</a>"
        : escapeHtml(photographerText);
    var unsplashLabel = photoPageUrl
        ? "<a href=\"" + escapeHtml(photoPageUrl) + "\">Unsplash</a>"
        : "Unsplash";

    // Unsplash credit should read "Photo by [photographer] on Unsplash";
    // do not replace "on Unsplash" with "by Unsplash".
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
        if (json.message) {
            return message + ": " + json.message;
        }
    } catch (e) {
        // Ignore JSON parse failures and keep the HTTP status message.
    }

    return message;
}

function shouldRetryImageDownload(errorText) {
    var text = normalizedText(errorText);

    if (!text) {
        return false;
    }

    return /curl:\(22\)/.test(text)
        || /requested url returned error:\s*(403|404|410|429)\b/i.test(text)
        || /http\s*(403|404|410|429)\b/i.test(text);
}

function shellQuote(value) {
    return "'" + String(value).replace(/'/g, "'\"'\"'") + "'";
}

function buildDomFetchCommand(url) {
    var script =
        "set -eu; " +
        "curl -fL --compressed -A " + shellQuote("K-Splash/1.0") + " " + shellQuote(url);

    return "bash -c " + shellQuote(script);
}

function safeFileSegment(value) {
    var normalized = normalizedText(value).replace(/[^a-zA-Z0-9._-]+/g, "-");
    return normalized.length > 0 ? normalized : "latest";
}

function buildTempFilePath(photoId) {
    return "/tmp/K-Splash-wallpaper-" + safeFileSegment(photoId) + ".jpg";
}

function buildCompletionSoundScript() {
    return "if command -v paplay >/dev/null 2>&1 && [ -f /usr/share/sounds/freedesktop/stereo/complete.oga ]; then " +
        "paplay /usr/share/sounds/freedesktop/stereo/complete.oga >/dev/null 2>&1 || true; " +
        "elif command -v paplay >/dev/null 2>&1 && [ -f /usr/share/sounds/freedesktop/stereo/bell.oga ]; then " +
        "paplay /usr/share/sounds/freedesktop/stereo/bell.oga >/dev/null 2>&1 || true; " +
        "elif command -v canberra-gtk-play >/dev/null 2>&1; then " +
        "canberra-gtk-play -i complete >/dev/null 2>&1 || canberra-gtk-play -i bell >/dev/null 2>&1 || true; " +
        "elif command -v aplay >/dev/null 2>&1 && [ -f /usr/share/sounds/alsa/Front_Center.wav ]; then " +
        "aplay -q /usr/share/sounds/alsa/Front_Center.wav >/dev/null 2>&1 || true; " +
        "fi";
}

function buildCompletionSoundCommand() {
    return "bash -c " + shellQuote(buildCompletionSoundScript());
}

function buildCommand(details) {
    var imageUrl = details && details.imageUrl ? details.imageUrl : "";
    var photoId = details && details.photoId ? details.photoId : "";
    var filePath = buildTempFilePath(photoId);
    var playSoundScript = buildCompletionSoundScript();
    var qdbusScript =
        "var Desktops = desktops(); " +
        "for (var i = 0; i < Desktops.length; i++) { " +
        "  var d = Desktops[i]; " +
        "  d.wallpaperPlugin = 'org.kde.image'; " +
        "  d.currentConfigGroup = ['Wallpaper','org.kde.image','General']; " +
        "  d.writeConfig('Image','file://" + filePath + "'); " +
        "  d.reloadConfig(); " +
        "}";

    var script =
        "set -eu; " +
        "curl -fL -A " + shellQuote("K-Splash/1.0") + " " + shellQuote(imageUrl) + " -o " + shellQuote(filePath) +
        " && if command -v qdbus6 >/dev/null 2>&1; then " +
        "qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript " + shellQuote(qdbusScript) + "; " +
        "elif command -v qdbus >/dev/null 2>&1; then " +
        "qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript " + shellQuote(qdbusScript) + "; " +
        "elif command -v dbus-send >/dev/null 2>&1; then " +
        "dbus-send --session --dest=org.kde.plasmashell --type=method_call /PlasmaShell org.kde.PlasmaShell.evaluateScript string:" + shellQuote(qdbusScript) + "; " +
        "else echo " + shellQuote("qdbus or dbus-send command not found") + " >&2; exit 127; fi" +
        " && " + playSoundScript;

    return "bash -c " + shellQuote(script);
}

function buildSavedFileName(details) {
    var parts = ["K-Splash"];
    var photoId = normalizedText(details && details.photoId);
    var description = safeFileSegment(details && details.description ? details.description : "");

    if (photoId.length > 0) {
        parts.push(safeFileSegment(photoId));
    }
    if (description !== "latest") {
        parts.push(description);
    }

    return parts.join("-") + ".jpg";
}

function buildSaveCopyCommand(sourcePath, targetDirectory, details) {
    var safeSourcePath = normalizedText(sourcePath);
    var safeTargetDirectory = normalizedText(targetDirectory);
    var targetPath = safeTargetDirectory + "/" + buildSavedFileName(details);
    var playSoundScript = buildCompletionSoundScript();
    var script =
        "set -eu; " +
        "mkdir -p " + shellQuote(safeTargetDirectory) +
        " && cp " + shellQuote(safeSourcePath) + " " + shellQuote(targetPath) +
        " && " + playSoundScript +
        " && printf %s " + shellQuote(targetPath);

    return "bash -c " + shellQuote(script);
}
