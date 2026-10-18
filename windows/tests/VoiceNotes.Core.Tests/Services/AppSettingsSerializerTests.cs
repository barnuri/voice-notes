using VoiceNotes.Core.Models;
using VoiceNotes.Core.Services;

namespace VoiceNotes.Core.Tests.Services;

public sealed class AppSettingsSerializerTests
{
    [Fact]
    public void RoundTripsAllFields()
    {
        var settings = new AppSettings
        {
            BaseUrl = "https://box.example.ts.net/v1",
            Model = "whisper/x",
            LanguageId = TranscriptionLanguage.English.Id,
            HotKey = new HotKey(HotKeyModifiers.Control | HotKeyModifiers.Shift, 0x44, "D"),
            ProtectedApiKey = "c2VjcmV0",
        };
        Assert.Equal(settings, AppSettingsSerializer.Deserialize(AppSettingsSerializer.Serialize(settings)));
    }

    [Fact]
    public void WritesModifiersAsNames()
    {
        Assert.Contains("\"Alt, Control\"", AppSettingsSerializer.Serialize(new AppSettings()), StringComparison.Ordinal);
    }

    [Theory]
    [InlineData("")]
    [InlineData("not json")]
    [InlineData("null")]
    [InlineData("{}")]
    public void FallsBackToDefaults(string json)
    {
        var settings = AppSettingsSerializer.Deserialize(json);
        Assert.Equal(new AppSettings(), settings);
        Assert.Equal("http://127.0.0.1:8888/v1", settings.BaseUrl);
        Assert.Equal("ivrit/ivrit-large-v3-turbo", settings.Model);
        Assert.Equal(TranscriptionLanguage.HebrewWithEnglish, settings.Language);
        Assert.Equal(HotKey.DefaultDictation, settings.HotKey);
    }

    [Fact]
    public void ReplacesNullValuesWithDefaults()
    {
        var settings = AppSettingsSerializer.Deserialize("""{"baseUrl":null,"model":"x","hotKey":null}""");
        Assert.Equal(AppSettings.DefaultBaseUrl, settings.BaseUrl);
        Assert.Equal("x", settings.Model);
        Assert.Equal(HotKey.DefaultDictation, settings.HotKey);
    }
}
