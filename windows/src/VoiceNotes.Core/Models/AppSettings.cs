using System.Text.Json.Serialization;

namespace VoiceNotes.Core.Models;

public sealed record AppSettings
{
    public const string DefaultBaseUrl = "http://127.0.0.1:8888/v1";
    public const string DefaultModel = "ivrit/ivrit-large-v3-turbo";

    public string BaseUrl { get; init; } = DefaultBaseUrl;

    public string Model { get; init; } = DefaultModel;

    public string LanguageId { get; init; } = TranscriptionLanguage.HebrewWithEnglish.Id;

    public HotKey HotKey { get; init; } = HotKey.DefaultDictation;

    public string ProtectedApiKey { get; init; } = "";

    [JsonIgnore]
    public TranscriptionLanguage Language => TranscriptionLanguage.FromId(LanguageId);
}
