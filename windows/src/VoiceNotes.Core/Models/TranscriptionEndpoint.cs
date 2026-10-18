namespace VoiceNotes.Core.Models;

public sealed record TranscriptionEndpoint
{
    private const string TranscriptionPath = "audio/transcriptions";

    private TranscriptionEndpoint(Uri url, string model, string apiKey, TranscriptionLanguage language)
    {
        Url = url;
        Model = model;
        ApiKey = apiKey;
        Language = language;
    }

    public Uri Url { get; }

    public string Model { get; }

    public string ApiKey { get; }

    public TranscriptionLanguage Language { get; }

    public static TranscriptionEndpoint? Create(string? baseUrl, string? model, string? apiKey, TranscriptionLanguage language)
    {
        var trimmedModel = model?.Trim() ?? "";
        var baseUri = ServiceBaseUrl.Parse(baseUrl);
        if (trimmedModel.Length == 0 || baseUri is null)
        {
            return null;
        }
        return new TranscriptionEndpoint(new Uri(baseUri, TranscriptionPath), trimmedModel, apiKey?.Trim() ?? "", language);
    }
}
