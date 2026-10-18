using System.Text.Json;
using System.Text.Json.Serialization;
using VoiceNotes.Core.Models;

namespace VoiceNotes.Core.Services;

public static class AppSettingsSerializer
{
    private static readonly JsonSerializerOptions Options = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        PropertyNameCaseInsensitive = true,
        WriteIndented = true,
        Converters = { new JsonStringEnumConverter() },
    };

    public static string Serialize(AppSettings settings) => JsonSerializer.Serialize(settings, Options);

    public static AppSettings Deserialize(string json)
    {
        AppSettings? settings;
        try
        {
            settings = JsonSerializer.Deserialize<AppSettings>(json, Options);
        }
        catch (JsonException)
        {
            return new AppSettings();
        }
        return settings is null ? new AppSettings() : WithDefaultsForMissingValues(settings);
    }

    private static AppSettings WithDefaultsForMissingValues(AppSettings settings)
    {
        var defaults = new AppSettings();
        var hotKey = settings.HotKey is { KeyLabel: not null, VirtualKey: > 0 } ? settings.HotKey : defaults.HotKey;
        return settings with
        {
            BaseUrl = settings.BaseUrl ?? defaults.BaseUrl,
            Model = settings.Model ?? defaults.Model,
            LanguageId = settings.LanguageId ?? defaults.LanguageId,
            HotKey = hotKey,
            ProtectedApiKey = settings.ProtectedApiKey ?? defaults.ProtectedApiKey,
        };
    }
}
