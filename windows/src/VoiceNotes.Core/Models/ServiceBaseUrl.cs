namespace VoiceNotes.Core.Models;

public static class ServiceBaseUrl
{
    private static readonly HashSet<string> LoopbackHosts = new(StringComparer.OrdinalIgnoreCase)
    {
        "127.0.0.1",
        "[::1]",
        "localhost",
    };

    public static Uri? Parse(string? raw)
    {
        var trimmed = raw?.Trim() ?? "";
        if (!Uri.TryCreate(trimmed, UriKind.Absolute, out var url) || string.IsNullOrEmpty(url.Host))
        {
            return null;
        }
        var allowsScheme = url.Scheme == Uri.UriSchemeHttps
            || (url.Scheme == Uri.UriSchemeHttp && LoopbackHosts.Contains(url.Host));
        if (!allowsScheme)
        {
            return null;
        }
        return url.AbsolutePath.EndsWith('/') ? url : new Uri(trimmed + "/");
    }
}
